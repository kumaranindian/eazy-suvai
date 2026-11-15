import {
  FieldValue,
  type DocumentReference,
  type Firestore,
  type QuerySnapshot,
  type Transaction,
} from "firebase-admin/firestore";
import { z } from "zod";

import { writeAudit } from "../lib/audit";
import { assertOwner, assertSignedIn, type CallerAuth, type OwnerContext } from "../lib/auth";
import { appError } from "../lib/errors";
import { parseInput } from "../lib/validation";
import { renderMenuPage } from "../public/render-menu";
import {
  imageUrlsFor,
  loadDraft,
  loadVersion,
  readerFor,
  sourceRef,
  storageUrlResolver,
  versionRef,
  type ImageUrlResolver,
  type LoadedDraft,
} from "./draft-reader";
import {
  buildDraftSource,
  buildSnapshot,
  diffSnapshots,
  DRAFT_CATEGORY_FIELDS,
  DRAFT_ITEM_FIELDS,
  DRAFT_ROOT_FIELDS,
  ProblemCode,
  stableJson,
  summaryCounts,
  VERSIONS_KEPT,
  type ChangeSummary,
  type DocEntry,
  type DraftSource,
  type MenuSnapshot,
  type PublishProblem,
  validateDraft,
} from "./snapshot";

type Data = Record<string, unknown>;

/** Test seams: the image URL resolver. */
export interface PublishDeps {
  resolveImageUrls?: ImageUrlResolver;
}

const rid = z.string().min(1).max(128).regex(/^[A-Za-z0-9_-]+$/);

export const publishMenuSchema = z
  .object({
    restaurantId: rid,
    dryRun: z.boolean().default(false),
    pricesReviewed: z.boolean().default(false),
  })
  .strict();

export const rollbackMenuSchema = z
  .object({
    restaurantId: rid,
    version: z.number().int().min(1),
    /** Also replace the draft with that version (FR-096: after the owner confirms). */
    replaceDraft: z.boolean().default(true),
  })
  .strict();

export const restaurantOnlySchema = z.object({ restaurantId: rid }).strict();

/** Entries kept in `restaurants/{rid}.versionHistory` (same as the versions kept). */
export interface VersionHistoryEntry {
  n: number;
  kind: "publish" | "rollback";
  rollbackOf: number | null;
  publishedAt: FirebaseFirestore.Timestamp | FieldValue;
  publishedBy: string;
  summary: ReturnType<typeof summaryCounts>;
}

/**
 * Like `assertOwner`, but an unverified email is reported as a publish
 * problem instead of an error, so the dry run lists it with the others
 * (FR-066, AC-021). Suspended and other inactive accounts still fail with
 * `account-inactive`.
 */
async function assertPublisher(
  db: Firestore,
  auth: CallerAuth | undefined | null,
  restaurantId: string,
): Promise<OwnerContext & { emailVerified: boolean }> {
  const caller = assertSignedIn(auth);
  const emailVerified = caller.token.email_verified === true;
  const owner = await assertOwner({ ...caller, token: { ...caller.token, email_verified: true } }, restaurantId, { db });
  return { ...owner, emailVerified };
}

function blocked(problems: PublishProblem[]): never {
  throw appError("publish-blocked", "The menu cannot be published.", { problems });
}

interface Prepared {
  snapshot: MenuSnapshot;
  source: DraftSource;
  summary: ChangeSummary;
  problems: PublishProblem[];
}

function prepare(
  draft: LoadedDraft,
  imageUrls: Record<string, string>,
  ctx: { emailVerified: boolean; pricesReviewed: boolean },
): Prepared {
  const input = { ...draft.input, imageUrls };
  const snapshot = buildSnapshot(input);
  const problems = validateWith(draft, input, snapshot, ctx);
  return {
    snapshot,
    source: buildDraftSource(input),
    summary: diffSnapshots(draft.current?.snapshot ?? null, snapshot),
    problems,
  };
}

function validateWith(
  draft: LoadedDraft,
  input: Parameters<typeof validateDraft>[0],
  snapshot: MenuSnapshot,
  ctx: { emailVerified: boolean; pricesReviewed: boolean },
): PublishProblem[] {
  return validateDraft(input, snapshot, {
    emailVerified: ctx.emailVerified,
    pricesNeedReview: draft.input.restaurant.pricesNeedReview === true,
    pricesReviewed: ctx.pricesReviewed,
    maxItems: draft.limits.maxItems,
    maxCategories: draft.limits.maxCategories,
    planId: draft.planId,
  });
}

/** Result of a dry run (FR-065, FR-066). */
export interface PublishCheck {
  ok: boolean;
  problems: PublishProblem[];
  summary: ChangeSummary;
  /** The version now live, or null. */
  currentVersion: number | null;
  /** The currency changed after the last publish: show the prices checkbox. */
  pricesNeedReview: boolean;
}

/** Result of a publish or rollback. */
export interface PublishResult {
  version: number;
  summary: ChangeSummary;
}

/**
 * Writes a new version and makes it live, in the caller's transaction
 * (FR-062, §7.4): `versions/{n}` with the snapshot, its private source,
 * the root pointer, `live/availability` reset from the snapshot, versions
 * beyond the last {@link VERSIONS_KEPT} deleted, and the audit entry. The
 * public menu reads `publishedVersion` and then that immutable version,
 * so readers see the old or the new menu, never a mix (AC-022).
 */
/** Versions that fall out of the last {@link VERSIONS_KEPT} once `n` is written. Read before any write. */
function readStale(tx: Transaction, db: Firestore, restaurantId: string, n: number): Promise<QuerySnapshot> {
  return tx.get(db.collection(`restaurants/${restaurantId}/versions`).where("n", "<=", n - VERSIONS_KEPT));
}

async function writeVersion(
  tx: Transaction,
  db: Firestore,
  args: {
    /** From {@link readStale}, read before any write. */
    stale: QuerySnapshot;
    restaurantId: string;
    uid: string;
    n: number;
    restaurant: Data;
    snapshot: MenuSnapshot;
    source: DraftSource;
    summary: ChangeSummary;
    kind: "publish" | "rollback";
    rollbackOf?: number;
    /** Root fields to set as well (draft replacement, `publishedDraftAt`). */
    rootPatch: Data;
    audit: { action: string; details: Data };
  },
): Promise<void> {
  const { restaurantId, n } = args;
  const root = db.doc(`restaurants/${restaurantId}`);

  const now = FieldValue.serverTimestamp();
  const counts = summaryCounts(args.summary);
  tx.create(versionRef(db, restaurantId, n), {
    n,
    kind: args.kind,
    rollbackOf: args.rollbackOf ?? null,
    publishedAt: now,
    publishedBy: args.uid,
    summary: counts,
    snapshot: args.snapshot,
  });
  tx.set(sourceRef(db, restaurantId, n), args.source);

  const history = Array.isArray(args.restaurant.versionHistory)
    ? (args.restaurant.versionHistory as Data[]).filter((h) => typeof h.n === "number" && (h.n as number) > n - VERSIONS_KEPT)
    : [];
  const entry = {
    n,
    kind: args.kind,
    rollbackOf: args.rollbackOf ?? null,
    // serverTimestamp() is not allowed inside arrays.
    publishedAt: new Date(),
    publishedBy: args.uid,
    summary: counts,
  };
  tx.update(root, {
    publishedVersion: n,
    publishedAt: now,
    publishedCurrency: args.snapshot.currency,
    pricesNeedReview: false,
    versionHistory: [entry, ...history].slice(0, VERSIONS_KEPT),
    ...args.rootPatch,
  });

  tx.set(db.doc(`restaurants/${restaurantId}/live/availability`), {
    items: Object.fromEntries(args.snapshot.items.map((i) => [i.id, i.available])),
    updatedAt: now,
  });

  for (const d of args.stale.docs) {
    tx.delete(d.ref);
    tx.delete(sourceRef(db, restaurantId, Number(d.id)));
  }

  await writeAudit(
    {
      actorUid: args.uid,
      actorRole: "owner",
      action: args.audit.action,
      restaurantId,
      target: `restaurants/${restaurantId}/versions/${n}`,
      details: { version: n, ...counts, ...args.audit.details },
    },
    { db: db as never, transaction: tx },
  );
}

/**
 * Callable `publishMenu` (FR-063 to FR-066, BR-003, BR-011, AC-013, AC-021).
 *
 * `dryRun: true` returns {@link PublishCheck}: every problem with its
 * stable code and the change summary, without writing anything. Otherwise
 * the draft is re-read, re-validated and published in one transaction; any
 * problem fails with `publish-blocked` and `details.problems`.
 *
 * @param db Firestore.
 * @param auth The caller.
 * @param data `{restaurantId, dryRun?, pricesReviewed?}`.
 * @param deps Test seams.
 * @return The check (dry run) or the new version.
 */
export async function publishMenu(
  db: Firestore,
  auth: CallerAuth | undefined | null,
  data: unknown,
  deps: PublishDeps = {},
): Promise<PublishCheck | PublishResult> {
  const input = parseInput(publishMenuSchema, data);
  const owner = await assertPublisher(db, auth, input.restaurantId);
  const resolve = deps.resolveImageUrls ?? storageUrlResolver;
  const ctx = { emailVerified: owner.emailVerified, pricesReviewed: input.pricesReviewed };

  // Resolve image URLs outside the transaction (network calls).
  const outside = await loadDraft(db, input.restaurantId);
  const urls = await imageUrlsFor(outside, resolve);

  if (input.dryRun) {
    const p = prepare(outside, urls, ctx);
    return {
      ok: p.problems.length === 0,
      problems: p.problems,
      summary: p.summary,
      currentVersion: outside.current?.n ?? null,
      pricesNeedReview: outside.input.restaurant.pricesNeedReview === true,
    };
  }

  return db.runTransaction(async (tx) => {
    const draft = await loadDraft(db, input.restaurantId, tx);
    const p = prepare(draft, await imageUrlsFor(draft, resolve, urls), ctx);
    if (p.problems.length > 0) blocked(p.problems);
    const n = (typeof draft.input.restaurant.publishedVersion === "number" ? draft.input.restaurant.publishedVersion : 0) + 1;
    const stale = await readStale(tx, db, input.restaurantId, n);
    await writeVersion(tx, db, {
      stale,
      restaurantId: input.restaurantId,
      uid: owner.uid,
      n,
      restaurant: draft.input.restaurant,
      snapshot: p.snapshot,
      source: p.source,
      summary: p.summary,
      kind: "publish",
      // Every draft change up to this commit is in the snapshot.
      rootPatch: { publishedDraftAt: FieldValue.serverTimestamp() },
      audit: { action: "menu.publish", details: {} },
    });
    return { version: n, summary: p.summary };
  });
}

/**
 * Writes the draft collections and root fields from a version's source, in
 * the caller's transaction (FR-096). Only documents that differ are
 * written. Draft content that is not in the source (added since) is
 * soft-deleted, so it stays in Recently deleted for 30 days (FR-098).
 * Availability is kept: it is live (FR-095).
 *
 * Every write stamps the same server time as the root's `draftUpdatedAt`
 * and `publishedDraftAt`, so the menu triggers see nothing newer and the
 * draft counts as published.
 */
function replaceDraft(tx: Transaction, db: Firestore, restaurantId: string, draft: LoadedDraft, source: DraftSource): Data {
  const root = db.doc(`restaurants/${restaurantId}`);
  const now = FieldValue.serverTimestamp();
  const live = (d: Data) => d.deletedAt === null || d.deletedAt === undefined;
  const same = (a: Data, b: Data, fields: readonly string[]) =>
    fields.every((f) => stableJson(a[f] ?? null) === stableJson(b[f] ?? null));

  const sync = (
    kind: "categories" | "items",
    current: DocEntry[],
    wanted: DocEntry[],
    fields: readonly string[],
  ) => {
    const col = root.collection(kind);
    const wantedIds = new Set(wanted.map((w) => w.id));
    const byId = new Map(current.map((c) => [c.id, c.data]));
    for (const w of wanted) {
      const existing = byId.get(w.id);
      if (existing && live(existing) && same(existing, w.data, fields)) continue;
      const doc: Data = {
        ...w.data,
        deletedAt: null,
        createdAt: existing?.createdAt ?? now,
        updatedAt: now,
      };
      if (kind === "items") {
        doc.available = existing ? existing.available !== false : true;
        doc.deletedWith = null;
        doc.hiddenOverLimit = w.data.hiddenOverLimit === true;
      }
      tx.set(col.doc(w.id) as DocumentReference, doc);
    }
    const goneCategories = new Set(
      kind === "items"
        ? draft.input.categories.filter((c) => live(c.data) && !source.categories.some((s) => s.id === c.id)).map((c) => c.id)
        : [],
    );
    for (const c of current) {
      if (!live(c.data) || wantedIds.has(c.id)) continue;
      const patch: Data = { deletedAt: now, updatedAt: now };
      if (kind === "items") {
        // Restoring the category from Recently deleted brings these back too.
        const cid = String(c.data.categoryId);
        patch.deletedWith = goneCategories.has(cid) ? cid : null;
      }
      tx.update(col.doc(c.id), patch);
    }
  };

  sync("categories", draft.input.categories, source.categories, DRAFT_CATEGORY_FIELDS);
  sync("items", draft.input.items, source.items, DRAFT_ITEM_FIELDS);

  const rootPatch: Data = {};
  for (const f of DRAFT_ROOT_FIELDS) rootPatch[f] = source.restaurant[f] ?? null;
  return {
    ...rootPatch,
    "counts": { categories: source.categories.length, items: source.items.length },
    "draftUpdatedAt": now,
    "publishedDraftAt": now,
  };
}

/**
 * Callable `rollbackMenu` (FR-096, AC-013): publishes version `version`
 * again as a new version, with today's availability. With `replaceDraft`
 * (the default; the app asks first) the draft is also replaced by that
 * version, otherwise the draft is kept and shows as unpublished changes.
 *
 * @param db Firestore.
 * @param auth The caller.
 * @param data `{restaurantId, version, replaceDraft?}`.
 * @return The new version and the change summary.
 */
export async function rollbackMenu(
  db: Firestore,
  auth: CallerAuth | undefined | null,
  data: unknown,
): Promise<PublishResult> {
  const input = parseInput(rollbackMenuSchema, data);
  const owner = await assertPublisher(db, auth, input.restaurantId);
  if (!owner.emailVerified) blocked([{ code: ProblemCode.emailNotVerified }]);

  return db.runTransaction(async (tx) => {
    const draft = await loadDraft(db, input.restaurantId, tx);
    const target = await loadVersion(db, readerFor(tx), input.restaurantId, input.version);
    if (!target || !target.source) throw appError("not-found", "That version is no longer kept.", { version: input.version });

    // Availability is live: take today's value for items that still exist.
    const draftItems = new Map(draft.input.items.map((i) => [i.id, i.data]));
    const snapshot: MenuSnapshot = {
      ...target.snapshot,
      items: target.snapshot.items.map((i) => {
        const d = draftItems.get(i.id);
        return d ? { ...i, available: d.available !== false } : i;
      }),
    };

    // BR-011: a version from before a downgrade may be over today's limits.
    const problems: PublishProblem[] = [];
    const { maxItems, maxCategories } = draft.limits;
    if (maxItems !== null && snapshot.items.length > maxItems) {
      problems.push({ code: ProblemCode.limitExceeded, details: { limit: "items", max: maxItems, count: snapshot.items.length, planId: draft.planId } });
    }
    if (maxCategories !== null && snapshot.categories.length > maxCategories) {
      problems.push({ code: ProblemCode.limitExceeded, details: { limit: "categories", max: maxCategories, count: snapshot.categories.length, planId: draft.planId } });
    }
    if (problems.length > 0) blocked(problems);

    const summary = diffSnapshots(draft.current?.snapshot ?? null, snapshot);
    const n = (typeof draft.input.restaurant.publishedVersion === "number" ? draft.input.restaurant.publishedVersion : 0) + 1;
    const stale = await readStale(tx, db, input.restaurantId, n);
    const rootPatch = input.replaceDraft
      ? replaceDraft(tx, db, input.restaurantId, draft, target.source)
      : { publishedDraftAt: null };
    await writeVersion(tx, db, {
      stale,
      restaurantId: input.restaurantId,
      uid: owner.uid,
      n,
      restaurant: draft.input.restaurant,
      snapshot,
      source: target.source,
      summary,
      kind: "rollback",
      rollbackOf: input.version,
      rootPatch,
      audit: { action: "menu.rollback", details: { rollbackOf: input.version, replaceDraft: input.replaceDraft } },
    });
    return { version: n, summary };
  });
}

/**
 * Callable `discardDraft` (FR-096): replaces the draft with the version now
 * live. Nothing is published.
 *
 * @param db Firestore.
 * @param auth The caller.
 * @param data `{restaurantId}`.
 * @return `{version}`: the version the draft now matches.
 */
export async function discardDraft(
  db: Firestore,
  auth: CallerAuth | undefined | null,
  data: unknown,
): Promise<{ version: number }> {
  const input = parseInput(restaurantOnlySchema, data);
  const owner = await assertOwner(auth, input.restaurantId, { db });

  return db.runTransaction(async (tx) => {
    const draft = await loadDraft(db, input.restaurantId, tx);
    const current = draft.current;
    if (!current || !current.source) throw appError("not-found", "Nothing is published yet.");
    const patch = replaceDraft(tx, db, input.restaurantId, draft, current.source);
    // Prices are back in the published currency.
    tx.update(db.doc(`restaurants/${input.restaurantId}`), { ...patch, pricesNeedReview: false });
    await writeAudit(
      {
        actorUid: owner.uid,
        actorRole: "owner",
        action: "menu.discardDraft",
        restaurantId: input.restaurantId,
        target: `restaurants/${input.restaurantId}`,
        details: { version: current.n },
      },
      { db: db as never, transaction: tx },
    );
    return { version: current.n };
  });
}

/**
 * Callable `previewMenu` (FR-061): the draft rendered by the public menu
 * renderer with `draft: true` (a "Preview" banner and `noindex`). The app
 * shows the HTML in an iframe (web) or a web view (mobile). Returned to
 * the owner only, never cached, never served at a public URL.
 *
 * @param db Firestore.
 * @param auth The caller.
 * @param data `{restaurantId}`.
 * @param deps Test seams.
 * @return `{html, problems}`; problems are those of a dry run (the preview works anyway).
 */
export async function previewMenu(
  db: Firestore,
  auth: CallerAuth | undefined | null,
  data: unknown,
  deps: PublishDeps = {},
): Promise<{ html: string; problems: PublishProblem[] }> {
  const input = parseInput(restaurantOnlySchema, data);
  const owner = await assertPublisher(db, auth, input.restaurantId);
  const draft = await loadDraft(db, input.restaurantId);
  const urls = await imageUrlsFor(draft, deps.resolveImageUrls ?? storageUrlResolver);
  const p = prepare(draft, urls, { emailVerified: owner.emailVerified, pricesReviewed: false });
  return { html: renderMenuPage(p.snapshot, { draft: true }), problems: p.problems };
}
