/**
 * The MVP plans (FRD §4.11, FR-078), seeded by `scripts/seed-platform.mjs`
 * into `plans/{id}`. Admins edit them later (M11). Prices are an open
 * decision (master plan), so `prices` starts empty.
 */
export const SEED_PLANS = [
  {
    id: "free",
    name: "Free",
    isFree: true,
    active: true,
    sort: 0,
    billing: [] as string[],
    prices: {},
    limits: {
      maxItems: 50,
      maxCategories: 10,
      maxBranches: 1,
      premiumThemes: false,
      defaultThemeId: "saffron",
      analyticsDays: 7,
      qrLogo: false,
      removeBranding: false,
    },
  },
  {
    id: "pro",
    name: "Pro",
    isFree: false,
    active: true,
    sort: 1,
    billing: ["monthly", "annual"],
    prices: {},
    limits: {
      maxItems: 500,
      // "Unlimited" (FRD), stored as a high number (M10 plan).
      maxCategories: 10000,
      maxBranches: 1,
      premiumThemes: true,
      defaultThemeId: "saffron",
      analyticsDays: 365,
      qrLogo: true,
      removeBranding: true,
    },
  },
] as const;
