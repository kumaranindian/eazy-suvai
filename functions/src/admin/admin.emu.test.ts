import { Timestamp } from "firebase-admin/firestore";

import { appErrorCodeOf } from "../lib/errors";
import { admin as emu, resetEmulators } from "../testing/emulator";
import { SEED_THEMES } from "../theme";
import { SEED_PLANS } from "../subscriptions/seed-plans";
import { adminDashboard, adminListAdmins, setAdminRole, type AdminAuth } from "./admins";
import { adminListCatalog, setAnnouncement, updatePlatformConfig, upsertLabel, upsertPlan, upsertTheme } from "./catalog";
import { adminGetRestaurant, adminSearchRestaurants, setRestaurantStatus } from "./restaurants";
import { readPlatformStats, recomputeStats } from "./stats";

const { db } = emu();
const ADMIN = { uid: "admin1", token: { email_verified: true, role: "platformAdmin", firebase: { sign_in_second_factor: "totp" } } };
const OWNER = { uid: "u1", token: { email_verified: true, role: "owner", restaurantId: "r1" } };

async function codeOf(p: Promise<unknown>): Promise<string | undefined> {
  try {
    await p;
  } catch (e) {
    return appErrorCodeOf(e) ?? String(e);
  }
  throw new Error("expected rejection");
}

const auditActions = async () => (await db.collection("auditLogs").get()).docs.map((d) => d.get("action") as string);

/** A fake Firebase Auth for revocations, claims and sign-in times. */
function fakeAuth() {
  const users: Record<string, { uid: string; email: string; customClaims?: Record<string, unknown> }> = {
    "admin@example.com": { uid: "admin1", email: "admin@example.com", customClaims: { role: "platformAdmin" } },
    "staff@example.com": { uid: "staff1", email: "staff@example.com" },
    "owner@example.com": { uid: "u1", email: "owner@example.com", customClaims: { role: "owner", restaurantId: "r1" } },
  };
  const revoked: string[] = [];
  const auth = {
    revoked,
    users,
    async revokeRefreshTokens(uid: string) {
      revoked.push(uid);
    },
    async getUser(uid: string) {
      return { uid, disabled: false, metadata: { creationTime: "Sat, 14 Nov 2026 10:00:00 GMT", lastSignInTime: "Sun, 15 Nov 2026 09:00:00 GMT", lastRefreshTime: null } } as never;
    },
    async getUserByEmail(email: string) {
      const u = users[email];
      if (!u) throw Object.assign(new Error("nope"), { code: "auth/user-not-found" });
      return u;
    },
    async setCustomUserClaims(uid: string, claims: Record<string, unknown>) {
      const u = Object.values(users).find((x) => x.uid === uid)!;
      u.customClaims = claims;
    },
    async listUsers() {
      return { users: [] };
    },
  };
  return auth;
}

async function restaurant(id: string, fields: Record<string, unknown>) {
  await db.doc(`restaurants/${id}`).set({
    name: "Spice Garden",
    nameLower: "spice garden",
    slug: `slug-${id}`,
    ownerUid: `owner_${id}`,
    ownerEmail: `${id}@example.com`,
    ownerMobile: "+919800000000",
    country: "IN",
    status: "active",
    planId: "free",
    subscription: { status: "free", planId: "free" },
    counts: { items: 5, categories: 1 },
    createdAt: Timestamp.fromDate(new Date("2026-11-01T00:00:00Z")),
    ...fields,
  });
  await db.doc(`slugs/slug-${id}`).set({ restaurantId: id, current: true });
}

beforeEach(async () => {
  await resetEmulators();
  await Promise.all([...SEED_THEMES.map((t) => db.doc(`themes/${t.id}`).set({ name: t.name, premium: t.premium, tokens: t.tokens })), ...SEED_PLANS.map(({ id, ...p }) => db.doc(`plans/${id}`).set(p))]);
});

describe("admin-only (FR-084, AC: owners cannot call admin functions)", () => {
  it("refuses owners and anonymous callers everywhere", async () => {
    const calls = [
      () => setRestaurantStatus(db, OWNER, { restaurantId: "r1", status: "suspended", reason: "abc" }),
      () => adminSearchRestaurants(db, OWNER, {}),
      () => adminGetRestaurant(db, OWNER, { restaurantId: "r1" }),
      () => adminDashboard(db, OWNER),
      () => adminListAdmins(db, OWNER),
      () => adminListCatalog(db, OWNER, { kind: "plans" }),
      () => upsertLabel(db, OWNER, {}),
      () => upsertTheme(db, OWNER, {}),
      () => upsertPlan(db, OWNER, {}),
      () => updatePlatformConfig(db, OWNER, { graceDays: 3 }),
      () => setAnnouncement(db, OWNER, { text: "x", active: true }),
      () => setAdminRole(db, OWNER, { email: "x@example.com", grant: true, reason: "abc" }, { auth: fakeAuth() as unknown as AdminAuth }),
    ];
    for (const call of calls) expect(await codeOf(call())).toBe("permission-denied");
    expect(await codeOf(adminDashboard(db, null))).toBe("unauthenticated");
  });
});

describe("setRestaurantStatus (AC-016)", () => {
  it("suspends, reactivates, deactivates and reactivates within 90 days, with reasons and audit", async () => {
    await restaurant("r1", {});
    const auth = fakeAuth();
    const deps = { auth, now: () => new Date("2026-11-15T00:00:00Z") };
    expect(await codeOf(setRestaurantStatus(db, ADMIN, { restaurantId: "r1", status: "suspended", reason: "" }, deps))).toBe("invalid-input");
    await setRestaurantStatus(db, ADMIN, { restaurantId: "r1", status: "suspended", reason: "Unpaid invoice" }, deps);
    let r = (await db.doc("restaurants/r1").get()).data()!;
    expect([r.status, r.statusReason]).toEqual(["suspended", "Unpaid invoice"]);
    expect((await db.doc("users/owner_r1").get()).get("accountStatus")).toBe("suspended");
    expect(auth.revoked).toEqual(["owner_r1"]);
    await setRestaurantStatus(db, ADMIN, { restaurantId: "r1", status: "active", reason: "Paid" }, deps);
    await setRestaurantStatus(db, ADMIN, { restaurantId: "r1", status: "deactivated", reason: "Closed down" }, deps);
    r = (await db.doc("restaurants/r1").get()).data()!;
    expect((r.deactivatedAt as Timestamp).toDate().toISOString()).toBe("2026-11-15T00:00:00.000Z");
    expect(await codeOf(setRestaurantStatus(db, ADMIN, { restaurantId: "r1", status: "suspended", reason: "nope" }, deps))).toBe("invalid-input");
    // 91 days later it can no longer be reactivated (FR-099).
    expect(await codeOf(setRestaurantStatus(db, ADMIN, { restaurantId: "r1", status: "active", reason: "Back" }, { auth, now: () => new Date("2027-02-14T00:00:01Z") }))).toBe("invalid-input");
    await setRestaurantStatus(db, ADMIN, { restaurantId: "r1", status: "active", reason: "Reopened" }, { auth, now: () => new Date("2026-12-01T00:00:00Z") });
    r = (await db.doc("restaurants/r1").get()).data()!;
    expect(r.status).toBe("active");
    expect(r.deactivatedAt).toBeUndefined();
    expect((await db.doc("users/owner_r1").get()).get("accountStatus")).toBe("active");
    const audit = (await db.collection("auditLogs").where("restaurantId", "==", "r1").get()).docs.map((d) => [d.get("action"), d.get("reason")]);
    expect(audit).toEqual(expect.arrayContaining([
      ["restaurant.suspend", "Unpaid invoice"],
      ["restaurant.activate", "Paid"],
      ["restaurant.deactivate", "Closed down"],
      ["restaurant.reactivate", "Reopened"],
    ]));
    expect(auth.revoked).toEqual(["owner_r1", "owner_r1"]);
  });
});

describe("search and detail (FR-086, FR-087, FR-089)", () => {
  beforeEach(async () => {
    await restaurant("r1", { name: "Spice Garden", nameLower: "spice garden", ownerEmail: "spice@example.com", ownerMobile: "+919876543210" });
    await restaurant("r2", { name: "Spice Route", nameLower: "spice route", country: "AE", planId: "pro", createdAt: Timestamp.fromDate(new Date("2026-11-10T00:00:00Z")) });
    await restaurant("r3", { name: "Dosa Corner", nameLower: "dosa corner", status: "suspended", createdAt: Timestamp.fromDate(new Date("2026-10-01T00:00:00Z")) });
  });

  it("finds by name prefix, slug, email and mobile, and filters", async () => {
    const ids = async (input: Record<string, unknown>) => (await adminSearchRestaurants(db, ADMIN, input)).rows.map((r) => r.id);
    expect((await ids({ query: "spice" })).sort()).toEqual(["r1", "r2"]);
    expect(await ids({ query: "slug-r3" })).toEqual(["r3"]);
    expect(await ids({ query: "SPICE@example.com" })).toEqual(["r1"]);
    expect(await ids({ query: "+91 98765 43210" })).toEqual(["r1"]);
    expect(await ids({ status: "suspended" })).toEqual(["r3"]);
    expect(await ids({ planId: "pro" })).toEqual(["r2"]);
    expect(await ids({ country: "IN" })).toEqual(["r1", "r3"]);
    expect(await ids({ createdFrom: "2026-11-05", createdTo: "2026-11-30" })).toEqual(["r2"]);
    expect(await ids({ query: "spice", country: "AE" })).toEqual(["r2"]);
  });

  it("pages by registration date, newest first", async () => {
    const p1 = await adminSearchRestaurants(db, ADMIN, { pageSize: 2 });
    expect(p1.rows.map((r) => r.id)).toEqual(["r2", "r1"]);
    expect(p1.nextCursor).toBe("r1");
    const p2 = await adminSearchRestaurants(db, ADMIN, { pageSize: 2, cursor: p1.nextCursor });
    expect(p2.rows.map((r) => r.id)).toEqual(["r3"]);
    expect(p2.nextCursor).toBeNull();
  });

  it("shows subscription, payments, history and activity", async () => {
    await db.doc("restaurants/r1/payments/p1").set({ amountMinor: 99900, currency: "INR", method: "upi", provider: "offline", reference: "UPI-1", planId: "pro", paidAt: Timestamp.fromDate(new Date("2026-11-02T00:00:00Z")), recordedBy: "admin1" });
    await db.doc("restaurants/r1/subscriptionHistory/h1").set({ action: "activate", fromPlanId: "free", toPlanId: "pro", at: Timestamp.now(), by: "admin1" });
    await db.collection("auditLogs").add({ action: "menu.publish", restaurantId: "r1", actorRole: "owner", actorUid: "u1", at: Timestamp.now(), details: { version: 3 } });
    await db.collection("auditLogs").add({ action: "item.something", restaurantId: "r1", actorRole: "owner", actorUid: "u1", at: Timestamp.now() });
    const detail = (await adminGetRestaurant(db, ADMIN, { restaurantId: "r1" }, { auth: fakeAuth() })) as Record<string, any>; // eslint-disable-line @typescript-eslint/no-explicit-any
    expect(detail.restaurant).toMatchObject({ id: "r1", name: "Spice Garden", status: "active", planId: "free" });
    expect(detail.payments).toEqual([expect.objectContaining({ amountMinor: 99900, method: "upi", reference: "UPI-1", paidAt: "2026-11-02T00:00:00.000Z" })]);
    expect(detail.history[0]).toMatchObject({ action: "activate", toPlanId: "pro" });
    expect(detail.activity.map((a: { action: string }) => a.action)).toEqual(["menu.publish"]);
    expect(detail.signIns.lastSignInAt).toBe("Sun, 15 Nov 2026 09:00:00 GMT");
    expect(await codeOf(adminGetRestaurant(db, ADMIN, { restaurantId: "nope" }))).toBe("not-found");
  });
});

describe("editors (FR-059, FR-076, FR-104)", () => {
  it("creates, updates and retires labels and tags", async () => {
    await upsertLabel(db, ADMIN, { kind: "label", id: "jain", name: "Jain", icon: "veg", color: "#2e7d32", sort: 50 });
    expect((await db.doc("dietaryLabels/jain").get()).data()).toMatchObject({ name: "Jain", color: "#2E7D32", retired: false });
    await upsertLabel(db, ADMIN, { kind: "label", id: "jain", name: "Jain", icon: "veg", color: "#2E7D32", sort: 50, retired: true, reason: "Merged into vegetarian" });
    await upsertLabel(db, ADMIN, { kind: "tag", id: "seasonal", name: "Seasonal", icon: "new", color: "#123456", sort: 5 });
    expect(await codeOf(upsertLabel(db, ADMIN, { kind: "tag", id: "Bad Id", name: "x", icon: "new", color: "#123456", sort: 1 }))).toBe("invalid-input");
    expect(await codeOf(upsertLabel(db, ADMIN, { kind: "tag", id: "x", name: "x", icon: "rocket", color: "#123456", sort: 1 }))).toBe("invalid-input");
    expect((await db.doc("dietaryLabels/jain").get()).exists).toBe(true); // retired, never deleted
    expect(await auditActions()).toEqual(expect.arrayContaining(["label.create", "label.retire", "tag.create"]));
  });

  it("refuses themes with unreadable text unless accepted", async () => {
    const tokens = { primary: "#A8550A", secondary: "#3B7A20", background: "#FFFFFF", surface: "#FFFFFF", text: "#EEEEEE", font: "Poppins", layout: "list", cardLayout: "compact", mode: "light" };
    expect(await codeOf(upsertTheme(db, ADMIN, { id: "pale", name: "Pale", premium: true, sort: 9, tokens }))).toBe("invalid-input");
    const res = await upsertTheme(db, ADMIN, { id: "pale", name: "Pale", premium: true, sort: 9, tokens, acceptContrastFixes: true });
    expect(res.issues.length).toBeGreaterThan(0);
    await upsertTheme(db, ADMIN, { id: "ok", name: "Ok", premium: false, sort: 8, tokens: { ...tokens, text: "#222222" } });
    expect(await auditActions()).toEqual(expect.arrayContaining(["theme.create"]));
  });

  it("edits plans and applies the flags to subscribers when asked (FR-077)", async () => {
    await restaurant("r1", { planId: "pro", planFeatures: { qrLogo: true } });
    const pro = SEED_PLANS[1];
    const base = { id: "pro", name: "Pro", isFree: false, active: true, sort: 1, billing: ["monthly", "annual"], prices: { INR: { monthly: 49900, annual: 499900 } }, limits: { ...pro.limits, qrLogo: false } };
    expect((await upsertPlan(db, ADMIN, base)).applied).toBe(0);
    expect((await db.doc("restaurants/r1").get()).get("planFeatures.qrLogo")).toBe(true);
    expect((await upsertPlan(db, ADMIN, { ...base, applyToSubscribers: true, reason: "No QR logo on Pro" })).applied).toBe(1);
    expect((await db.doc("restaurants/r1").get()).get("planFeatures.qrLogo")).toBe(false);
    expect((await db.doc("plans/pro").get()).get("prices.INR.annual")).toBe(499900);
    expect(await codeOf(upsertPlan(db, ADMIN, { ...base, limits: { ...base.limits, defaultThemeId: "midnight" } }))).toBe("invalid-input");
    expect(await codeOf(upsertPlan(db, ADMIN, { ...base, id: "free", isFree: false }))).toBe("invalid-input");
    const planAudit = (await db.collection("auditLogs").where("action", "==", "plan.update").get()).docs.map((d) => d.get("reason") ?? null);
    expect(planAudit).toEqual(expect.arrayContaining([null, "No QR logo on Pro"]));
  });

  it("updates platform settings and the announcement", async () => {
    await updatePlatformConfig(db, ADMIN, { graceDays: 7, reservedSlugs: ["admin", "api", "admin"], fonts: ["Poppins", "Inter"], currencies: { INR: 2, KWD: 3 }, supportEmail: "help@eazysuvai.com", liveIdleMinutes: 15, liveMaxMinutes: 90 });
    expect(await codeOf(updatePlatformConfig(db, ADMIN, { graceDays: 45 }))).toBe("invalid-input");
    expect(await codeOf(updatePlatformConfig(db, ADMIN, { liveMaxMinutes: 1000 }))).toBe("invalid-input");
    await setAnnouncement(db, ADMIN, { text: "Maintenance on Sunday 2 am", level: "warning", active: true });
    expect(await codeOf(setAnnouncement(db, ADMIN, { text: "", active: true }))).toBe("invalid-input");
    const { config } = (await adminListCatalog(db, ADMIN, { kind: "config" })) as { config: Record<string, any> }; // eslint-disable-line @typescript-eslint/no-explicit-any
    expect(config).toMatchObject({ graceDays: 7, reservedSlugs: ["admin", "api"], supportEmail: "help@eazysuvai.com", liveIdleMinutes: 15, liveMaxMinutes: 90 });
    expect(config.announcement).toMatchObject({ text: "Maintenance on Sunday 2 am", level: "warning", active: true });
    expect(await auditActions()).toEqual(expect.arrayContaining(["platform.updateConfig", "platform.announcement"]));
    const { entries } = (await adminListCatalog(db, ADMIN, { kind: "themes" })) as { entries: Array<{ id: string }> };
    expect(entries.map((e) => e.id)).toContain("saffron");
  });
});

describe("admins and the dashboard (FR-084, FR-085)", () => {
  it("grants and revokes the admin role, never one's own", async () => {
    const auth = fakeAuth();
    await setAdminRole(db, ADMIN, { email: "staff@example.com", grant: true, reason: "New support hire" }, { auth: auth as unknown as AdminAuth });
    expect(auth.users["staff@example.com"].customClaims).toEqual({ role: "platformAdmin" });
    expect(auth.revoked).toContain("staff1");
    expect((await adminListAdmins(db, ADMIN)).admins.map((a) => a.uid)).toEqual(["staff1"]);
    expect(await codeOf(setAdminRole(db, ADMIN, { email: "admin@example.com", grant: false, reason: "oops" }, { auth: auth as unknown as AdminAuth }))).toBe("invalid-input");
    expect(await codeOf(setAdminRole(db, ADMIN, { email: "owner@example.com", grant: true, reason: "nope" }, { auth: auth as unknown as AdminAuth }))).toBe("invalid-input");
    expect(await codeOf(setAdminRole(db, ADMIN, { email: "ghost@example.com", grant: true, reason: "nope" }, { auth: auth as unknown as AdminAuth }))).toBe("not-found");
    await setAdminRole(db, ADMIN, { email: "staff@example.com", grant: false, reason: "Left the company" }, { auth: auth as unknown as AdminAuth });
    expect(auth.users["staff@example.com"].customClaims).toEqual({});
    expect(await auditActions()).toEqual(expect.arrayContaining(["admin.grant", "admin.revoke"]));
  });

  it("keeps stats/platform with the trigger and shows the FR-085 counts", async () => {
    await restaurant("r1", {});
    await restaurant("r2", { status: "suspended", subscription: { status: "active", planId: "pro" }, counts: { items: 20 } });
    await db.collection("upgradeRequests").add({ restaurantId: "r1", status: "pending", createdAt: Timestamp.now() });
    // The onRestaurantStats trigger (Functions emulator) counts both.
    const end = Date.now() + 20000;
    let stats = await readPlatformStats(db);
    while ((stats.restaurants as number) < 2 && Date.now() < end) {
      await new Promise((r) => setTimeout(r, 200));
      stats = await readPlatformStats(db);
    }
    // The trigger counted them (late triggers from earlier tests may add to
    // this cumulative counter, so only the lower bound is exact here).
    expect(stats.restaurants).toBeGreaterThanOrEqual(2);
    // A drifted counter is fixed by the recompute, which is exact.
    await db.doc("stats/platform").update({ restaurants: 99 });
    expect(await recomputeStats(db)).toMatchObject({ restaurants: 2, totalItems: 25, subscriptionsByStatus: { free: 1, active: 1, grace: 0 } });
    const dash = await adminDashboard(db, ADMIN);
    expect(dash.stats).toMatchObject({ restaurants: 2, restaurantsByStatus: { active: 1, suspended: 1, deactivated: 0, deleted: 0 } });
    expect(dash.pendingUpgrades).toBe(1);
    expect((dash.recentSignups as unknown[]).length).toBe(2);
  });
});
