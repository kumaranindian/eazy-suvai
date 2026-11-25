/**
 * The effective menu configuration of one restaurant (M14): a pure
 * function, the single source of truth for which tag groups, tags, item
 * fields, notices, badges and filters a restaurant has. Every writer of
 * `settings/menuConfig` calls it; the apps only read the result.
 *
 * effective = type groups + capability groups − capability-hidden groups
 *   − owner-disabled optional groups; then capability-hidden tags removed;
 *   then the owner's custom tags added when the plan allows them.
 */
import {
  BADGES,
  CUSTOM_TAG_PREFIX,
  DIET_GROUP_ID,
  ITEM_FIELDS,
  NOTICES,
  SINGLE_SLOTS,
  type Badge,
  type BusinessTypeDef,
  type CapabilityDef,
  type CapabilityFlags,
  type ConfigTag,
  type ConfigTagGroup,
  type CustomTag,
  type ItemField,
  type MenuConfig,
  type MenuConfigInputs,
  type MenuFilter,
  type Notice,
  type RestaurantFeatureFields,
  type StarterCategory,
  type TagDef,
  type TagGroupDef,
} from "./types";

/** Used when a restaurant's type is missing or retired. */
export const FALLBACK_TYPE_ID = "restaurant";

const DEFAULT_TERMS = { itemLabel: "Item", itemLabelPlural: "Items" };

const bySortThenId = <T extends { sort: number; id: string }>(a: T, b: T) =>
  a.sort - b.sort || (a.id < b.id ? -1 : a.id > b.id ? 1 : 0);

function pushUnique<T>(list: T[], values: readonly T[]): void {
  for (const v of values) if (!list.includes(v)) list.push(v);
}

/**
 * Type defaults overlaid by the owner's answers, for every active capability.
 * Unknown keys in either are dropped.
 */
export function effectiveCapabilities(
  type: BusinessTypeDef | null,
  capabilities: Record<string, CapabilityDef>,
  answers: CapabilityFlags,
): CapabilityFlags {
  const out: CapabilityFlags = {};
  for (const c of Object.values(capabilities).filter((c) => c.active).sort(bySortThenId)) {
    const own = answers[c.id];
    out[c.id] = typeof own === "boolean" ? own : type?.defaultCapabilities[c.id] === true;
  }
  return out;
}

function configTag(t: TagDef, custom = false): ConfigTag {
  return { id: t.id, name: t.name, icon: t.icon, color: t.color, retired: t.retired, custom, filter: t.filter === true };
}

/**
 * Computes the menu configuration.
 *
 * @param input Catalog documents, the restaurant's fields and plan flags.
 * @return The `settings/menuConfig` document (without server stamps).
 */
export function computeMenuConfig(input: MenuConfigInputs): MenuConfig {
  const { type, capabilities, tagGroups, restaurant, plan } = input;
  const caps = effectiveCapabilities(type, capabilities, restaurant.capabilities);
  const on = Object.values(capabilities)
    .filter((c) => c.active && caps[c.id])
    .sort(bySortThenId);

  // Groups: type + capabilities − hidden; diet is always there (FR-023).
  const groupIds: string[] = [DIET_GROUP_ID];
  pushUnique(groupIds, type?.tagGroupIds ?? []);
  for (const c of on) pushUnique(groupIds, c.addTagGroupIds);
  const hiddenGroups = new Set(on.flatMap((c) => c.hideTagGroupIds));
  hiddenGroups.delete(DIET_GROUP_ID);
  const candidates = groupIds
    .filter((id) => !hiddenGroups.has(id))
    .map((id) => tagGroups[id])
    .filter((g): g is TagGroupDef => g !== undefined && g.active);
  const optionalGroupIds = candidates.filter((g) => !g.required && g.id !== DIET_GROUP_ID).map((g) => g.id).sort();
  const disabled = new Set(restaurant.disabledTagGroupIds.filter((id) => optionalGroupIds.includes(id)));
  const hiddenTags = new Set(on.flatMap((c) => c.hideTagIds));

  // Custom tags (D8): only with the plan flag, only in enabled non-diet
  // groups, at most maxCustomTags, ids prefixed so they can't shadow
  // platform tags.
  const customByGroup = new Map<string, CustomTag[]>();
  if (plan.customTags) {
    let left = Math.max(0, plan.maxCustomTags);
    for (const t of restaurant.customTags) {
      if (left === 0 && t.retired !== true) continue;
      if (!t.id.startsWith(CUSTOM_TAG_PREFIX) || t.groupId === DIET_GROUP_ID) continue;
      const list = customByGroup.get(t.groupId) ?? [];
      list.push(t);
      customByGroup.set(t.groupId, list);
      if (t.retired !== true) left--;
    }
  }

  const groups: ConfigTagGroup[] = candidates
    .filter((g) => !disabled.has(g.id))
    .sort(bySortThenId)
    .map((g) => {
      const tags = [...g.tags].sort(bySortThenId).filter((t) => !hiddenTags.has(t.id)).map((t) => configTag(t));
      const taken = new Set(tags.map((t) => t.id));
      for (const c of customByGroup.get(g.id) ?? []) {
        if (taken.has(c.id)) continue;
        taken.add(c.id);
        tags.push({
          id: c.id, name: c.name, icon: c.icon ?? "tag", color: c.color ?? "#5D4037",
          retired: c.retired === true, custom: true, filter: false,
        });
      }
      const exclusive = g.exclusive
        .map((set) => ({ ids: set.ids.filter((id) => taken.has(id)) }))
        .filter((set) => set.ids.length > 1);
      return { id: g.id, name: g.name, selection: g.selection, required: g.id === DIET_GROUP_ID || g.required, exclusive, tags };
    });

  const diet = groups.find((g) => g.id === DIET_GROUP_ID);
  const others = groups.filter((g) => g.id !== DIET_GROUP_ID);
  const offered = (g: ConfigTagGroup) => g.tags.filter((t) => !t.retired).map((t) => t.id);

  // Single-choice sets for the rules: single groups, then exclusive sets.
  const singles: string[][] = [
    ...others.filter((g) => g.selection === "single").map((g) => g.tags.map((t) => t.id)),
    ...others.filter((g) => g.selection === "multi").flatMap((g) => g.exclusive.map((s) => s.ids)),
  ].filter((s) => s.length > 1);
  const slot = (i: number) => singles[i] ?? [];

  const itemFields: ItemField[] = [];
  pushUnique(itemFields, (type?.itemFields ?? []).filter((f) => ITEM_FIELDS.includes(f)));
  for (const c of on) pushUnique(itemFields, c.addItemFields.filter((f) => ITEM_FIELDS.includes(f)));
  const notices: Notice[] = [];
  for (const c of on) pushUnique(notices, c.addNotices.filter((n) => NOTICES.includes(n)));
  const badges: Badge[] = [];
  for (const c of on) pushUnique(badges, c.addBadges.filter((b) => BADGES.includes(b)));

  const filters: MenuFilter[] = groups.flatMap((g) =>
    g.tags
      .filter((t) => t.filter && !t.retired)
      .map((t) => ({ id: t.id, kind: g.id === DIET_GROUP_ID ? ("diet" as const) : ("tag" as const) })),
  );

  const starterCategories: StarterCategory[] = [];
  const keys = new Set<string>();
  for (const c of [...(type?.defaultCategories ?? []), ...on.flatMap((c) => c.addCategories)]) {
    if (keys.has(c.key)) continue;
    keys.add(c.key);
    starterCategories.push(c);
  }

  return {
    inputs: {
      businessType: type?.id ?? FALLBACK_TYPE_ID,
      typeVersion: type?.version ?? 0,
      capabilities: caps,
      disabledTagGroupIds: [...disabled].sort(),
      customTags: plan.customTags,
    },
    terminology: type?.terminology ?? DEFAULT_TERMS,
    capabilities: caps,
    tagGroups: groups,
    allowedTagIds: others.flatMap(offered),
    allowedDietIds: diet ? offered(diet) : [],
    single0: slot(0),
    single1: slot(1),
    single2: slot(2),
    single3: slot(3),
    extraSingles: singles.slice(SINGLE_SLOTS).map((ids) => ({ ids })),
    itemFields,
    notices,
    badges,
    filters,
    starterCategories,
    seoIndexableDefault: on.every((c) => c.seoIndexableDefault !== false),
    optionalGroupIds,
  };
}

// ---- Item validation (createItem, publish) ---------------------------------

export type TagProblem =
  | { kind: "diet-missing" }
  | { kind: "diet-not-allowed"; id: string }
  | { kind: "tag-not-allowed"; id: string }
  | { kind: "single-conflict"; ids: string[] }
  | { kind: "required-missing"; groupId: string };

/**
 * Checks an item's diet and tags against a config.
 *
 * @param config The restaurant's menu config.
 * @param dietId `dietaryLabelId`.
 * @param tagIds `tagIds`.
 * @param keep Ids that were on the item before: they may stay even when the
 *   config no longer offers them (hidden, never deleted).
 * @return Problems; empty when valid.
 */
export function checkItemTags(
  config: Pick<MenuConfig, "tagGroups" | "allowedTagIds" | "allowedDietIds">,
  dietId: string | null | undefined,
  tagIds: readonly string[],
  keep: { dietId?: string | null; tagIds?: readonly string[] } = {},
): TagProblem[] {
  const problems: TagProblem[] = [];
  if (!dietId) problems.push({ kind: "diet-missing" });
  else if (!config.allowedDietIds.includes(dietId) && dietId !== keep.dietId) {
    problems.push({ kind: "diet-not-allowed", id: dietId });
  }
  const kept = new Set(keep.tagIds ?? []);
  const allowed = new Set(config.allowedTagIds);
  for (const id of tagIds) {
    if (!allowed.has(id) && !kept.has(id)) problems.push({ kind: "tag-not-allowed", id });
  }
  const ids = new Set(tagIds);
  for (const g of config.tagGroups) {
    if (g.id === DIET_GROUP_ID) continue;
    const sets = g.selection === "single" ? [g.tags.map((t) => t.id)] : g.exclusive.map((s) => s.ids);
    for (const set of sets) {
      const hit = set.filter((id) => ids.has(id));
      if (hit.length > 1) problems.push({ kind: "single-conflict", ids: hit });
    }
    if (g.required && !g.tags.some((t) => ids.has(t.id))) problems.push({ kind: "required-missing", groupId: g.id });
  }
  return problems;
}

/**
 * Tag ids the config shows: ids on an item that are not in any enabled
 * group are hidden (kept on the item).
 */
export function visibleTagIds(config: Pick<MenuConfig, "tagGroups">, tagIds: readonly string[]): string[] {
  const shown = new Set(config.tagGroups.filter((g) => g.id !== DIET_GROUP_ID).flatMap((g) => g.tags.map((t) => t.id)));
  return tagIds.filter((id) => shown.has(id));
}

// ---- Parsing catalog documents (defensive: admin data) ----------------------

type Data = Record<string, unknown>;

const str = (v: unknown, fallback = ""): string => (typeof v === "string" ? v : fallback);
const num = (v: unknown, fallback = 0): number => (typeof v === "number" && Number.isFinite(v) ? v : fallback);
const bool = (v: unknown, fallback = false): boolean => (typeof v === "boolean" ? v : fallback);
const strings = (v: unknown): string[] => (Array.isArray(v) ? v.filter((x): x is string => typeof x === "string") : []);
const flags = (v: unknown): CapabilityFlags => {
  const out: CapabilityFlags = {};
  if (v && typeof v === "object") {
    for (const [k, x] of Object.entries(v as Data)) if (typeof x === "boolean") out[k] = x;
  }
  return out;
};
const categories = (v: unknown): StarterCategory[] =>
  (Array.isArray(v) ? v : [])
    .filter((c): c is Data => !!c && typeof c === "object")
    .map((c) => ({ key: str(c.key), name: str(c.name) }))
    .filter((c) => c.key !== "" && c.name !== "");

export function parseBusinessType(id: string, d: Data | undefined): BusinessTypeDef | null {
  if (!d) return null;
  const terms = (d.terminology ?? {}) as Data;
  return {
    id,
    name: str(d.name, id),
    icon: str(d.icon, "restaurant"),
    sort: num(d.sort),
    active: bool(d.active, true),
    version: num(d.version, 1),
    terminology: {
      itemLabel: str(terms.itemLabel, DEFAULT_TERMS.itemLabel),
      itemLabelPlural: str(terms.itemLabelPlural, DEFAULT_TERMS.itemLabelPlural),
    },
    defaultCapabilities: flags(d.defaultCapabilities),
    defaultCategories: categories(d.defaultCategories),
    tagGroupIds: strings(d.tagGroupIds),
    itemFields: strings(d.itemFields).filter((f): f is ItemField => (ITEM_FIELDS as readonly string[]).includes(f)),
    schemaType: str(d.schemaType, "FoodEstablishment"),
  };
}

export function parseCapability(id: string, d: Data): CapabilityDef {
  return {
    id,
    question: str(d.question, id),
    help: str(d.help),
    sort: num(d.sort),
    active: bool(d.active, true),
    addTagGroupIds: strings(d.addTagGroupIds),
    hideTagGroupIds: strings(d.hideTagGroupIds),
    hideTagIds: strings(d.hideTagIds),
    addItemFields: strings(d.addItemFields).filter((f): f is ItemField => (ITEM_FIELDS as readonly string[]).includes(f)),
    addNotices: strings(d.addNotices).filter((n): n is Notice => (NOTICES as readonly string[]).includes(n)),
    addBadges: strings(d.addBadges).filter((b): b is Badge => (BADGES as readonly string[]).includes(b)),
    addCategories: categories(d.addCategories),
    ...(typeof d.seoIndexableDefault === "boolean" ? { seoIndexableDefault: d.seoIndexableDefault } : {}),
  };
}

export function parseTagGroup(id: string, d: Data): TagGroupDef {
  const tags = (Array.isArray(d.tags) ? d.tags : [])
    .filter((t): t is Data => !!t && typeof t === "object" && typeof (t as Data).id === "string")
    .map((t) => ({
      id: str(t.id),
      name: str(t.name, str(t.id)),
      icon: str(t.icon, "tag"),
      color: /^#[0-9A-Fa-f]{6}$/.test(str(t.color)) ? str(t.color) : "#5D4037",
      sort: num(t.sort),
      retired: bool(t.retired),
      ...(t.filter === true ? { filter: true } : {}),
    }));
  return {
    id,
    name: str(d.name, id),
    sort: num(d.sort),
    active: bool(d.active, true),
    selection: d.selection === "single" ? "single" : "multi",
    required: bool(d.required),
    exclusive: (Array.isArray(d.exclusive) ? d.exclusive : [])
      .map((s) => ({ ids: strings(s && typeof s === "object" ? (s as Data).ids : undefined) }))
      .filter((s) => s.ids.length > 1),
    tags,
  };
}

/** The restaurant fields the config reads, from `restaurants/{rid}` data. */
export function restaurantFeatureFields(d: Data): RestaurantFeatureFields {
  const custom = (Array.isArray(d.customTags) ? d.customTags : [])
    .filter((t): t is Data => !!t && typeof t === "object")
    .map((t) => ({
      id: str(t.id),
      name: str(t.name),
      groupId: str(t.groupId),
      ...(typeof t.icon === "string" ? { icon: t.icon } : {}),
      ...(typeof t.color === "string" && /^#[0-9A-Fa-f]{6}$/.test(t.color) ? { color: t.color } : {}),
      ...(t.retired === true ? { retired: true } : {}),
    }))
    .filter((t) => t.id !== "" && t.name !== "" && t.groupId !== "");
  return {
    businessType: typeof d.businessType === "string" ? d.businessType : null,
    capabilities: flags(d.capabilities),
    disabledTagGroupIds: strings(d.disabledTagGroupIds),
    customTags: custom,
  };
}
