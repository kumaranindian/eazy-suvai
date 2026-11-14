import { appErrorCodeOf } from "../lib/errors";
import { admin, resetEmulators } from "../testing/emulator";
import { changeSlug } from "./slug-change";

const { db } = admin();

const RID = "rest_1";
const OTHER = "rest_2";

const ownerCaller = (uid = "u1", rid = RID) => ({
  uid,
  token: { email_verified: true, role: "owner", restaurantId: rid },
});

async function seed(): Promise<void> {
  const restaurant = (ownerUid: string, slug: string, extra: Record<string, unknown> = {}) => ({
    name: "Spice Garden",
    nameLower: "spice garden",
    ownerUid,
    slug,
    qrCode: "ABCDEFGH",
    status: "active",
    currency: "INR",
    publishedVersion: null,
    pricesNeedReview: false,
    ...extra,
  });
  await Promise.all([
    db.doc(`restaurants/${RID}`).set(restaurant("u1", "spice-garden")),
    db.doc(`restaurants/${OTHER}`).set(restaurant("u2", "other-place")),
    db.doc("slugs/spice-garden").set({ restaurantId: RID, current: true }),
    db.doc("slugs/other-place").set({ restaurantId: OTHER, current: true }),
    db.doc("slugs/other-old").set({ restaurantId: OTHER, current: false }),
  ]);
}

async function codeOf(p: Promise<unknown>): Promise<string | undefined> {
  try {
    await p;
  } catch (e) {
    return appErrorCodeOf(e) ?? String(e);
  }
  throw new Error("expected rejection");
}

beforeEach(async () => {
  await resetEmulators();
  await seed();
});

describe("changeSlug on the emulator (FR-092, FR-093)", () => {
  it("changes the slug, keeps the old one for redirects and audits it", async () => {
    const r = await changeSlug(db, ownerCaller(), { restaurantId: RID, slug: "Spice-Garden-Chennai" });
    expect(r).toEqual({ slug: "spice-garden-chennai", previousSlug: "spice-garden", changed: true, available: true });

    expect((await db.doc(`restaurants/${RID}`).get()).get("slug")).toBe("spice-garden-chennai");
    const old = (await db.doc("slugs/spice-garden").get()).data()!;
    expect(old).toMatchObject({ restaurantId: RID, current: false });
    expect(old.replacedAt).toBeDefined();
    expect((await db.doc("slugs/spice-garden-chennai").get()).data()).toMatchObject({
      restaurantId: RID,
      current: true,
    });

    const audit = await db.collection("auditLogs").where("action", "==", "restaurant.changeSlug").get();
    expect(audit.size).toBe(1);
    expect(audit.docs[0].data()).toMatchObject({
      actorUid: "u1",
      actorRole: "owner",
      restaurantId: RID,
      details: { from: "spice-garden", to: "spice-garden-chennai", reclaimed: false },
    });
  });

  it("refuses a reserved slug", async () => {
    expect(await codeOf(changeSlug(db, ownerCaller(), { restaurantId: RID, slug: "admin" }))).toBe("slug-reserved");
  });

  it("uses the reserved list from config/platform", async () => {
    await db.doc("config/platform").set({ reservedSlugs: ["menu-card"] });
    expect(await codeOf(changeSlug(db, ownerCaller(), { restaurantId: RID, slug: "menu-card" }))).toBe(
      "slug-reserved",
    );
  });

  it("refuses a slug taken by another restaurant, current or old", async () => {
    for (const slug of ["other-place", "other-old"]) {
      expect(await codeOf(changeSlug(db, ownerCaller(), { restaurantId: RID, slug }))).toBe("slug-taken");
    }
    expect((await db.doc(`restaurants/${RID}`).get()).get("slug")).toBe("spice-garden");
  });

  it.each(["ab", "-abc", "abc-", "a--b", "spice garden", "x".repeat(61), "naïve"])(
    "refuses the badly formed %s",
    async (slug) => {
      expect(await codeOf(changeSlug(db, ownerCaller(), { restaurantId: RID, slug }))).toBe("slug-invalid");
    },
  );

  it("refuses malformed input", async () => {
    expect(await codeOf(changeSlug(db, ownerCaller(), { restaurantId: RID }))).toBe("invalid-input");
    expect(await codeOf(changeSlug(db, ownerCaller(), { restaurantId: RID, slug: "abc", x: 1 }))).toBe(
      "invalid-input",
    );
  });

  it("dry run checks availability without changing anything", async () => {
    const r = await changeSlug(db, ownerCaller(), { restaurantId: RID, slug: "new-name", dryRun: true });
    expect(r).toMatchObject({ available: true, changed: false });
    expect((await db.doc("slugs/new-name").get()).exists).toBe(false);
    expect((await db.doc(`restaurants/${RID}`).get()).get("slug")).toBe("spice-garden");
    expect(
      await codeOf(changeSlug(db, ownerCaller(), { restaurantId: RID, slug: "other-place", dryRun: true })),
    ).toBe("slug-taken");
  });

  it("the current slug is a no-op", async () => {
    const r = await changeSlug(db, ownerCaller(), { restaurantId: RID, slug: "spice-garden" });
    expect(r).toMatchObject({ changed: false, slug: "spice-garden" });
    expect((await db.collection("auditLogs").get()).size).toBe(0);
  });

  it("an owner can go back to one of their own old slugs", async () => {
    await changeSlug(db, ownerCaller(), { restaurantId: RID, slug: "spice-two" });
    const r = await changeSlug(db, ownerCaller(), { restaurantId: RID, slug: "spice-garden" });
    expect(r.changed).toBe(true);
    expect((await db.doc("slugs/spice-garden").get()).data()).toMatchObject({ current: true, restaurantId: RID });
    expect((await db.doc("slugs/spice-two").get()).data()).toMatchObject({ current: false, restaurantId: RID });
    const current = await db.collection("slugs").where("restaurantId", "==", RID).where("current", "==", true).get();
    expect(current.docs.map((d) => d.id)).toEqual(["spice-garden"]);
  });

  it("refuses another tenant, unverified callers and inactive restaurants (AC-017)", async () => {
    expect(await codeOf(changeSlug(db, ownerCaller("u2", OTHER), { restaurantId: RID, slug: "stolen" }))).toBe(
      "permission-denied",
    );
    expect(await codeOf(changeSlug(db, ownerCaller("u1", OTHER), { restaurantId: OTHER, slug: "stolen" }))).toBe(
      "permission-denied",
    );
    const unverified = { uid: "u1", token: { email_verified: false, role: "owner", restaurantId: RID } };
    expect(await codeOf(changeSlug(db, unverified, { restaurantId: RID, slug: "new-one" }))).toBe(
      "email-not-verified",
    );
    expect(await codeOf(changeSlug(db, null, { restaurantId: RID, slug: "new-one" }))).toBe("unauthenticated");
    await db.doc(`restaurants/${RID}`).update({ status: "suspended" });
    expect(await codeOf(changeSlug(db, ownerCaller(), { restaurantId: RID, slug: "new-one" }))).toBe(
      "account-inactive",
    );
  });

  it("two restaurants racing for one slug: only one wins", async () => {
    const results = await Promise.allSettled([
      changeSlug(db, ownerCaller(), { restaurantId: RID, slug: "hot-name" }),
      changeSlug(db, ownerCaller("u2", OTHER), { restaurantId: OTHER, slug: "hot-name" }),
    ]);
    expect(results.filter((r) => r.status === "fulfilled")).toHaveLength(1);
    const owner = (await db.doc("slugs/hot-name").get()).get("restaurantId");
    expect([RID, OTHER]).toContain(owner);
  });
});

async function waitFor<T>(read: () => Promise<T>, done: (v: T) => boolean, timeoutMs = 20000): Promise<T> {
  const end = Date.now() + timeoutMs;
  for (;;) {
    const v = await read();
    if (done(v) || Date.now() > end) return v;
    await new Promise((r) => setTimeout(r, 250));
  }
}

describe("onRestaurantUpdated through the Functions emulator", () => {
  it("sets pricesNeedReview after a currency change on a published menu, and syncs nameLower", async () => {
    await db.doc(`restaurants/${RID}`).update({ publishedVersion: 2 });
    await db.doc(`restaurants/${RID}`).update({ currency: "AED", name: "Spice Garden Dubai" });
    const data = await waitFor(
      async () => (await db.doc(`restaurants/${RID}`).get()).data()!,
      (d) => d.pricesNeedReview === true && d.nameLower === "spice garden dubai",
    );
    expect(data.pricesNeedReview).toBe(true);
    expect(data.nameLower).toBe("spice garden dubai");
  });

  it("leaves pricesNeedReview alone before the first publish", async () => {
    await db.doc(`restaurants/${RID}`).update({ currency: "KWD", name: "Renamed" });
    const data = await waitFor(
      async () => (await db.doc(`restaurants/${RID}`).get()).data()!,
      (d) => d.nameLower === "renamed",
    );
    expect(data.nameLower).toBe("renamed");
    expect(data.pricesNeedReview).toBe(false);
  });
});
