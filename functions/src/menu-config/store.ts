/**
 * Reading the catalogs and writing `restaurants/{rid}/settings/menuConfig`
 * (M14). Every writer goes through {@link writeMenuConfig}, so the document
 * always matches {@link computeMenuConfig} of the restaurant's current
 * fields.
 */
import { FieldValue, type DocumentReference, type Firestore, type Transaction } from "firebase-admin/firestore";
import { z } from "zod";

import { readerFor, type Reader } from "../publishing/draft-reader";
import {
  computeMenuConfig,
  parseBusinessType,
  parseCapability,
  parseTagGroup,
  restaurantFeatureFields,
} from "./compute";
import type { BusinessTypeDef, CapabilityDef, MenuConfig, PlanTagFeatures, TagGroupDef } from "./types";

type Data = Record<string, unknown>;

export const BUSINESS_TYPES_COLLECTION = "businessTypes";
export const CAPABILITIES_COLLECTION = "capabilities";
export const TAG_GROUPS_COLLECTION = "tagGroups";

export function menuConfigRef(db: Firestore, rid: string): DocumentReference {
  return db.doc(`restaurants/${rid}/settings/menuConfig`);
}

export interface Catalog {
  types: Record<string, BusinessTypeDef>;
  capabilities: Record<string, CapabilityDef>;
  tagGroups: Record<string, TagGroupDef>;
}

/** Reads the three platform catalogs (small collections). */
export async function loadCatalog(db: Firestore, read: Reader = readerFor()): Promise<Catalog> {
  const [types, caps, groups] = await Promise.all([
    read.query(db.collection(BUSINESS_TYPES_COLLECTION)),
    read.query(db.collection(CAPABILITIES_COLLECTION)),
    read.query(db.collection(TAG_GROUPS_COLLECTION)),
  ]);
  const catalog: Catalog = { types: {}, capabilities: {}, tagGroups: {} };
  for (const d of types.docs) {
    const t = parseBusinessType(d.id, d.data());
    if (t) catalog.types[d.id] = t;
  }
  for (const d of caps.docs) catalog.capabilities[d.id] = parseCapability(d.id, d.data());
  for (const d of groups.docs) catalog.tagGroups[d.id] = parseTagGroup(d.id, d.data());
  return catalog;
}

/** Plan flags from the restaurant's `planFeatures` copy (missing = Free = off). */
export function planTagFeatures(restaurant: Data): PlanTagFeatures {
  const f = (restaurant.planFeatures ?? {}) as Data;
  const max = typeof f.maxCustomTags === "number" && Number.isInteger(f.maxCustomTags) ? f.maxCustomTags : 0;
  return { customTags: f.customTags === true, maxCustomTags: Math.max(0, max) };
}

/**
 * The type a restaurant uses: its own when it exists and is active, else
 * `restaurant` (also when the type was retired after the owner chose it,
 * so the menu keeps working).
 */
export function typeFor(catalog: Catalog, businessType: unknown): BusinessTypeDef | null {
  const own = typeof businessType === "string" ? catalog.types[businessType] : undefined;
  if (own) return own;
  return catalog.types.restaurant ?? null;
}

/** Computes the config of a restaurant from its root data. */
export function configFor(catalog: Catalog, restaurant: Data): MenuConfig {
  return computeMenuConfig({
    type: typeFor(catalog, restaurant.businessType),
    capabilities: catalog.capabilities,
    tagGroups: catalog.tagGroups,
    restaurant: restaurantFeatureFields(restaurant),
    plan: planTagFeatures(restaurant),
  });
}

/**
 * Stable JSON of a config without its stamps, to decide whether a write
 * changes anything.
 */
export function configFingerprint(c: Data | MenuConfig | undefined): string {
  if (!c) return "";
  const { configVersion: _v, computedAt: _c, ...rest } = c as Data;
  void _v;
  void _c;
  return stableJson(rest);
}

function stableJson(v: unknown): string {
  if (Array.isArray(v)) return `[${v.map(stableJson).join(",")}]`;
  if (v && typeof v === "object") {
    return `{${Object.keys(v as Data).sort().map((k) => `${JSON.stringify(k)}:${stableJson((v as Data)[k])}`).join(",")}}`;
  }
  return JSON.stringify(v);
}

/**
 * Writes the config inside a transaction when it differs from [previous].
 * Call after every read of the transaction.
 *
 * @return The new config version, or the old one when nothing changed.
 */
export function writeMenuConfig(
  tx: Transaction,
  db: Firestore,
  rid: string,
  config: MenuConfig,
  previous: Data | undefined,
): { configVersion: number; changed: boolean } {
  const before = typeof previous?.configVersion === "number" ? previous.configVersion : 0;
  if (previous && configFingerprint(previous) === configFingerprint(config)) {
    return { configVersion: before, changed: false };
  }
  const configVersion = before + 1;
  tx.set(menuConfigRef(db, rid), { ...config, configVersion, computedAt: FieldValue.serverTimestamp() });
  return { configVersion, changed: true };
}

/**
 * Recomputes one restaurant's config in its own transaction.
 *
 * @return Whether the document changed; false also when the restaurant is gone.
 */
export async function recomputeMenuConfig(db: Firestore, rid: string, catalog?: Catalog): Promise<boolean> {
  return db.runTransaction(async (tx) => {
    const read = readerFor(tx);
    const [root, prev] = await Promise.all([read.get(db.doc(`restaurants/${rid}`)), read.get(menuConfigRef(db, rid))]);
    if (!root.exists || root.get("status") === "deleted") return false;
    const cat = catalog ?? (await loadCatalog(db, read));
    const config = configFor(cat, root.data() as Data);
    return writeMenuConfig(tx, db, rid, config, prev.exists ? (prev.data() as Data) : undefined).changed;
  });
}

// ---- Item attributes (D7) ----------------------------------------------------

/** Keep in sync with `validItemAttributes()` in firestore.rules and `ItemAttributes` in core. */
export const ATTRIBUTE_LIMITS = {
  maxServingSizes: 6,
  servingLabel: 30,
  maxVolumeMl: 10_000,
  maxAbvTenths: 1000,
  maxPriceMinor: 999_999_999,
} as const;

export const servingSizeSchema = z
  .object({
    label: z.string().trim().min(1).max(ATTRIBUTE_LIMITS.servingLabel),
    volumeMl: z.number().int().min(1).max(ATTRIBUTE_LIMITS.maxVolumeMl).optional(),
    priceMinor: z.number().int().min(0).max(ATTRIBUTE_LIMITS.maxPriceMinor),
  })
  .strict();

export const itemAttributesSchema = z
  .object({
    servingSizes: z.array(servingSizeSchema).max(ATTRIBUTE_LIMITS.maxServingSizes).optional(),
    abvTenths: z.number().int().min(0).max(ATTRIBUTE_LIMITS.maxAbvTenths).optional(),
  })
  .strict();

export type ItemAttributes = z.infer<typeof itemAttributesSchema>;

/** Valid attributes from stored data, or an empty object (publish, export). */
export function attributesOf(v: unknown): ItemAttributes {
  const r = itemAttributesSchema.safeParse(v ?? {});
  return r.success ? r.data : {};
}
