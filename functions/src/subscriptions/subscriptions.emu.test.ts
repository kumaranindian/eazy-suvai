import { Timestamp } from "firebase-admin/firestore";

import { appErrorCodeOf } from "../lib/errors";
import { createItem } from "../menu/menu-callables";
import { DIETARY_LABELS, ITEM_TAGS } from "../menu/seed-data";
import { loadMenu } from "../public/loader";
import { publishMenu } from "../publishing/publish";
import { admin as emu, resetEmulators } from "../testing/emulator";
import { SEED_THEMES } from "../theme";
import {
  adminListUpgradeRequests,
  changeSubscription,
  closeUpgradeRequest,
  recordPaymentAndActivate,
  requestUpgrade,
  setHiddenOverLimit,
} from "./callables";
import { runSubscriptionDaily } from "./daily";
import { SEED_PLANS } from "./seed-plans";

const { db } = emu();
let run = 0;
let RID = "";
const owner = () => ({ uid: "u1", token: { email_verified: true, role: "owner", restaurantId: RID } });
const adminAuth = { uid: "admin1", token: { email_verified: true, role: "platformAdmin", firebase: { sign_in_second_factor: "totp" } } };
const deps = { resolveImageUrls: async () => ({}) };
const root = () => db.doc(`restaurants/${RID}`);
const data = async (path: string) => (await db.doc(path).get()).data();

async function codeOf(p: Promise<unknown>): Promise<string | undefined> {
  try {
    await p;
  } catch (e) {
    return appErrorCodeOf(e) ?? String(e);
  }
  throw new Error("expected rejection");
}

/** A restaurant with `cats` categories and `items` items spread over them, written directly. */
async function seed(opts: { planId?: string; cats?: number; items?: number; themeId?: string; subscription?: Record<string, unknown> } = {}) {
  RID = `rest_sub_${++run}`;
  const planId = opts.planId ?? "free";
  const writes: Promise<unknown>[] = [
    root().set({
      name: "Spice Garden",
      slug: `spice-${run}`,
      ownerUid: "u1",
      ownerEmail: "owner@example.com",
      status: "active",
      planId,
      country: "IN",
      currency: "INR",
      timezone: "Asia/Kolkata",
      businessType: "restaurant",
      contact: {},
      themeId: opts.themeId ?? "saffron",
      themeSettings: { mode: "dark" },
      counts: { categories: opts.cats ?? 0, items: opts.items ?? 0 },
      publishedVersion: null,
      pricesNeedReview: false,
      draftUpdatedAt: Timestamp.fromMillis(0),
      subscription: opts.subscription ?? { status: "free", planId: "free" },
    }),
    db.doc(`slugs/spice-${run}`).set({ restaurantId: RID, current: true }),
  ];
  for (let c = 0; c < (opts.cats ?? 0); c++) {
    writes.push(root().collection("categories").doc(`c${String(c).padStart(2, "0")}`).set({ name: `Cat ${c}`, sequence: (c + 1) * 1000, active: true, deletedAt: null, updatedAt: Timestamp.fromMillis(1) }));
  }
  for (let i = 0; i < (opts.items ?? 0); i++) {
    const c = i % Math.max(1, opts.cats ?? 1);
    writes.push(
      root().collection("items").doc(`i${String(i).padStart(3, "0")}`).set({
        categoryId: `c${String(c).padStart(2, "0")}`, name: `Dish ${i}`, priceMinor: 10000 + i, dietaryLabelId: "vegetarian", tagIds: [],
        available: true, featured: false, sequence: (i + 1) * 1000, hiddenOverLimit: false, deletedAt: null, updatedAt: Timestamp.fromMillis(1),
      }),
    );
  }
  await Promise.all(writes);
}

beforeAll(async () => {
  await resetEmulators();
});

beforeEach(async () => {
  const w: Promise<unknown>[] = [];
  for (const { id, ...d } of DIETARY_LABELS) w.push(db.doc(`dietaryLabels/${id}`).set(d));
  for (const { id, ...d } of ITEM_TAGS) w.push(db.doc(`itemTags/${id}`).set(d));
  for (const t of SEED_THEMES) w.push(db.doc(`themes/${t.id}`).set({ name: t.name, premium: t.premium, tokens: t.tokens }));
  for (const { id, ...p } of SEED_PLANS) w.push(db.doc(`plans/${id}`).set(p));
  w.push(db.doc("config/platform").set({ graceDays: 14 }));
  await Promise.all(w);
});

describe("plan limits (AC-018)", () => {
  it("the 51st item on Free fails on the server", async () => {
    await seed({ cats: 1, items: 50 });
    expect(await codeOf(createItem(db, owner(), { restaurantId: RID, categoryId: "c00", name: "One more", priceMinor: 100, dietaryLabelId: "vegetarian" }))).toBe("limit-reached");
  });
});

describe("upgrade request and offline payment (FR-106, AC-030, AC-026)", () => {
  it("one open request; the admin records the payment; Pro activates and hidden content returns", async () => {
    await seed({ cats: 2, items: 4 });
    await root().collection("items").doc("i003").update({ hiddenOverLimit: true });
    const { requestId } = await requestUpgrade(db, owner(), { restaurantId: RID, planId: "pro", billing: "annual" });
    expect(await codeOf(requestUpgrade(db, owner(), { restaurantId: RID, planId: "pro", billing: "monthly" }))).toBe("request-pending");
    const listed = await adminListUpgradeRequests(db, adminAuth, {});
    expect(listed.requests.map((r) => r.id)).toContain(requestId);
    expect(await codeOf(adminListUpgradeRequests(db, owner(), {}))).toBe("permission-denied");
    expect(await codeOf(recordPaymentAndActivate(db, owner(), {}))).toBe("permission-denied");

    const res = await recordPaymentAndActivate(db, adminAuth, {
      restaurantId: RID, planId: "pro", billing: "annual", amountMinor: 999900, currency: "INR", method: "bank-transfer",
      reference: "NEFT-123", paidAt: "2026-11-15", startAt: "2026-11-15", endAt: "2027-11-15",
    });
    expect(res.restored).toBe(1);
    const r = (await root().get()).data()!;
    expect(r.planId).toBe("pro");
    expect(r.subscription.status).toBe("active");
    expect((r.subscription.expiresAt as Timestamp).toDate().toISOString()).toBe("2027-11-15T00:00:00.000Z");
    expect(r.planFeatures).toMatchObject({ maxItems: 500, premiumThemes: true, qrLogo: true, analyticsDays: 365 });
    expect(r.pendingUpgradeRequestId).toBeNull();
    expect(r.planNotice).toMatchObject({ kind: "restored", restored: 1 });
    expect((await data(`restaurants/${RID}/items/i003`))!.hiddenOverLimit).toBe(false);
    expect((await data(`upgradeRequests/${requestId}`))!.status).toBe("activated");
    const payments = await root().collection("payments").get();
    expect(payments.docs[0].data()).toMatchObject({ amountMinor: 999900, currency: "INR", method: "bank-transfer", provider: "offline", reference: "NEFT-123", recordedBy: "admin1" });
    const audit = await db.collection("auditLogs").where("restaurantId", "==", RID).where("action", "==", "subscription.activate").get();
    expect(audit.size).toBe(1);
    expect(audit.docs[0].data()).toMatchObject({ actorUid: "admin1", actorRole: "platformAdmin" });
    const mail = await db.collection("mail").where("restaurantId", "==", RID).where("kind", "==", "activated").get();
    expect(mail.docs[0].data().to).toBe("owner@example.com");
    expect(await codeOf(requestUpgrade(db, owner(), { restaurantId: RID, planId: "pro", billing: "annual" }))).toBe("already-on-plan");
  });

  it("validates payments and lets the admin decline a request", async () => {
    await seed();
    const { requestId } = await requestUpgrade(db, owner(), { restaurantId: RID, planId: "pro", billing: "monthly" });
    const bad = { restaurantId: RID, planId: "pro", billing: "monthly", amountMinor: 1, currency: "INR", method: "upi", reference: "x", paidAt: "2026-11-15", startAt: "2026-11-15", endAt: "2026-11-01" };
    expect(await codeOf(recordPaymentAndActivate(db, adminAuth, bad))).toBe("invalid-input");
    expect(await codeOf(recordPaymentAndActivate(db, adminAuth, { ...bad, endAt: "2026-12-15", amountMinor: 1.5 }))).toBe("invalid-input");
    expect(await codeOf(recordPaymentAndActivate(db, adminAuth, { ...bad, endAt: "2026-12-15", planId: "free" }))).toBe("invalid-input");
    await closeUpgradeRequest(db, adminAuth, { requestId, reason: "Owner asked to wait" });
    expect((await data(`upgradeRequests/${requestId}`))!.status).toBe("closed");
    expect((await root().get()).get("pendingUpgradeRequestId")).toBeNull();
    expect(await codeOf(closeUpgradeRequest(db, adminAuth, { requestId, reason: "again" }))).toBe("invalid-input");
  });
});

describe("expiry, grace and automatic downgrade (FR-100, FR-101, AC-025)", () => {
  it("Pro keeps working in grace; after grace it is Free with the last content hidden, not deleted, and the menu still loads", async () => {
    await seed({
      planId: "pro",
      cats: 12,
      items: 55,
      themeId: "midnight",
      subscription: { status: "active", planId: "pro", billing: "annual", startAt: Timestamp.fromDate(new Date("2025-12-01T00:00:00Z")), expiresAt: Timestamp.fromDate(new Date("2026-12-01T00:00:00Z")), graceEndsAt: null, remindersSent: [] },
    });
    await root().update({ planFeatures: { maxItems: 500, maxCategories: 10000, premiumThemes: true, analyticsDays: 365, qrLogo: true, removeBranding: true } });
    await publishMenu(db, owner(), { restaurantId: RID }, deps);
    const v1 = (await root().get()).get("publishedVersion");

    // 14 days before: one reminder.
    let rep = await runSubscriptionDaily(db, new Date("2026-11-17T19:00:00Z"));
    expect(rep.reminders).toBeGreaterThanOrEqual(1);
    expect((await root().get()).get("subscription.remindersSent")).toEqual([14]);
    // The same day again: nothing new (idempotent).
    await runSubscriptionDaily(db, new Date("2026-11-17T20:00:00Z"));
    expect((await root().get()).get("subscription.remindersSent")).toEqual([14]);

    // Expiry: grace for 14 days; still Pro, menu live, nothing hidden.
    await runSubscriptionDaily(db, new Date("2026-12-01T00:30:00Z"));
    let r = (await root().get()).data()!;
    expect(r.subscription.status).toBe("grace");
    expect((r.subscription.graceEndsAt as Timestamp).toDate().toISOString()).toBe("2026-12-15T00:00:00.000Z");
    expect(r.planId).toBe("pro");
    expect((await loadMenu(db, `spice-${run}`)).kind).toBe("live");
    expect((await root().collection("items").where("hiddenOverLimit", "==", true).get()).size).toBe(0);

    // Grace over: Free, last 2 categories and their items hidden first, then items past 50.
    rep = await runSubscriptionDaily(db, new Date("2026-12-15T00:30:00Z"));
    expect(rep.downgraded).toBeGreaterThanOrEqual(1);
    r = (await root().get()).data()!;
    expect(r.planId).toBe("free");
    expect(r.subscription.status).toBe("free");
    expect(r.planFeatures).toMatchObject({ maxItems: 50, maxCategories: 10, premiumThemes: false });
    expect(r.themeId).toBe("saffron");
    expect(r.themeSettings).toEqual({ mode: "dark" });
    expect(r.planNotice).toMatchObject({ kind: "limitsApplied", hiddenCategories: 2, themeReverted: true });
    const hiddenCats = (await root().collection("categories").where("hiddenOverLimit", "==", true).get()).docs.map((d) => d.id).sort();
    expect(hiddenCats).toEqual(["c10", "c11"]);
    const allItems = await root().collection("items").get();
    expect(allItems.size).toBe(55); // nothing deleted
    const visible = allItems.docs.filter((d) => d.get("hiddenOverLimit") !== true);
    expect(visible.length).toBeLessThanOrEqual(50);
    expect(visible.every((d) => !["c10", "c11"].includes(d.get("categoryId")))).toBe(true);

    // A new version without hidden content, published by the system; the public menu loads.
    expect(r.publishedVersion).toBe(v1 + 1);
    const menu = await loadMenu(db, `spice-${run}`);
    expect(menu.kind).toBe("live");
    if (menu.kind === "live") {
      expect(menu.snapshot.categories.map((c) => c.id)).not.toContain("c10");
      expect(menu.snapshot.items.length).toBeLessThanOrEqual(50);
      expect(menu.snapshot.theme.themeId).toBe("saffron");
    }
    const version = await data(`restaurants/${RID}/versions/${v1 + 1}`);
    expect(version!.publishedBy).toBe("system");
    const kinds = (await db.collection("mail").where("restaurantId", "==", RID).get()).docs.map((d) => d.get("kind")).sort();
    expect(kinds).toEqual(["downgraded", "grace", "limitsApplied", "reminder"]);
    const actions = (await db.collection("auditLogs").where("restaurantId", "==", RID).get()).docs.map((d) => d.get("action"));
    expect(actions).toEqual(expect.arrayContaining(["subscription.grace", "subscription.expire", "subscription.applyLimits", "menu.publishPlanLimits"]));

    // While over: no new items (hidden ones still count, FR-101).
    expect(await codeOf(createItem(db, owner(), { restaurantId: RID, categoryId: "c00", name: "x", priceMinor: 1, dietaryLabelId: "vegetarian" }))).toBe("limit-reached");

    // Running again changes nothing.
    rep = await runSubscriptionDaily(db, new Date("2026-12-16T00:30:00Z"));
    expect(rep.downgraded).toBe(0);
    expect((await root().get()).get("publishedVersion")).toBe(v1 + 1);
  });
});

describe("over-limit manager and admin changes (FR-101, FR-081)", () => {
  it("swaps hidden items within the limit and refuses going over", async () => {
    await seed({ cats: 1, items: 52 });
    await root().collection("items").doc("i050").update({ hiddenOverLimit: true });
    await root().collection("items").doc("i051").update({ hiddenOverLimit: true });
    const res = await setHiddenOverLimit(db, owner(), { restaurantId: RID, hideItemIds: ["i000"], showItemIds: ["i051"] });
    expect(res.visibleItems).toBe(50);
    expect((await data(`restaurants/${RID}/items/i000`))!.hiddenOverLimit).toBe(true);
    expect((await data(`restaurants/${RID}/items/i051`))!.hiddenOverLimit).toBe(false);
    expect(await codeOf(setHiddenOverLimit(db, owner(), { restaurantId: RID, showItemIds: ["i050"] }))).toBe("limit-reached");
    expect(await codeOf(setHiddenOverLimit(db, owner(), { restaurantId: RID, showItemIds: ["nope"] }))).toBe("not-found");
  });

  it("lets the owner downgrade choosing what to hide, then publishes", async () => {
    await seed({ planId: "pro", cats: 1, items: 52, subscription: { status: "active", planId: "pro", expiresAt: Timestamp.fromDate(new Date("2027-01-01T00:00:00Z")) } });
    await publishMenu(db, owner(), { restaurantId: RID }, deps);
    expect(await codeOf(setHiddenOverLimit(db, owner(), { restaurantId: RID, downgrade: true, hideItemIds: ["i000"] }))).toBe("limit-reached");
    const res = await setHiddenOverLimit(db, owner(), { restaurantId: RID, downgrade: true, hideItemIds: ["i000", "i001"] });
    expect(res.published).toBe(2);
    expect((await root().get()).get("planId")).toBe("free");
    const menu = await loadMenu(db, `spice-${run}`);
    expect(menu.kind === "live" && menu.snapshot.items.map((i) => i.id)).not.toContain("i000");
    expect(menu.kind === "live" && menu.snapshot.items.map((i) => i.id)).toContain("i051");
  });

  it("extends and downgrades with an audit-logged reason", async () => {
    await seed({ planId: "pro", cats: 1, items: 3, subscription: { status: "grace", planId: "pro", expiresAt: Timestamp.fromDate(new Date("2026-11-10T00:00:00Z")), graceEndsAt: Timestamp.fromDate(new Date("2026-11-24T00:00:00Z")) } });
    const now = () => new Date("2026-11-15T00:00:00Z");
    expect(await codeOf(changeSubscription(db, adminAuth, { action: "extend", restaurantId: RID, expiresAt: "2026-12-15", reason: "x" }, { now }))).toBe("invalid-input");
    await changeSubscription(db, adminAuth, { action: "extend", restaurantId: RID, expiresAt: "2026-12-15", reason: "Paid by cheque, clearing" }, { now });
    let s = (await root().get()).get("subscription");
    expect(s.status).toBe("active");
    expect(s.graceEndsAt).toBeNull();
    await changeSubscription(db, adminAuth, { action: "downgrade", restaurantId: RID, reason: "Refund requested" }, { now });
    s = (await root().get()).get("subscription");
    expect([(await root().get()).get("planId"), s.status]).toEqual(["free", "free"]);
    const audit = (await db.collection("auditLogs").where("restaurantId", "==", RID).get()).docs.map((d) => [d.get("action"), d.get("reason")]);
    expect(audit).toEqual(expect.arrayContaining([["subscription.extend", "Paid by cheque, clearing"], ["subscription.downgrade", "Refund requested"]]));
    expect(await codeOf(changeSubscription(db, owner(), { action: "downgrade", restaurantId: RID, reason: "nope" }))).toBe("permission-denied");
  });
});
