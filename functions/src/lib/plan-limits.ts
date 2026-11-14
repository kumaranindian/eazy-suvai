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
