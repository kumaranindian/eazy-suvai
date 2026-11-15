/**
 * FR-101: what happens to the menu when a restaurant's limits change.
 *
 * {@link applyPlanLimits} (downgrade, or admin plan changes):
 * - Hides content beyond the plan's limits with `hiddenOverLimit: true`,
 *   the last in display order first, never deleting anything. Content the
 *   owner already chose to hide stays hidden; nothing is un-hidden here.
 * - Reverts a premium theme to the plan's default theme, keeping
 *   `themeSettings`.
 * - Copies the plan's flags to `planFeatures` and leaves a `planNotice`
 *   for the dashboard.
 * - Publishes a new version made from the **live** version with the
 *   hidden content removed (never the unreviewed draft), when anything
 *   live changed.
 * - Emails the owner.
 *
 * {@link clearHiddenOverLimit} (upgrade): clears every flag, touches the
 * draft so "Unpublished changes" shows, and asks the owner to publish
 * (FR-101 last bullet, AC-026).
 *
 * Flag writes keep each document's `updatedAt` on a downgrade, so the menu
 * triggers do not report a draft change the owner didn't make.
 */
import { FieldValue, type DocumentReference, type Firestore } from "firebase-admin/firestore";

import { writeAudit } from "../lib/audit";
import { getPlanFeatures, restaurantPlanFeatures, type PlanFeatures } from "../lib/plan-limits";
import { loadVersion, readerFor } from "../publishing/draft-reader";
import { readStale, writeVersion } from "../publishing/publish";
import {
  buildSnapshot,
  compareSequenced,
  diffSnapshots,
  isEmptySummary,
  type DocEntry,
  type DraftSource,
  type MenuSnapshot,
} from "../publishing/snapshot";
import { queueOwnerMail } from "./mail";

type Data = Record<string, unknown>;

const isLive = (d: Data) => d.deletedAt === null || d.deletedAt === undefined;
const isHidden = (d: Data) => d.hiddenOverLimit === true;

export interface Actor {
  uid: string;
  role: "owner" | "platformAdmin" | "system";
}

/** Which documents to newly hide so the visible ones fit `limits` (pure). */
export function chooseHidden(
  categories: readonly DocEntry[],
  items: readonly DocEntry[],
  limits: { maxItems: number | null; maxCategories: number | null },
): { categories: string[]; items: string[] } {
  const liveCats = categories.filter((c) => isLive(c.data)).sort(compareSequenced);
  const visibleCats = liveCats.filter((c) => !isHidden(c.data));
  const hideCats = limits.maxCategories === null ? [] : visibleCats.slice(limits.maxCategories);
  const hiddenCatIds = new Set([...liveCats.filter((c) => isHidden(c.data)).map((c) => c.id), ...hideCats.map((c) => c.id)]);

  // Items in a hidden category are hidden with it; the rest fill the
  // quota in display order (category order, then item order).
  const order = new Map(liveCats.map((c, i) => [c.id, i]));
  const rank = (i: DocEntry) => order.get(String(i.data.categoryId)) ?? Number.MAX_SAFE_INTEGER;
  const visibleItems = items
    .filter((i) => isLive(i.data) && !isHidden(i.data))
    .sort((a, b) => rank(a) - rank(b) || compareSequenced(a, b));
  const inHiddenCat = visibleItems.filter((i) => hiddenCatIds.has(String(i.data.categoryId)));
  const rest = visibleItems.filter((i) => !hiddenCatIds.has(String(i.data.categoryId)));
  const hideItems = [...(limits.maxItems === null ? [] : rest.slice(limits.maxItems)), ...inHiddenCat]
    .sort((a, b) => rank(a) - rank(b) || compareSequenced(a, b));
  // "Last first": report them in reverse display order.
  return { categories: hideCats.map((c) => c.id).reverse(), items: hideItems.map((i) => i.id).reverse() };
}

async function commitInChunks(db: Firestore, writes: Array<(b: FirebaseFirestore.WriteBatch) => void>): Promise<void> {
  for (let i = 0; i < writes.length; i += 400) {
    const batch = db.batch();
    for (const w of writes.slice(i, i + 400)) w(batch);
    await batch.commit();
  }
}

export interface ApplyLimitsResult {
  hiddenItems: string[];
  hiddenCategories: string[];
  themeReverted: boolean;
  /** The version published, or null when nothing live changed. */
  published: number | null;
  features: PlanFeatures;
}

/**
 * Applies the restaurant's current plan to its menu (FR-101).
 *
 * @param db Firestore.
 * @param restaurantId The restaurant.
 * @param actor Who caused it (system for the daily job).
 * @param opts `notify`: email the owner (default true); `reason` for the audit.
 * @return What was hidden, reverted and published.
 */
export async function applyPlanLimits(
  db: Firestore,
  restaurantId: string,
  actor: Actor,
  opts: { notify?: boolean; reason?: string } = {},
): Promise<ApplyLimitsResult> {
  const root = db.doc(`restaurants/${restaurantId}`);
  const rootSnap = await root.get();
  if (!rootSnap.exists) throw new Error(`restaurants/${restaurantId} is missing`);
  const r = rootSnap.data() as Data;
  const features = await getPlanFeatures(async (p) => (await db.doc(p).get()).data(), r.planId);

  const [catSnap, itemSnap] = await Promise.all([root.collection("categories").get(), root.collection("items").get()]);
  const categories: DocEntry[] = catSnap.docs.map((d) => ({ id: d.id, data: d.data() }));
  const items: DocEntry[] = itemSnap.docs.map((d) => ({ id: d.id, data: d.data() }));
  const hide = chooseHidden(categories, items, features);

  // Theme (FR-101): premium → the plan's default, settings kept.
  let themeId = typeof r.themeId === "string" ? r.themeId : null;
  let themeReverted = false;
  if (themeId && !features.premiumThemes) {
    const theme = await db.doc(`themes/${themeId}`).get();
    if (theme.get("premium") === true) {
      themeId = features.defaultThemeId;
      themeReverted = true;
    }
  }

  // 1. Flags on the draft (batched: up to 450 items on a Pro → Free downgrade).
  const flag = (ref: DocumentReference) => (b: FirebaseFirestore.WriteBatch) => b.update(ref, { hiddenOverLimit: true });
  await commitInChunks(db, [
    ...hide.categories.map((id) => flag(root.collection("categories").doc(id))),
    ...hide.items.map((id) => flag(root.collection("items").doc(id))),
  ]);
  const hiddenCatIds = new Set([...categories.filter((c) => isHidden(c.data)).map((c) => c.id), ...hide.categories]);
  const hiddenItemIds = new Set([...items.filter((i) => isHidden(i.data)).map((i) => i.id), ...hide.items]);

  // 2. A new live version without the hidden content, from the live source.
  let published: number | null = null;
  if (typeof r.publishedVersion === "number") {
    published = await db.runTransaction(async (tx) => {
      const read = readerFor(tx);
      const fresh = (await tx.get(root)).data() as Data;
      const n0 = fresh.publishedVersion as number;
      const current = await loadVersion(db, read, restaurantId, n0);
      if (!current?.source) return null;
      const [labels, tags, theme, live] = await Promise.all([
        tx.get(db.collection("dietaryLabels")),
        tx.get(db.collection("itemTags")),
        themeId ? tx.get(db.doc(`themes/${themeId}`)) : Promise.resolve(null),
        tx.get(db.doc(`restaurants/${restaurantId}/live/availability`)),
      ]);
      const availability = (live.get("items") ?? {}) as Record<string, unknown>;
      const src: DraftSource = current.source;
      const source: DraftSource = {
        ...src,
        restaurant: { ...src.restaurant, themeId },
        // The draft flags win in both directions (an owner may un-hide while downgrading).
        categories: src.categories.map((c) => ({ id: c.id, data: { ...c.data, hiddenOverLimit: hiddenCatIds.has(c.id) } })),
        items: src.items.map((i) => ({ id: i.id, data: { ...i.data, hiddenOverLimit: hiddenItemIds.has(i.id) } })),
      };
      const built = buildSnapshot({
        restaurant: source.restaurant,
        categories: source.categories,
        items: source.items.map((i) => ({ id: i.id, data: { ...i.data, available: availability[i.id] !== false } })),
        labels: Object.fromEntries(labels.docs.map((d) => [d.id, d.data()])),
        tags: Object.fromEntries(tags.docs.map((d) => [d.id, d.data()])),
        themeTokens: theme?.get("tokens") ?? null,
        imageUrls: source.imageUrls,
      });
      // Keep everything else exactly as published (profile and theme as live).
      const snapshot: MenuSnapshot = { ...current.snapshot, theme: themeReverted ? built.theme : current.snapshot.theme, categories: built.categories, items: built.items };
      const summary = diffSnapshots(current.snapshot, snapshot);
      if (isEmptySummary(summary)) return null;
      const n = n0 + 1;
      const stale = await readStale(tx, db, restaurantId, n);
      await writeVersion(tx, db, {
        stale,
        restaurantId,
        uid: actor.uid,
        actorRole: actor.role,
        n,
        restaurant: fresh,
        snapshot,
        source,
        summary,
        kind: "publish",
        rootPatch: {},
        audit: { action: "menu.publishPlanLimits", details: { hiddenItems: hiddenItemIds.size, hiddenCategories: hiddenCatIds.size, themeReverted } },
      });
      return n;
    });
  }

  // 3. Root: flags for rules and apps, the reverted theme, the dashboard notice.
  const notice = hide.items.length + hide.categories.length > 0 || themeReverted;
  await root.update({
    planFeatures: restaurantPlanFeatures(features),
    ...(themeReverted ? { themeId } : {}),
    ...(notice
      ? {
        planNotice: {
          kind: "limitsApplied",
          planId: r.planId ?? "free",
          hiddenItems: hiddenItemIds.size,
          hiddenCategories: hiddenCatIds.size,
          themeReverted,
          at: FieldValue.serverTimestamp(),
        },
      }
      : {}),
  });
  await writeAudit(
    {
      actorUid: actor.uid,
      actorRole: actor.role,
      action: "subscription.applyLimits",
      restaurantId,
      target: `restaurants/${restaurantId}`,
      ...(opts.reason ? { reason: opts.reason } : {}),
      details: { planId: r.planId ?? "free", hiddenItems: hide.items.length, hiddenCategories: hide.categories.length, themeReverted, published },
    },
    { db: db as never },
  );
  if (notice && opts.notify !== false) {
    await queueOwnerMail(db, r.ownerEmail, "limitsApplied", {
      restaurantId,
      name: String(r.name ?? ""),
      planName: features.premiumThemes ? "Pro" : "Free",
      hiddenItems: hiddenItemIds.size,
      hiddenCategories: hiddenCatIds.size,
    });
  }
  return { hiddenItems: hide.items, hiddenCategories: hide.categories, themeReverted, published, features };
}

/**
 * On upgrade (FR-101, AC-026): every hidden item and category comes back
 * to the draft, the draft counts as changed, and the owner is asked to
 * publish. Also refreshes `planFeatures`.
 *
 * @return How many documents were restored.
 */
export async function clearHiddenOverLimit(db: Firestore, restaurantId: string, actor: Actor, opts: { notify?: boolean } = {}): Promise<number> {
  const root = db.doc(`restaurants/${restaurantId}`);
  const r = (await root.get()).data() as Data | undefined;
  if (!r) throw new Error(`restaurants/${restaurantId} is missing`);
  const features = await getPlanFeatures(async (p) => (await db.doc(p).get()).data(), r.planId);
  const [cats, items] = await Promise.all([
    root.collection("categories").where("hiddenOverLimit", "==", true).get(),
    root.collection("items").where("hiddenOverLimit", "==", true).get(),
  ]);
  const docs = [...cats.docs, ...items.docs];
  const now = FieldValue.serverTimestamp();
  await commitInChunks(db, docs.map((d) => (b) => b.update(d.ref, { hiddenOverLimit: false, updatedAt: now })));
  await root.update({
    planFeatures: restaurantPlanFeatures(features),
    ...(docs.length > 0
      ? { draftUpdatedAt: now, planNotice: { kind: "restored", planId: r.planId ?? "free", restored: docs.length, at: now } }
      : { planNotice: FieldValue.delete() }),
  });
  if (docs.length > 0) {
    await writeAudit(
      {
        actorUid: actor.uid,
        actorRole: actor.role,
        action: "subscription.restoreHidden",
        restaurantId,
        target: `restaurants/${restaurantId}`,
        details: { restored: docs.length },
      },
      { db: db as never },
    );
    if (opts.notify !== false) await queueOwnerMail(db, r.ownerEmail, "restored", { restaurantId, name: String(r.name ?? "") });
  }
  return docs.length;
}
