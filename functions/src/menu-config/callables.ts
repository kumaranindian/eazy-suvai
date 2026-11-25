/**
 * Owner callables for business type, capabilities, tag groups, custom tags
 * and starter categories (M14). Each one writes the restaurant root and
 * recomputes `settings/menuConfig` in the same transaction, so the item
 * editor never sees a config that lags behind the owner's choice (D5).
 *
 * Nothing is ever deleted from items: tags and fields the new config no
 * longer allows stay on the items, hidden in the editor and on the public
 * menu, and come back when re-enabled.
 */
import { FieldValue, type Firestore } from "firebase-admin/firestore";
import { z } from "zod";

import { writeAudit } from "../lib/audit";
import { assertOwner, assertSignedIn, type CallerAuth } from "../lib/auth";
import { appError } from "../lib/errors";
import { getPlanLimits } from "../lib/plan-limits";
import { parseInput } from "../lib/validation";
import { isLive, nextSequence } from "../menu/menu-callables";
import { readerFor } from "../publishing/draft-reader";
import { attributesOf, configFor, loadCatalog, menuConfigRef, planTagFeatures, writeMenuConfig, type Catalog } from "./store";
import { CUSTOM_TAG_PREFIX, DIET_GROUP_ID, type MenuConfig } from "./types";

type Data = Record<string, unknown>;

const docId = z.string().min(1).max(64).regex(/^[A-Za-z0-9_-]+$/);

/** ISO 3166-2 (`IN-TN`) or a bare country (`IN`). */
export const REGION_PATTERN = /^[A-Z]{2}(-[A-Z0-9]{1,3})?$/;

export const SETUP_STEPS = ["type", "features", "categories"] as const;

export const updateMenuFeaturesSchema = z
  .object({
    restaurantId: docId,
    businessType: docId.optional(),
    capabilities: z.record(docId, z.boolean()).optional(),
    disabledTagGroupIds: z.array(docId).max(50).optional(),
    region: z.string().regex(REGION_PATTERN).nullable().optional(),
    /** null = back to the default of the type and capabilities (D10). */
    seoIndexable: z.boolean().nullable().optional(),
    /** Setup wizard step this call finishes (resume point). */
    setupStep: z.enum(SETUP_STEPS).optional(),
    dryRun: z.boolean().default(false),
  })
  .strict();

/** What a change would hide, for the warning dialog. Nothing is deleted. */
export interface FeatureImpact {
  /** Items (not deleted) with at least one tag, diet label or field that becomes hidden. */
  items: number;
  /** Tag and diet ids that become hidden and are used by items. */
  hiddenTagIds: string[];
  /** Item fields that become hidden and are used by items. */
  hiddenFields: string[];
  /** Tags, diet labels and fields that come back. */
  restoredTagIds: string[];
}

function shownIds(c: Pick<MenuConfig, "tagGroups"> | undefined): Set<string> {
  return new Set((c?.tagGroups ?? []).flatMap((g) => g.tags.map((t) => t.id)));
}

/**
 * Compares two configs over the restaurant's items.
 *
 * @param before The current config (undefined before the first compute).
 * @param after The config after the change.
 * @param items Live items' data.
 */
export function featureImpact(
  before: Pick<MenuConfig, "tagGroups" | "itemFields"> | undefined,
  after: Pick<MenuConfig, "tagGroups" | "itemFields">,
  items: readonly Data[],
): FeatureImpact {
  const was = shownIds(before);
  const now = shownIds(after);
  const hiddenTags = new Set<string>();
  const restored = new Set<string>();
  const hiddenFields = new Set<string>();
  let affected = 0;
  for (const item of items) {
    const ids = [
      ...(typeof item.dietaryLabelId === "string" ? [item.dietaryLabelId] : []),
      ...(Array.isArray(item.tagIds) ? item.tagIds.filter((t): t is string => typeof t === "string") : []),
    ];
    let hit = false;
    for (const id of ids) {
      if (was.has(id) && !now.has(id)) {
        hiddenTags.add(id);
        hit = true;
      }
      if (!was.has(id) && now.has(id)) restored.add(id);
    }
    const attrs = attributesOf(item.attributes);
    const used = [
      ...(attrs.servingSizes && attrs.servingSizes.length > 0 ? ["servingSizes"] : []),
      ...(attrs.abvTenths !== undefined ? ["abv"] : []),
    ];
    for (const f of used) {
      if ((before?.itemFields ?? []).includes(f as never) && !after.itemFields.includes(f as never)) {
        hiddenFields.add(f);
        hit = true;
      }
    }
    if (hit) affected++;
  }
  return { items: affected, hiddenTagIds: [...hiddenTags].sort(), hiddenFields: [...hiddenFields].sort(), restoredTagIds: [...restored].sort() };
}

function assertKnown(catalog: Catalog, input: z.infer<typeof updateMenuFeaturesSchema>, current: Data): void {
  if (input.businessType !== undefined && input.businessType !== current.businessType) {
    const t = catalog.types[input.businessType];
    if (!t || !t.active) throw appError("invalid-input", "Unknown business type.", { field: "businessType" });
  }
  for (const id of Object.keys(input.capabilities ?? {})) {
    if (!catalog.capabilities[id]?.active) throw appError("invalid-input", "Unknown capability.", { field: "capabilities" });
  }
  for (const id of input.disabledTagGroupIds ?? []) {
    const g = catalog.tagGroups[id];
    if (!g || id === DIET_GROUP_ID || g.required) {
      throw appError("invalid-input", "This tag group can't be switched off.", { field: "disabledTagGroupIds" });
    }
  }
}

/**
 * Callable `updateMenuFeatures`: business type, capability answers,
 * switched-off tag groups, alcohol-notice region and the search-engine
 * choice. With `dryRun` it only reports what would be hidden.
 *
 * @return `{configVersion, impact, config}` (`config` is the new menu config).
 */
export async function updateMenuFeatures(
  db: Firestore,
  auth: CallerAuth | undefined | null,
  data: unknown,
): Promise<{ configVersion: number; impact: FeatureImpact; dryRun: boolean }> {
  assertSignedIn(auth);
  const input = parseInput(updateMenuFeaturesSchema, data);
  const { uid, restaurantId } = await assertOwner(auth, input.restaurantId, { db });
  const root = db.doc(`restaurants/${restaurantId}`);

  return db.runTransaction(async (tx) => {
    const read = readerFor(tx);
    const [rootSnap, prevSnap, items, catalog] = await Promise.all([
      read.get(root),
      read.get(menuConfigRef(db, restaurantId)),
      read.query(root.collection("items").where("deletedAt", "==", null)),
      loadCatalog(db, read),
    ]);
    const current = (rootSnap.data() ?? {}) as Data;
    assertKnown(catalog, input, current);

    const patch: Data = {};
    if (input.businessType !== undefined) patch.businessType = input.businessType;
    if (input.capabilities !== undefined) {
      patch.capabilities = { ...((current.capabilities as Data | undefined) ?? {}), ...input.capabilities };
    }
    if (input.disabledTagGroupIds !== undefined) patch.disabledTagGroupIds = [...new Set(input.disabledTagGroupIds)].sort();
    if (input.region !== undefined) patch.region = input.region;
    if (input.seoIndexable !== undefined) patch.seo = input.seoIndexable === null ? {} : { indexable: input.seoIndexable };

    const next = { ...current, ...patch };
    const before = prevSnap.exists ? (prevSnap.data() as MenuConfig) : configFor(catalog, current);
    const config = configFor(catalog, next);
    const impact = featureImpact(before, config, items.docs.map((d) => d.data()));
    if (input.dryRun) {
      return { configVersion: (prevSnap.get("configVersion") as number | undefined) ?? 0, impact, dryRun: true };
    }

    const now = FieldValue.serverTimestamp();
    const update: Data = { ...patch };
    // Type, capabilities, region and SEO all change the public menu: a draft change (FR-012).
    if (Object.keys(patch).length > 0) update.draftUpdatedAt = now;
    if (input.setupStep) update[`setupProgress.${input.setupStep}`] = now;
    if (Object.keys(update).length > 0) tx.update(root, update);
    const { configVersion } = writeMenuConfig(tx, db, restaurantId, config, prevSnap.exists ? (prevSnap.data() as Data) : undefined);
    if (Object.keys(patch).length > 0) {
      await writeAudit({
        actorUid: uid,
        actorRole: "owner",
        action: "restaurant.updateFeatures",
        restaurantId,
        target: `restaurants/${restaurantId}`,
        details: { ...patch, hiddenItems: impact.items },
      }, { db: db as never, transaction: tx });
    }
    return { configVersion, impact, dryRun: false };
  });
}

// ---- Starter categories -------------------------------------------------------

export const createStarterCategoriesSchema = z
  .object({
    restaurantId: docId,
    /** Keys from `menuConfig.starterCategories`; [] skips the step. */
    keys: z.array(docId).max(30),
  })
  .strict();

/**
 * Callable `createStarterCategories`: creates the chosen starter categories
 * (in config order) within the plan's category limit, once per key
 * (`categories/{cid}.starterKey`), and marks the wizard step done.
 *
 * @return `{created}` ids of the new categories.
 */
export async function createStarterCategories(
  db: Firestore,
  auth: CallerAuth | undefined | null,
  data: unknown,
): Promise<{ created: string[] }> {
  assertSignedIn(auth);
  const input = parseInput(createStarterCategoriesSchema, data);
  const { restaurantId } = await assertOwner(auth, input.restaurantId, { db });
  const root = db.doc(`restaurants/${restaurantId}`);
  const categories = root.collection("categories");

  return db.runTransaction(async (tx) => {
    const read = readerFor(tx);
    const [rootSnap, configSnap, all, itemCount] = await Promise.all([
      read.get(root),
      read.get(menuConfigRef(db, restaurantId)),
      read.query(categories),
      tx.get(root.collection("items").where("deletedAt", "==", null).count()),
    ]);
    const restaurant = (rootSnap.data() ?? {}) as Data;
    const starters = ((configSnap.get("starterCategories") as { key: string; name: string }[] | undefined) ?? []);
    const wanted = new Set(input.keys);
    const existing = new Set(all.docs.filter((d) => isLive(d.data())).map((d) => d.get("starterKey")));
    const toCreate = starters.filter((c) => wanted.has(c.key) && !existing.has(c.key));
    if (input.keys.some((k) => !starters.some((c) => c.key === k))) {
      throw appError("invalid-input", "Unknown starter category.", { field: "keys" });
    }

    const live = all.docs.filter((d) => isLive(d.data())).length;
    const planId = typeof restaurant.planId === "string" ? restaurant.planId : "free";
    const limits = await getPlanLimits(async (path) => (await read.get(db.doc(path))).data(), planId);
    if (limits.maxCategories !== null && live + toCreate.length > limits.maxCategories) {
      throw appError("limit-reached", `Plan limit of ${limits.maxCategories} categories reached.`, {
        limit: "categories", max: limits.maxCategories, planId,
      });
    }

    let sequence = nextSequence(all.docs.map((d) => d.data()));
    const now = FieldValue.serverTimestamp();
    const created: string[] = [];
    for (const c of toCreate) {
      const ref = categories.doc();
      tx.create(ref, {
        name: c.name, description: "", image: null, sequence, active: true, starterKey: c.key,
        deletedAt: null, createdAt: now, updatedAt: now,
      });
      created.push(ref.id);
      sequence += 1000;
    }
    const update: Data = { "setupProgress.categories": now };
    if (created.length > 0) {
      update["counts.categories"] = live + created.length;
      update["counts.items"] = itemCount.data().count;
      update.draftUpdatedAt = now;
    }
    tx.update(root, update);
    return { created };
  });
}

// ---- Custom tags (plan-gated, D8) ---------------------------------------------

export const upsertCustomTagSchema = z
  .object({
    restaurantId: docId,
    /** Omit to create. */
    id: z.string().regex(/^c-[A-Za-z0-9_-]{1,40}$/).optional(),
    name: z.string().trim().min(1).max(30),
    groupId: docId,
    color: z.string().regex(/^#[0-9A-Fa-f]{6}$/).optional(),
    /** true removes the tag from new choices (items keep it, hidden). */
    retired: z.boolean().default(false),
  })
  .strict();

function newCustomId(name: string, taken: Set<string>): string {
  const base = `${CUSTOM_TAG_PREFIX}${name.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, "").slice(0, 30) || "tag"}`;
  let id = base;
  for (let n = 2; taken.has(id); n++) id = `${base}-${n}`;
  return id;
}

/**
 * Callable `upsertCustomTag`: creates, renames or retires one of the
 * restaurant's own tags. Needs the plan's `customTags` flag; at most
 * `maxCustomTags` active tags (BR-011).
 *
 * @return `{id, configVersion}`.
 */
export async function upsertCustomTag(
  db: Firestore,
  auth: CallerAuth | undefined | null,
  data: unknown,
): Promise<{ id: string; configVersion: number }> {
  assertSignedIn(auth);
  const input = parseInput(upsertCustomTagSchema, data);
  const { uid, restaurantId } = await assertOwner(auth, input.restaurantId, { db });
  const root = db.doc(`restaurants/${restaurantId}`);

  return db.runTransaction(async (tx) => {
    const read = readerFor(tx);
    const [rootSnap, prevSnap, catalog] = await Promise.all([
      read.get(root), read.get(menuConfigRef(db, restaurantId)), loadCatalog(db, read),
    ]);
    const restaurant = (rootSnap.data() ?? {}) as Data;
    const plan = planTagFeatures(restaurant);
    const planId = typeof restaurant.planId === "string" ? restaurant.planId : "free";
    if (!plan.customTags && !input.retired) {
      throw appError("limit-reached", "Your plan has no custom tags.", { limit: "customTags", max: 0, planId });
    }
    const group = catalog.tagGroups[input.groupId];
    if (!group || input.groupId === DIET_GROUP_ID) {
      throw appError("invalid-input", "Custom tags can't go in this group.", { field: "groupId" });
    }

    const list = ((restaurant.customTags as Data[] | undefined) ?? []).map((t) => ({ ...t }));
    const taken = new Set([...list.map((t) => String(t.id)), ...Object.values(catalog.tagGroups).flatMap((g) => g.tags.map((t) => t.id))]);
    let id = input.id;
    const tag: Data = { name: input.name, groupId: input.groupId, ...(input.color ? { color: input.color } : {}), ...(input.retired ? { retired: true } : {}) };
    if (id === undefined) {
      id = newCustomId(input.name, taken);
      list.push({ id, ...tag });
    } else {
      const i = list.findIndex((t) => t.id === id);
      if (i < 0) throw appError("not-found", "Custom tag not found.", { field: "id" });
      list[i] = { id, ...tag };
    }
    const active = list.filter((t) => t.retired !== true).length;
    if (!input.retired && active > plan.maxCustomTags) {
      throw appError("limit-reached", `Plan limit of ${plan.maxCustomTags} custom tags reached.`, {
        limit: "customTags", max: plan.maxCustomTags, planId,
      });
    }

    const now = FieldValue.serverTimestamp();
    tx.update(root, { customTags: list, draftUpdatedAt: now });
    const config = configFor(catalog, { ...restaurant, customTags: list });
    const { configVersion } = writeMenuConfig(tx, db, restaurantId, config, prevSnap.exists ? (prevSnap.data() as Data) : undefined);
    await writeAudit({
      actorUid: uid, actorRole: "owner", action: input.id === undefined ? "restaurant.createCustomTag" : "restaurant.updateCustomTag",
      restaurantId, target: `restaurants/${restaurantId}`, details: { id, ...tag },
    }, { db: db as never, transaction: tx });
    return { id, configVersion };
  });
}
