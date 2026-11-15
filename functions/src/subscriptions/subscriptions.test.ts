import { DEFAULT_PLAN_FEATURES, planFeaturesFrom, restaurantPlanFeatures } from "../lib/plan-limits";
import type { DocEntry } from "../publishing/snapshot";
import { ProblemCode, validateDraft } from "../publishing/snapshot";
import { chooseHidden } from "./apply-limits";
import { mailContent } from "./mail";
import { dailyActionFor, daysUntil, freeSubscription, graceDaysFrom, subscriptionFrom, type Subscription } from "./model";
import { SEED_PLANS } from "./seed-plans";

const d = (iso: string) => new Date(iso);
const pro = (over: Partial<Subscription> = {}): Subscription => ({
  status: "active",
  planId: "pro",
  billing: "annual",
  startAt: d("2025-12-01T00:00:00Z"),
  expiresAt: d("2026-12-01T00:00:00Z"),
  graceEndsAt: null,
  remindersSent: [],
  ...over,
});

describe("plans (FR-078)", () => {
  it("seeds Free and Pro as the FRD table says", () => {
    const [free, proPlan] = SEED_PLANS;
    expect(planFeaturesFrom("free", free)).toEqual({
      maxItems: 50, maxCategories: 10, maxBranches: 1, premiumThemes: false, defaultThemeId: "saffron", analyticsDays: 7, qrLogo: false, removeBranding: false,
    });
    expect(planFeaturesFrom("pro", proPlan)).toMatchObject({ maxItems: 500, maxCategories: 10000, premiumThemes: true, analyticsDays: 365, qrLogo: true });
  });

  it("falls back to the FRD values and ignores bad fields", () => {
    expect(planFeaturesFrom("pro", undefined)).toEqual(DEFAULT_PLAN_FEATURES.pro);
    expect(planFeaturesFrom("free", { limits: { analyticsDays: -3, qrLogo: "yes", defaultThemeId: "../x" } })).toEqual(DEFAULT_PLAN_FEATURES.free);
    expect(restaurantPlanFeatures(DEFAULT_PLAN_FEATURES.free)).toEqual({
      maxItems: 50, maxCategories: 10, premiumThemes: false, analyticsDays: 7, qrLogo: false, removeBranding: false,
    });
  });
});

describe("dailyActionFor (FR-100) with fixed dates", () => {
  const at = (iso: string, sub: Subscription, grace = 14) => dailyActionFor(sub, d(iso), grace);

  it("does nothing on Free, and early in a paid period", () => {
    expect(at("2026-11-15T00:00:00Z", freeSubscription())).toEqual({ kind: "none" });
    expect(at("2026-11-01T00:00:00Z", pro())).toEqual({ kind: "none" }); // 30 days left
  });

  it("sends the 14, 7 and 1 day reminders once each", () => {
    let sub = pro();
    const sent: number[] = [];
    for (const day of ["2026-11-17", "2026-11-18", "2026-11-24", "2026-11-25", "2026-11-30", "2026-11-30"]) {
      const a = dailyActionFor(sub, d(`${day}T01:00:00Z`), 14);
      if (a.kind === "remind") {
        sent.push(a.days);
        sub = { ...sub, remindersSent: [...new Set([...sub.remindersSent, ...a.markSent])] };
      }
    }
    expect(sent).toEqual([14, 7, 1]);
  });

  it("sends only the nearest reminder after a missed run", () => {
    const a = at("2026-11-30T12:00:00Z", pro()); // 12 hours left, nothing sent yet
    expect(a).toEqual({ kind: "remind", days: 1, daysLeft: 1, markSent: [14, 7, 1] });
  });

  it("enters grace at expiry for config/platform.graceDays", () => {
    expect(at("2026-12-01T00:00:00Z", pro())).toEqual({ kind: "enterGrace", graceEndsAt: d("2026-12-15T00:00:00Z") });
    expect(at("2026-12-01T05:00:00Z", pro(), 30)).toEqual({ kind: "enterGrace", graceEndsAt: d("2026-12-31T00:00:00Z") });
    expect(at("2026-12-01T05:00:00Z", pro(), 0)).toEqual({ kind: "downgrade" });
  });

  it("keeps working in grace, then downgrades when it ends", () => {
    const grace = pro({ status: "grace", graceEndsAt: d("2026-12-15T00:00:00Z") });
    expect(at("2026-12-14T23:59:59Z", grace)).toEqual({ kind: "none" });
    expect(at("2026-12-15T00:00:00Z", grace)).toEqual({ kind: "downgrade" });
  });

  it("reads grace days and stored subscriptions defensively", () => {
    expect([graceDaysFrom(undefined), graceDaysFrom(7), graceDaysFrom(99), graceDaysFrom(-1), graceDaysFrom(2.5)]).toEqual([14, 7, 30, 14, 14]);
    expect(subscriptionFrom({ status: "weird" }, "pro").status).toBe("free");
    const s = subscriptionFrom({ status: "active", expiresAt: { toDate: () => d("2027-01-01T00:00:00Z") }, remindersSent: [14, "x"] }, "pro");
    expect(s).toMatchObject({ status: "active", planId: "pro", remindersSent: [14] });
    expect(s.expiresAt?.toISOString()).toBe("2027-01-01T00:00:00.000Z");
    expect(daysUntil(d("2026-12-01T00:00:00Z"), d("2026-11-30T23:00:00Z"))).toBe(1);
  });
});

describe("chooseHidden (FR-101: last in display order first, never un-hide)", () => {
  const cat = (id: string, sequence: number, extra = {}): DocEntry => ({ id, data: { sequence, deletedAt: null, ...extra } });
  const item = (id: string, categoryId: string, sequence: number, extra = {}): DocEntry => ({ id, data: { categoryId, sequence, deletedAt: null, ...extra } });

  it("hides the last categories and items beyond the limits", () => {
    const cats = [cat("c2", 2000), cat("c1", 1000), cat("c3", 3000), cat("cx", 500, { deletedAt: new Date() })];
    const items = [
      item("a", "c1", 1000), item("b", "c1", 2000), item("c", "c2", 1000), item("d", "c3", 1000), item("e", "c2", 500),
      item("deleted", "c1", 3000, { deletedAt: new Date() }),
    ];
    expect(chooseHidden(cats, items, { maxItems: 3, maxCategories: 2 })).toEqual({
      categories: ["c3"],
      // d is in the hidden c3; of a, b, e, c (display order) keep a, b, e.
      items: ["d", "c"],
    });
  });

  it("respects content the owner already hid and unlimited plans", () => {
    const cats = [cat("c1", 1)];
    const items = [item("a", "c1", 1), item("b", "c1", 2, { hiddenOverLimit: true }), item("c", "c1", 3)];
    expect(chooseHidden(cats, items, { maxItems: 2, maxCategories: 10 })).toEqual({ categories: [], items: [] });
    expect(chooseHidden(cats, items, { maxItems: 1, maxCategories: 10 })).toEqual({ categories: [], items: ["c"] });
    expect(chooseHidden(cats, items, { maxItems: null, maxCategories: null })).toEqual({ categories: [], items: [] });
  });
});

describe("premium theme at publish (BR-011)", () => {
  it("blocks a premium theme on a plan without premium themes", () => {
    const input = { restaurant: { themeId: "midnight", name: "x" }, categories: [], items: [], labels: {}, tags: {}, themeTokens: null, imageUrls: {} };
    const base = { emailVerified: true, pricesNeedReview: false, pricesReviewed: false, maxItems: 50, maxCategories: 10, planId: "free" };
    const snapshot = { items: [], categories: [] } as never;
    expect(validateDraft(input, snapshot, { ...base, themePremium: true, premiumThemes: false }).map((p) => p.code)).toContain(ProblemCode.premiumTheme);
    expect(validateDraft(input, snapshot, { ...base, themePremium: true, premiumThemes: true }).map((p) => p.code)).not.toContain(ProblemCode.premiumTheme);
  });
});

describe("emails", () => {
  it("say the right thing", () => {
    expect(mailContent("reminder", { name: "Spice", days: 1, date: d("2026-12-01T00:00:00Z") }).subject).toBe("Your Pro plan ends in 1 day");
    expect(mailContent("reminder", { name: "Spice", days: 7 }).subject).toBe("Your Pro plan ends in 7 days");
    expect(mailContent("limitsApplied", { name: "Spice", hiddenItems: 3, hiddenCategories: 1 }).text).toContain("3 item(s) and 1 category is hidden");
    expect(mailContent("activated", { name: "Spice", planName: "Pro", date: d("2027-11-15T00:00:00Z") }).text).toContain("15 November 2027");
  });
});
