/**
 * Business types, capabilities and tag groups (M14).
 *
 * Platform catalogs (`businessTypes/{id}`, `capabilities/{id}`,
 * `tagGroups/{id}`) are written only by Functions (seed script, admin
 * callables). Each restaurant gets a computed `settings/menuConfig`
 * document (see {@link MenuConfig}); the apps never derive allowed tags
 * themselves (docs/plans/M14-business-types-and-tags.md).
 */

/** Capability ids. Adding one needs no app release (owners see `question`). */
export type CapabilityFlags = Record<string, boolean>;

/** The diet group is stored in `items.dietaryLabelId`, not in `tagIds` (D1). */
export const DIET_GROUP_ID = "diet";

/** Item fields a capability or type can switch on. */
export const ITEM_FIELDS = ["servingSizes", "abv"] as const;
export type ItemField = (typeof ITEM_FIELDS)[number];

/** Public-menu notices. */
export const NOTICES = ["alcohol"] as const;
export type Notice = (typeof NOTICES)[number];

/** Header badges. */
export const BADGES = ["pureVeg"] as const;
export type Badge = (typeof BADGES)[number];

/** Rules check at most this many single-choice sets (`single0`…). */
export const SINGLE_SLOTS = 4;

/** Custom tag ids start with this, so they never collide with platform ids. */
export const CUSTOM_TAG_PREFIX = "c-";

/** Firestore can't store nested arrays, so sets are `{ids}` maps. */
export interface TagSet {
  ids: string[];
}

export interface StarterCategory {
  /** Stable key, so creating starter categories twice adds nothing. */
  key: string;
  name: string;
}

export interface Terminology {
  itemLabel: string;
  itemLabelPlural: string;
}

export interface BusinessTypeDef {
  id: string;
  name: string;
  icon: string;
  sort: number;
  active: boolean;
  version: number;
  terminology: Terminology;
  defaultCapabilities: CapabilityFlags;
  defaultCategories: StarterCategory[];
  tagGroupIds: string[];
  /** Extra item fields for every restaurant of this type (rare). */
  itemFields?: ItemField[];
  /** schema.org type for the public menu's JSON-LD. */
  schemaType: string;
}

export interface CapabilityDef {
  id: string;
  question: string;
  help: string;
  sort: number;
  active: boolean;
  addTagGroupIds: string[];
  hideTagGroupIds: string[];
  hideTagIds: string[];
  addItemFields: ItemField[];
  addNotices: Notice[];
  addBadges: Badge[];
  addCategories: StarterCategory[];
  /** When the capability is on, the menu is left out of search engines unless the owner says otherwise. */
  seoIndexableDefault?: boolean;
}

export interface TagDef {
  id: string;
  name: string;
  icon: string;
  color: string;
  sort: number;
  retired: boolean;
  /** Offered as a filter chip on the public menu. */
  filter?: boolean;
}

export interface TagGroupDef {
  id: string;
  name: string;
  sort: number;
  active: boolean;
  selection: "single" | "multi";
  required: boolean;
  /** Sets of tags inside a multi group of which an item may carry at most one. */
  exclusive: TagSet[];
  tags: TagDef[];
}

/** `restaurants/{rid}.customTags[]` (plan-gated, D8). */
export interface CustomTag {
  id: string;
  name: string;
  groupId: string;
  icon?: string;
  color?: string;
  /** Removed by the owner: kept (hidden) on items that have it, never offered. */
  retired?: boolean;
}

/** Restaurant fields the config depends on. */
export interface RestaurantFeatureFields {
  businessType: string | null;
  /** Owner's answers; a missing key means the type default. */
  capabilities: CapabilityFlags;
  disabledTagGroupIds: string[];
  customTags: CustomTag[];
}

export interface PlanTagFeatures {
  customTags: boolean;
  maxCustomTags: number;
}

export interface MenuConfigInputs {
  type: BusinessTypeDef | null;
  capabilities: Record<string, CapabilityDef>;
  tagGroups: Record<string, TagGroupDef>;
  restaurant: RestaurantFeatureFields;
  plan: PlanTagFeatures;
}

export interface ConfigTag {
  id: string;
  name: string;
  icon: string;
  color: string;
  /** Kept on items that have it, never offered (FR-104). */
  retired: boolean;
  custom: boolean;
  filter: boolean;
}

export interface ConfigTagGroup {
  id: string;
  name: string;
  selection: "single" | "multi";
  required: boolean;
  exclusive: TagSet[];
  tags: ConfigTag[];
}

export interface MenuFilter {
  id: string;
  kind: "diet" | "tag";
}

/** `restaurants/{rid}/settings/menuConfig` without the server stamps. */
export interface MenuConfig {
  /** What the config was computed from, to skip recomputes that change nothing. */
  inputs: {
    businessType: string;
    typeVersion: number;
    capabilities: CapabilityFlags;
    disabledTagGroupIds: string[];
    customTags: boolean;
  };
  terminology: Terminology;
  /** Effective capability values (type defaults overlaid by the owner's answers). */
  capabilities: CapabilityFlags;
  tagGroups: ConfigTagGroup[];
  /** Non-diet tags an owner may add to an item (rules). */
  allowedTagIds: string[];
  /** Diet labels an owner may choose (rules). */
  allowedDietIds: string[];
  single0: string[];
  single1: string[];
  single2: string[];
  single3: string[];
  /** Single-choice sets beyond the four the rules check (Functions still check them). */
  extraSingles: TagSet[];
  itemFields: ItemField[];
  notices: Notice[];
  badges: Badge[];
  filters: MenuFilter[];
  starterCategories: StarterCategory[];
  seoIndexableDefault: boolean;
  /** Optional groups the owner may switch off (settings page). */
  optionalGroupIds: string[];
}
