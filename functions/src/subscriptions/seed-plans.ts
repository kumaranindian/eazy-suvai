/**
 * The MVP plans (FRD §4.11, FR-078), seeded by `scripts/seed-platform.mjs`
 * into `plans/{id}`. Admins edit them later (M11).
 */

/**
 * Pro prices, set 2026-11-15 from market rates for menu-only QR tools
 * (ordering and POS bundles cost more): about ₹499 a month in India and the
 * AED 99 band in the Gulf. Annual = 10 months (two months free). Minor units
 * with the ISO 4217 exponent (BR-019): KWD, BHD and OMR have 3 decimals.
 */
export const PRO_PRICES = {
  INR: { monthly: 49900, annual: 499900 }, // ₹499 / ₹4,999
  AED: { monthly: 9900, annual: 99900 }, // AED 99 / 999
  SAR: { monthly: 9900, annual: 99900 }, // SAR 99 / 999
  QAR: { monthly: 9900, annual: 99900 }, // QAR 99 / 999
  KWD: { monthly: 8000, annual: 80000 }, // KWD 8.000 / 80.000
  BHD: { monthly: 10000, annual: 100000 }, // BHD 10.000 / 100.000
  OMR: { monthly: 10000, annual: 100000 }, // OMR 10.000 / 100.000
  USD: { monthly: 1900, annual: 19000 }, // $19 / $190
} as const;

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
    prices: PRO_PRICES,
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
