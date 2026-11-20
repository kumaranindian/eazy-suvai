import { platformConfigSchema } from "./catalog";
import { canTransition, queryKind, statusAction } from "./restaurants";
import { contribution, medianMinutes, statsDelta } from "./stats";

const d = (iso: string) => new Date(iso);

describe("status transitions (FR-088, FR-099)", () => {
  const now = d("2026-11-15T00:00:00Z");
  it.each([
    ["active", "suspended", true],
    ["suspended", "active", true],
    ["active", "deactivated", true],
    ["suspended", "deactivated", true],
    ["deactivated", "suspended", false],
    ["active", "active", false],
    ["deleted", "active", false],
  ] as const)("%s → %s: %s", (from, to, ok) => {
    expect(canTransition(from, to, d("2026-11-01T00:00:00Z"), now)).toBe(ok);
  });

  it("reactivates only within 90 days", () => {
    expect(canTransition("deactivated", "active", d("2026-08-17T00:00:00Z"), now)).toBe(true); // 90 days
    expect(canTransition("deactivated", "active", d("2026-08-16T00:00:00Z"), now)).toBe(false);
    expect(canTransition("deactivated", "active", null, now)).toBe(false);
  });

  it("names the audit actions", () => {
    expect(statusAction("active", "suspended")).toBe("restaurant.suspend");
    expect(statusAction("suspended", "active")).toBe("restaurant.activate");
    expect(statusAction("deactivated", "active")).toBe("restaurant.reactivate");
    expect(statusAction("active", "deactivated")).toBe("restaurant.deactivate");
  });
});

describe("search text (FR-086)", () => {
  it("tells emails, mobiles and names apart", () => {
    expect(queryKind(" Owner@Example.com ")).toEqual({ kind: "email", value: "owner@example.com" });
    expect(queryKind("+91 98765 43210")).toEqual({ kind: "mobile", value: "+919876543210" });
    expect(queryKind("919876543210")).toEqual({ kind: "mobile", value: "+919876543210" });
    expect(queryKind("Spice Garden")).toEqual({ kind: "text", value: "spice garden" });
  });
});

describe("stats deltas (FR-085)", () => {
  const r = (status: string, sub: string, items: number) => ({ status, subscription: { status: sub }, counts: { items } });
  it("counts a new restaurant", () => {
    expect(statsDelta(undefined, r("active", "free", 0))).toEqual({ "restaurants": 1, "restaurantsByStatus.active": 1, "subscriptionsByStatus.free": 1 });
  });
  it("moves status, subscription and items", () => {
    expect(statsDelta(r("active", "grace", 10), r("suspended", "free", 12))).toEqual({
      "restaurantsByStatus.active": -1,
      "restaurantsByStatus.suspended": 1,
      "subscriptionsByStatus.grace": -1,
      "subscriptionsByStatus.free": 1,
      "totalItems": 2,
      "subscriptionsExpired": 1,
    });
  });
  it("ignores unrelated writes and removes deleted documents", () => {
    expect(statsDelta(r("active", "free", 3), { ...r("active", "free", 3), name: "x" })).toEqual({});
    expect(statsDelta(r("deactivated", "free", 3), undefined)).toEqual({ "restaurants": -1, "restaurantsByStatus.deactivated": -1, "subscriptionsByStatus.free": -1, "totalItems": -3 });
    expect(contribution(r("deleted", "free", 0))).toEqual({ "restaurants": 1, "restaurantsByStatus.deleted": 1, "totalItems": 0 });
  });
});

describe("FRD §13 success metrics (M13)", () => {
  it("counts activation, live published menus and QR downloads", () => {
    expect(contribution({ status: "active", publishedVersion: 2, qrDownloads: 3 })).toMatchObject({ activated: 1, publishedMenus: 1, qrDownloads: 3 });
    expect(contribution({ status: "suspended", publishedVersion: 2 })).toMatchObject({ activated: 1 });
    expect(contribution({ status: "suspended", publishedVersion: 2 }).publishedMenus).toBeUndefined();
    expect(contribution({ status: "active" }).activated).toBeUndefined();
    // A purged tombstone keeps its activation.
    expect(contribution({ status: "deleted", activated: true })).toMatchObject({ activated: 1 });
  });

  it("first publish raises activated once", () => {
    expect(statsDelta({ status: "active" }, { status: "active", publishedVersion: 1, firstPublishedAt: new Date() })).toMatchObject({ activated: 1, publishedMenus: 1 });
    expect(statsDelta({ status: "active", publishedVersion: 1 }, { status: "active", publishedVersion: 2 }).activated).toBeUndefined();
  });

  it("takes the median of sign-up to first publish in minutes", () => {
    const at = (m: number) => new Date(Date.UTC(2026, 10, 1) + m * 60_000);
    expect(medianMinutes([])).toBeNull();
    expect(medianMinutes([{ createdAt: at(0), firstPublishedAt: at(20) }])).toBe(20);
    expect(medianMinutes([
      { createdAt: at(0), firstPublishedAt: at(10) },
      { createdAt: at(0), firstPublishedAt: at(30) },
      { createdAt: at(0), firstPublishedAt: at(1000) },
      { createdAt: at(0), firstPublishedAt: at(40) },
    ])).toBe(35);
    // Clock skew (publish before sign-up) is ignored.
    expect(medianMinutes([{ createdAt: at(10), firstPublishedAt: at(0) }])).toBeNull();
  });
});

describe("platform settings: live-check limits on open menu pages", () => {
  const ok = (v: unknown) => platformConfigSchema.safeParse(v).success;
  it("accepts minutes within range and rejects the rest", () => {
    expect(ok({ liveIdleMinutes: 30, liveMaxMinutes: 120 })).toBe(true);
    expect(ok({ liveIdleMinutes: 1, liveMaxMinutes: 5 })).toBe(true);
    expect(ok({ liveIdleMinutes: 240, liveMaxMinutes: 720 })).toBe(true);
    expect(ok({ liveIdleMinutes: 0 })).toBe(false);
    expect(ok({ liveIdleMinutes: 241 })).toBe(false);
    expect(ok({ liveMaxMinutes: 4 })).toBe(false);
    expect(ok({ liveMaxMinutes: 721 })).toBe(false);
    expect(ok({ liveMaxMinutes: 12.5 })).toBe(false);
  });
});
