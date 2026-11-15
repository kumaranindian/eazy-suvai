/**
 * Plan limits for menu content (FR-078, BR-011).
 *
 * `plans/{planId}.limits` is the source of truth. M10 seeds the plans and
 * owns this helper from then on; until a plan document exists, the FRD
 * §4.11 MVP limits below apply, so a missing document never means
 * "unlimited".
 */
export interface PlanLimits {
  /** Maximum non-deleted items, or null for unlimited. */
  maxItems: number | null;
  /** Maximum non-deleted categories, or null for unlimited. */
  maxCategories: number | null;
}

/** FRD §4.11: Free 50 items / 10 categories; Pro 500 items / unlimited. */
export const DEFAULT_PLAN_LIMITS: Readonly<Record<string, PlanLimits>> = {
  free: { maxItems: 50, maxCategories: 10 },
  pro: { maxItems: 500, maxCategories: null },
};

/** Reads one document's data, for example through a transaction. */
export type DocDataReader = (path: string) => Promise<Record<string, unknown> | undefined>;

function limitOf(value: unknown, fallback: number | null): number | null {
  if (value === null) return null;
  if (typeof value === "number" && Number.isInteger(value)) return value < 0 ? null : value;
  return fallback;
}

/**
 * Limits from a plan document's data, falling back to the FRD defaults for
 * the plan id (unknown plans fall back to Free).
 *
 * A limit stored as `null` or a negative number means unlimited.
 *
 * @param planId The restaurant's `planId`.
 * @param data `plans/{planId}` data, if the document exists.
 * @return The limits.
 */
export function planLimitsFrom(planId: string, data: Record<string, unknown> | undefined): PlanLimits {
  const fallback = DEFAULT_PLAN_LIMITS[planId] ?? DEFAULT_PLAN_LIMITS.free;
  const limits = data?.limits as Record<string, unknown> | undefined;
  if (!limits) return fallback;
  return {
    maxItems: limitOf(limits.maxItems, fallback.maxItems),
    maxCategories: limitOf(limits.maxCategories, fallback.maxCategories),
  };
}

/**
 * Reads `plans/{planId}` and returns its menu limits.
 *
 * @param read Reads a document (use the transaction's reader so the check
 *   is consistent with the write).
 * @param planId The restaurant's `planId` (defaults to `free`).
 * @return The limits.
 */
export async function getPlanLimits(read: DocDataReader, planId: unknown): Promise<PlanLimits> {
  const id = typeof planId === "string" && /^[A-Za-z0-9_-]{1,64}$/.test(planId) ? planId : "free";
  return planLimitsFrom(id, await read(`plans/${id}`));
}

/**
 * Whether the plan hides the "Powered by EazySuvai" footer on the public
 * menu (M07; `plans/{planId}.limits.removeBranding`). Until M10 seeds the
 * plans: Free shows it, Pro hides it. Whether Free shows it at all is an
 * open decision (master plan); setting the flag on `plans/free` turns it off.
 *
 * @param planId The restaurant's `planId`.
 * @param data `plans/{planId}` data, if the document exists.
 * @return true when the footer is hidden.
 */
export function removeBrandingFrom(planId: string, data: Record<string, unknown> | undefined): boolean {
  const flag = (data?.limits as Record<string, unknown> | undefined)?.removeBranding;
  if (typeof flag === "boolean") return flag;
  return planId === "pro";
}

/**
 * Every plan flag (FR-078; architecture §4.1 `plans/{planId}.limits`).
 * Copied to `restaurants/{rid}.planFeatures` when the plan changes, so the
 * security rules (premium themes) and the apps (QR logo, analytics range)
 * read one field instead of the plan document (FR-077: plan edits reach
 * subscribers only when applied).
 */
export interface PlanFeatures extends PlanLimits {
  maxBranches: number;
  /** Premium themes allowed (`themes/{id}.premium`). */
  premiumThemes: boolean;
  /** Theme a premium theme reverts to on downgrade (FR-101). */
  defaultThemeId: string;
  /** Analytics history in days (FR-074). */
  analyticsDays: number;
  /** Logo in the QR code (FR-053). */
  qrLogo: boolean;
  /** Hide "Powered by EazySuvai" on the public menu. */
  removeBranding: boolean;
}

/** FRD §4.11 MVP plans. Categories "unlimited" is stored as 10000 in the seed. */
export const DEFAULT_PLAN_FEATURES: Readonly<Record<string, PlanFeatures>> = {
  free: {
    ...DEFAULT_PLAN_LIMITS.free,
    maxBranches: 1,
    premiumThemes: false,
    defaultThemeId: "saffron",
    analyticsDays: 7,
    qrLogo: false,
    removeBranding: false,
  },
  pro: {
    ...DEFAULT_PLAN_LIMITS.pro,
    maxBranches: 1,
    premiumThemes: true,
    defaultThemeId: "saffron",
    analyticsDays: 365,
    qrLogo: true,
    removeBranding: true,
  },
};

function boolOf(v: unknown, fallback: boolean): boolean {
  return typeof v === "boolean" ? v : fallback;
}

function intOf(v: unknown, fallback: number, min: number, max: number): number {
  return typeof v === "number" && Number.isInteger(v) && v >= min && v <= max ? v : fallback;
}

/**
 * All flags of a plan document, with the FRD defaults for anything
 * missing (unknown plans fall back to Free).
 */
export function planFeaturesFrom(planId: string, data: Record<string, unknown> | undefined): PlanFeatures {
  const fallback = DEFAULT_PLAN_FEATURES[planId] ?? DEFAULT_PLAN_FEATURES.free;
  const l = (data?.limits ?? {}) as Record<string, unknown>;
  const theme = typeof l.defaultThemeId === "string" && /^[A-Za-z0-9_-]{1,64}$/.test(l.defaultThemeId)
    ? l.defaultThemeId
    : fallback.defaultThemeId;
  return {
    ...planLimitsFrom(planId, data),
    maxBranches: intOf(l.maxBranches, fallback.maxBranches, 1, 1000),
    premiumThemes: boolOf(l.premiumThemes, fallback.premiumThemes),
    defaultThemeId: theme,
    analyticsDays: intOf(l.analyticsDays, fallback.analyticsDays, 1, 3660),
    qrLogo: boolOf(l.qrLogo, fallback.qrLogo),
    removeBranding: boolOf(l.removeBranding, fallback.removeBranding),
  };
}

/** Reads `plans/{planId}` and returns all its flags. */
export async function getPlanFeatures(read: DocDataReader, planId: unknown): Promise<PlanFeatures> {
  const id = typeof planId === "string" && /^[A-Za-z0-9_-]{1,64}$/.test(planId) ? planId : "free";
  return planFeaturesFrom(id, await read(`plans/${id}`));
}

/**
 * The subset copied to `restaurants/{rid}.planFeatures` (read by the rules
 * and the owner app).
 */
export function restaurantPlanFeatures(f: PlanFeatures): Record<string, unknown> {
  return {
    maxItems: f.maxItems,
    maxCategories: f.maxCategories,
    premiumThemes: f.premiumThemes,
    analyticsDays: f.analyticsDays,
    qrLogo: f.qrLogo,
    removeBranding: f.removeBranding,
  };
}
