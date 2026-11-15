import { Timestamp } from "firebase-admin/firestore";

import { appErrorCodeOf } from "../lib/errors";
import { loadMenu, resolveQr } from "../public/loader";
import { admin as emu, resetEmulators } from "../testing/emulator";
import { adminListAuditLogs } from "./audit-viewer";
import { requestAccountDeletion } from "./deletion";
import { exportMenu } from "./export";
import { purgeArchivedPayments, purgeDeactivated, purgeOrphanImages, purgeSoftDeleted, releaseSlugs, runPurgeDaily } from "./purge";

const { db } = emu();
const OWNER = { uid: "u1", token: { email_verified: true, role: "owner", restaurantId: "r1" } };
const ADMIN = { uid: "admin1", token: { email_verified: true, role: "platformAdmin", firebase: { sign_in_second_factor: "totp" } } };
const NOW = new Date("2026-11-15T00:00:00Z");
/** Slugs that registration and changeSlug would refuse (any slugs document blocks, M01/M03). */
const slugCandidatesBlocked = async (_db: unknown, slugs: string[]) => {
  const out: string[] = [];
  for (const s of slugs) if ((await db.doc(`slugs/${s}`).get()).exists) out.push(s);
  return out;
};
const days = (n: number) => Timestamp.fromMillis(NOW.getTime() - n * 86_400_000);

async function codeOf(p: Promise<unknown>): Promise<string | undefined> {
  try {
    await p;
  } catch (e) {
    return appErrorCodeOf(e) ?? String(e);
  }
  throw new Error("expected rejection");
}

async function seedTenant(rid: string, extra: Record<string, unknown> = {}) {
  const root = db.doc(`restaurants/${rid}`);
  await root.set({
    name: "Spice Garden",
    slug: `spice-${rid}`,
    qrCode: `QR${rid.toUpperCase()}AAAA`.slice(0, 8),
    ownerUid: rid === "r1" ? "u1" : `owner_${rid}`,
    ownerEmail: `${rid}@example.com`,
    ownerMobile: "+919800000000",
    status: "active",
    currency: "INR",
    country: "IN",
    timezone: "Asia/Kolkata",
    planId: "free",
    counts: { categories: 1, items: 2 },
    logo: { status: "ready", path: `restaurants/${rid}/images/logo1/original.png`, renditions: { w320: `restaurants/${rid}/images/logo1/w320.webp` } },
    ...extra,
  });
  await Promise.all([
    root.collection("categories").doc("c1").set({ name: "Starters", sequence: 1000, active: true, deletedAt: null }),
    root.collection("items").doc("i1").set({ categoryId: "c1", name: "Idli", priceMinor: 6000, dietaryLabelId: "vegetarian", tagIds: [], available: true, featured: false, sequence: 1000, deletedAt: null }),
    root.collection("items").doc("i2").set({ categoryId: "c1", name: "Vada", priceMinor: 7000, dietaryLabelId: "vegetarian", tagIds: [], available: true, featured: false, sequence: 2000, deletedAt: null }),
    root.collection("analyticsDaily").doc("2026-11-01").set({ views: 3 }),
    root.collection("payments").doc("p1").set({ amountMinor: 99900, currency: "INR", method: "upi", provider: "offline", reference: "UPI-1", planId: "pro", paidAt: Timestamp.fromDate(new Date("2026-01-10T00:00:00Z")) }),
    db.doc(`slugs/spice-${rid}`).set({ restaurantId: rid, current: true }),
    db.doc(`slugs/old-${rid}`).set({ restaurantId: rid, current: false }),
    db.doc(`qrCodes/QR${rid.toUpperCase()}AAAA`.slice(0, 16)).set({ restaurantId: rid }),
    db.doc(`users/${rid === "r1" ? "u1" : `owner_${rid}`}`).set({ email: `${rid}@example.com`, role: "owner", restaurantId: rid }),
    db.collection("auditLogs").add({ actorUid: rid === "r1" ? "u1" : `owner_${rid}`, actorRole: "owner", action: "restaurant.changeSlug", restaurantId: rid, target: "x", details: { from: "a", to: "b", ownerEmail: `${rid}@example.com` }, at: Timestamp.now() }),
    db.collection("upgradeRequests").add({ restaurantId: rid, status: "pending", ownerEmail: `${rid}@example.com` }),
    db.collection("mail").add({ restaurantId: rid, to: `${rid}@example.com` }),
  ]);
}

beforeEach(async () => {
  await resetEmulators();
  await db.doc("dietaryLabels/vegetarian").set({ name: "Vegetarian", icon: "veg", color: "#0F7B0F", sort: 1 });
});

describe("exportMenu (FR-105)", () => {
  it("exports every category and item with minor units and currency, owner only, audited", async () => {
    await seedTenant("r1");
    const res = await exportMenu(db, OWNER, { restaurantId: "r1" }, { now: () => NOW });
    const json = JSON.parse(res.json);
    expect(json.items.map((i: { name: string }) => i.name)).toEqual(["Idli", "Vada"]);
    expect(json.items[0]).toMatchObject({ priceMinor: 6000, currency: "INR", dietaryLabel: "Vegetarian" });
    expect(res.csv).toContain("Starters,Idli,,6000,60.00,INR,Vegetarian");
    expect(res.fileBase).toBe("spice-r1-menu-2026-11-15");
    expect(await codeOf(exportMenu(db, { ...OWNER, token: { ...OWNER.token, restaurantId: "r2" } }, { restaurantId: "r1" }))).toBe("permission-denied");
    const audit = await db.collection("auditLogs").where("action", "==", "menu.export").get();
    expect(audit.size).toBe(1);
  });
});

describe("requestAccountDeletion (FR-105)", () => {
  it("needs the name, deactivates at once, signs out, emails and audits", async () => {
    await seedTenant("r1");
    const revoked: string[] = [];
    const deps = { auth: { revokeRefreshTokens: async (u: string) => void revoked.push(u) }, now: () => NOW };
    expect(await codeOf(requestAccountDeletion(db, OWNER, { restaurantId: "r1", confirmName: "Spice" }, deps))).toBe("invalid-input");
    const res = await requestAccountDeletion(db, OWNER, { restaurantId: "r1", confirmName: "spice garden" }, deps);
    expect(res.purgeAfter).toBe("2027-02-13T00:00:00.000Z");
    const r = (await db.doc("restaurants/r1").get()).data()!;
    expect(r.status).toBe("deactivated");
    expect((r.deactivatedAt as Timestamp).toDate()).toEqual(NOW);
    expect((await db.doc("users/u1").get()).get("accountStatus")).toBe("deactivated");
    expect(revoked).toEqual(["u1"]);
    expect((await db.collection("mail").where("kind", "==", "deletionRequested").get()).size).toBe(1);
    expect((await db.collection("auditLogs").where("action", "==", "account.requestDeletion").get()).size).toBe(1);
    // The public menu and QR code answer 410 right away (FR-099).
    expect((await loadMenu(db, "spice-r1")).kind).toBe("gone");
    // A second request is refused (already deactivated).
    expect(await codeOf(requestAccountDeletion(db, OWNER, { restaurantId: "r1", confirmName: "Spice Garden" }, deps))).toBe("account-inactive");
  });
});

describe("purge rules with fixed dates (§7.7)", () => {
  it("soft-deleted content: exactly what is older than 30 days", async () => {
    await seedTenant("r1");
    await db.doc("restaurants/r1/items/i1").update({ deletedAt: days(31) });
    await db.doc("restaurants/r1/items/i2").update({ deletedAt: days(29) });
    await db.doc("restaurants/r1/categories/c9").set({ name: "Old", deletedAt: days(45) });
    expect(await purgeSoftDeleted(db, NOW)).toBe(2);
    expect((await db.doc("restaurants/r1/items/i1").get()).exists).toBe(false);
    expect((await db.doc("restaurants/r1/items/i2").get()).exists).toBe(true);
    expect((await db.doc("restaurants/r1/categories/c9").get()).exists).toBe(false);
    expect((await db.doc("restaurants/r1/categories/c1").get()).exists).toBe(true);
    expect(await purgeSoftDeleted(db, NOW)).toBe(0); // idempotent
  });

  it("deactivated accounts: purged after 90 days, tombstone, payments archived, slugs held, audit anonymised", async () => {
    await seedTenant("r1", { status: "deactivated", deactivatedAt: days(91) });
    await seedTenant("r2", { status: "deactivated", deactivatedAt: days(89) });
    await seedTenant("r3", { status: "active" });
    const deleted: string[] = [];
    const prefixes: string[] = [];
    const deps = { auth: { deleteUser: async (u: string) => void deleted.push(u) }, deletePrefix: async (p: string) => void prefixes.push(p) };
    expect(await purgeDeactivated(db, NOW, deps)).toBe(1);

    const tomb = (await db.doc("restaurants/r1").get()).data()!;
    expect(tomb).toMatchObject({ status: "deleted", slug: "spice-r1" });
    expect(tomb.name).toBeUndefined();
    expect(tomb.ownerEmail).toBeUndefined();
    for (const sub of ["categories", "items", "analyticsDaily", "payments"]) {
      expect((await db.collection(`restaurants/r1/${sub}`).get()).size).toBe(0);
    }
    expect((await db.doc("users/u1").get()).exists).toBe(false);
    expect(deleted).toEqual(["u1"]);
    expect(prefixes).toEqual(["restaurants/r1/"]);
    const archived = (await db.doc("paymentArchive/r1_p1").get()).data()!;
    expect(archived).toMatchObject({ amountMinor: 99900, reference: "UPI-1", businessName: "Spice Garden" });
    expect((archived.retainUntil as Timestamp).toDate().toISOString()).toBe("2034-01-10T00:00:00.000Z");
    expect(archived.ownerEmail).toBeUndefined();
    const slugs = await db.collection("slugs").where("restaurantId", "==", "r1").get();
    expect(slugs.size).toBe(2);
    expect(slugs.docs.every((s) => (s.get("releaseAfter") as Timestamp).toDate().toISOString() === "2027-11-15T00:00:00.000Z")).toBe(true);
    const audit = (await db.collection("auditLogs").where("restaurantId", "==", "r1").where("action", "==", "restaurant.changeSlug").get()).docs[0].data();
    expect(audit.actorUid).toMatch(/^anon:/);
    expect(audit.details).toEqual({ from: "a", to: "b" });
    expect((await db.collection("upgradeRequests").where("restaurantId", "==", "r1").get()).size).toBe(0);
    expect((await db.collection("mail").where("restaurantId", "==", "r1").get()).size).toBe(0);
    // The deleted menu still answers 410 by slug and QR code (FR-099, AC).
    expect((await loadMenu(db, "spice-r1")).kind).toBe("gone");
    expect(await resolveQr(db, "QRR1AAAA")).toEqual({ kind: "slug", slug: "spice-r1" });
    // Not due yet / active: untouched.
    expect((await db.doc("restaurants/r2").get()).get("name")).toBe("Spice Garden");
    expect((await db.doc("restaurants/r3/items/i1").get()).exists).toBe(true);
    // Idempotent.
    expect(await purgeDeactivated(db, NOW, deps)).toBe(0);
  });

  it("slugs of deleted accounts are blocked for 12 months, then released", async () => {
    await db.doc("slugs/held").set({ restaurantId: "gone", current: true, releaseAfter: Timestamp.fromDate(new Date("2026-11-16T00:00:00Z")) });
    await db.doc("slugs/due").set({ restaurantId: "gone", current: false, releaseAfter: Timestamp.fromDate(new Date("2026-11-14T00:00:00Z")) });
    await db.doc("slugs/live").set({ restaurantId: "r9", current: true });
    expect(await slugCandidatesBlocked(db, ["held", "due", "live"])).toEqual(["held", "due", "live"]);
    expect(await releaseSlugs(db, NOW)).toBe(1);
    expect(await slugCandidatesBlocked(db, ["held", "due", "live"])).toEqual(["held", "live"]);
  });

  it("archived payments go after 8 years", async () => {
    await db.doc("paymentArchive/a").set({ retainUntil: Timestamp.fromDate(new Date("2026-11-01T00:00:00Z")) });
    await db.doc("paymentArchive/b").set({ retainUntil: Timestamp.fromDate(new Date("2030-01-01T00:00:00Z")) });
    expect(await purgeArchivedPayments(db, NOW)).toBe(1);
    expect((await db.doc("paymentArchive/b").get()).exists).toBe(true);
  });

  it("orphan image folders: only unreferenced ones older than 7 days", async () => {
    await seedTenant("r1");
    await db.doc("restaurants/r1/items/i1").update({ image: { status: "ready", path: "restaurants/r1/images/item1/original.png" } });
    await db.doc("restaurants/r1/items/i2").update({ deletedAt: days(5), image: { status: "ready", path: "restaurants/r1/images/restorable/original.png" } });
    await db.doc("restaurants/r1/versions/1").set({ n: 1, snapshot: { items: [{ image: { w320: "https://x/o/restaurants%2Fr1%2Fimages%2Fpublished%2Fw320.webp?alt=media" } }] } });
    const deleted: string[] = [];
    const folders = ["logo1", "item1", "restorable", "published", "orphan", "fresh"].map((f) => ({
      folder: `restaurants/r1/images/${f}/`,
      updatedAt: f === "fresh" ? new Date(NOW.getTime() - 86_400_000) : new Date("2026-10-01T00:00:00Z"),
    }));
    const n = await purgeOrphanImages(db, NOW, { listImageFolders: async () => folders, deletePrefix: async (p) => void deleted.push(p) });
    expect(n).toBe(1);
    expect(deleted).toEqual(["restaurants/r1/images/orphan/"]);
  });

  it("runPurgeDaily runs every rule and logs a summary", async () => {
    await seedTenant("r1", { status: "deactivated", deactivatedAt: days(100) });
    const report = await runPurgeDaily(db, NOW, { deletePrefix: async () => undefined });
    expect(report).toMatchObject({ tenants: 1 });
    expect((await db.collection("auditLogs").where("action", "==", "platform.purge").get()).size).toBe(1);
  });
});

describe("adminListAuditLogs (FR-090)", () => {
  it("filters by actor, action, restaurant and dates, newest first, admin only", async () => {
    const at = (d: string) => Timestamp.fromDate(new Date(d));
    await Promise.all([
      db.collection("auditLogs").doc("a1").set({ actorUid: "admin1", actorRole: "platformAdmin", action: "restaurant.suspend", restaurantId: "r1", target: "x", reason: "Unpaid", at: at("2026-11-10T00:00:00Z") }),
      db.collection("auditLogs").doc("a2").set({ actorUid: "u1", actorRole: "owner", action: "menu.publish", restaurantId: "r1", target: "x", at: at("2026-11-12T00:00:00Z") }),
      db.collection("auditLogs").doc("a3").set({ actorUid: "admin1", actorRole: "platformAdmin", action: "plan.update", target: "plans/pro", at: at("2026-11-14T00:00:00Z") }),
    ]);
    const ids = async (f: Record<string, unknown>) => (await adminListAuditLogs(db, ADMIN, f)).entries.map((e) => e.id);
    expect(await ids({})).toEqual(["a3", "a2", "a1"]);
    expect(await ids({ actorUid: "admin1" })).toEqual(["a3", "a1"]);
    expect(await ids({ action: "menu.publish" })).toEqual(["a2"]);
    expect(await ids({ restaurantId: "r1" })).toEqual(["a2", "a1"]);
    expect(await ids({ from: "2026-11-11", to: "2026-11-13" })).toEqual(["a2"]);
    const p1 = await adminListAuditLogs(db, ADMIN, { pageSize: 2 });
    expect(p1.nextCursor).toBe("a2");
    expect((await adminListAuditLogs(db, ADMIN, { pageSize: 2, cursor: "a2" })).entries.map((e) => e.id)).toEqual(["a1"]);
    expect(await codeOf(adminListAuditLogs(db, OWNER, {}))).toBe("permission-denied");
  });
});
