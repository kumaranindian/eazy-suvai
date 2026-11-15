import { Timestamp } from "firebase-admin/firestore";

import { appErrorCodeOf } from "../lib/errors";
import { createCategory, createItem } from "../menu/menu-callables";
import { DIETARY_LABELS, ITEM_TAGS } from "../menu/seed-data";
import { admin, resetEmulators } from "../testing/emulator";
import { SEED_THEMES } from "../theme";
import {
  discardDraft,
  previewMenu,
  publishMenu,
  rollbackMenu,
  type PublishCheck,
  type PublishResult,
} from "./publish";
import type { MenuSnapshot } from "./snapshot";

const { db } = admin();

// A new restaurant per test: the reset deletes the previous test's items,
// and their delete triggers can land after the next seed.
let RID = "";
let root = db.doc("restaurants/none");
let run = 0;

const owner = (verified = true, rid = RID) => ({
  uid: "u1",
  token: { email_verified: verified, role: "owner", restaurantId: rid },
});

const deps = { resolveImageUrls: async (paths: string[]) => Object.fromEntries(paths.map((p) => [p, `https://img.test/${p}`])) };

async function seed(extra: Record<string, unknown> = {}): Promise<void> {
  const writes: Promise<unknown>[] = [
    root.set({
      name: "Spice Garden",
      ownerUid: "u1",
      status: "active",
      planId: "free",
      country: "IN",
      currency: "INR",
      timezone: "Asia/Kolkata",
      businessType: "restaurant",
      contact: { city: "Chennai", phone: "+914423456789" },
      visibility: { phone: false, email: true, address: true, hours: true, social: true },
      themeId: "saffron",
      themeSettings: {},
      counts: { categories: 0, items: 0 },
      publishedVersion: null,
      pricesNeedReview: false,
      draftUpdatedAt: Timestamp.fromMillis(0),
      ...extra,
    }),
    db.doc("restaurants/susp").set({ name: "S", ownerUid: "u1", status: "suspended" }),
  ];
  for (const { id, ...data } of DIETARY_LABELS) writes.push(db.doc(`dietaryLabels/${id}`).set(data));
  for (const { id, ...data } of ITEM_TAGS) writes.push(db.doc(`itemTags/${id}`).set(data));
  for (const t of SEED_THEMES) writes.push(db.doc(`themes/${t.id}`).set({ name: t.name, tokens: t.tokens }));
  await Promise.all(writes);
}

async function codeOf(p: Promise<unknown>): Promise<{ code?: string; details?: Record<string, unknown> }> {
  try {
    await p;
  } catch (e) {
    return { code: appErrorCodeOf(e) ?? String(e), details: (e as { details?: Record<string, unknown> }).details };
  }
  throw new Error("expected rejection");
}

const newCategory = async (name: string, extra: Record<string, unknown> = {}) =>
  (await createCategory(db, owner(), { restaurantId: RID, name, ...extra })).id;

const newItem = async (categoryId: string, name: string, extra: Record<string, unknown> = {}) =>
  (await createItem(db, owner(), { restaurantId: RID, categoryId, name, priceMinor: 12900, dietaryLabelId: "vegetarian", ...extra })).id;

const dryRun = (extra: Record<string, unknown> = {}) =>
  publishMenu(db, owner(), { restaurantId: RID, dryRun: true, ...extra }, deps) as Promise<PublishCheck>;

const publish = (extra: Record<string, unknown> = {}, verified = true) =>
  publishMenu(db, owner(verified), { restaurantId: RID, ...extra }, deps) as Promise<PublishResult>;

async function data(path: string) {
  return (await db.doc(path).get()).data();
}

async function waitFor<T>(read: () => Promise<T>, done: (v: T) => boolean, timeoutMs = 20000): Promise<T> {
  const end = Date.now() + timeoutMs;
  for (;;) {
    const v = await read();
    if (done(v)) return v;
    if (Date.now() > end) throw new Error(`timed out; last value ${JSON.stringify(v)}`);
    await new Promise((r) => setTimeout(r, 200));
  }
}

const millis = (v: unknown) => (v instanceof Timestamp ? v.toMillis() : null);

/** Starters (Idli, Vada) and Mains (Thali). */
async function sampleMenu() {
  const starters = await newCategory("Starters");
  const mains = await newCategory("Mains");
  const idli = await newItem(starters, "Idli");
  const vada = await newItem(starters, "Vada", { tagIds: ["spicy"] });
  const thali = await newItem(mains, "Thali", { priceMinor: 25000 });
  return { starters, mains, idli, vada, thali };
}

beforeEach(async () => {
  await resetEmulators();
  RID = `rest_pub_${++run}`;
  root = db.doc(`restaurants/${RID}`);
  await seed();
});

describe("publishMenu dry run", () => {
  it("lists every problem with stable codes (AC-021)", async () => {
    const check = await publishMenu(db, owner(false), { restaurantId: RID, dryRun: true }, deps) as PublishCheck;
    expect(check.ok).toBe(false);
    expect(check.problems.map((p) => p.code)).toEqual(["email-not-verified", "menu-empty"]);
    expect(check.currentVersion).toBeNull();
    expect(check.summary.firstPublish).toBe(true);
  });

  it("returns the change summary without writing", async () => {
    await sampleMenu();
    const check = await dryRun();
    expect(check.ok).toBe(true);
    expect(check.problems).toEqual([]);
    expect(check.summary.categories.added.map((c) => c.name)).toEqual(["Starters", "Mains"]);
    expect(check.summary.items.added.map((c) => c.name)).toEqual(["Idli", "Vada", "Thali"]);
    expect((await root.get()).get("publishedVersion")).toBeNull();
    expect((await root.collection("versions").get()).size).toBe(0);
  });

  it("refuses other tenants and suspended accounts", async () => {
    expect((await codeOf(publishMenu(db, owner(true, "other"), { restaurantId: RID, dryRun: true }, deps))).code).toBe("permission-denied");
    expect((await codeOf(publishMenu(db, owner(true, "susp"), { restaurantId: "susp", dryRun: true }, deps))).code).toBe("account-inactive");
    expect((await codeOf(publishMenu(db, null, { restaurantId: RID }, deps))).code).toBe("unauthenticated");
  });
});

describe("publishMenu", () => {
  it("writes version 1, the pointer, the overlay, the source and an audit entry", async () => {
    const m = await sampleMenu();
    await root.collection("items").doc(m.vada).update({ available: false });
    const result = await publish();
    expect(result.version).toBe(1);

    const r = (await root.get()).data()!;
    expect(r.publishedVersion).toBe(1);
    expect(millis(r.publishedAt)).toBeGreaterThan(0);
    expect(millis(r.publishedDraftAt)).toBe(millis(r.publishedAt));
    expect(r.publishedCurrency).toBe("INR");
    expect(r.versionHistory).toHaveLength(1);
    expect(r.versionHistory[0]).toMatchObject({ n: 1, kind: "publish", publishedBy: "u1", summary: { added: 5 } });

    const v = (await data(`restaurants/${RID}/versions/1`))!;
    expect(v).toMatchObject({ n: 1, kind: "publish", rollbackOf: null, publishedBy: "u1" });
    const s = v.snapshot as MenuSnapshot;
    expect(s.items.map((i) => i.name)).toEqual(["Idli", "Vada", "Thali"]);
    expect(s.items[1].tags.map((t) => t.id)).toEqual(["spicy"]);
    expect(s.profile.contact).toEqual({ city: "Chennai" });
    expect(s.theme.themeId).toBe("saffron");

    const live = (await data(`restaurants/${RID}/live/availability`))!;
    expect(live.items).toEqual({ [m.idli]: true, [m.vada]: false, [m.thali]: true });

    const source = (await data(`restaurants/${RID}/versions/1/private/source`))!;
    expect(source.items).toHaveLength(3);

    const audits = await db.collection("auditLogs").where("restaurantId", "==", RID).get();
    expect(audits.docs.map((d) => d.get("action"))).toEqual(["menu.publish"]);
  });

  it("is blocked with every problem and writes nothing", async () => {
    const res = await codeOf(publish());
    expect(res.code).toBe("publish-blocked");
    expect((res.details!.problems as { code: string }[]).map((p) => p.code)).toEqual(["menu-empty"]);
    expect((await root.get()).get("publishedVersion")).toBeNull();

    await sampleMenu();
    expect((await codeOf(publish({}, false))).code).toBe("publish-blocked");
  });

  it("blocks over-limit content (BR-011)", async () => {
    await db.doc("plans/free").set({ limits: { maxItems: 2, maxCategories: 10 } });
    await sampleMenu().catch(() => undefined); // the third create fails on the limit
    await db.doc("plans/free").set({ limits: { maxItems: 1, maxCategories: 10 } });
    const res = await codeOf(publish());
    expect(res.details!.problems).toEqual([
      { code: "limit-exceeded", details: { limit: "items", max: 1, count: 2, planId: "free" } },
    ]);
  });

  it("needs the price review after a currency change and then clears it", async () => {
    await sampleMenu();
    await publish();
    await root.update({ currency: "AED", pricesNeedReview: true });
    const blocked = await codeOf(publish());
    expect((blocked.details!.problems as { code: string }[]).map((p) => p.code)).toEqual(["prices-need-review"]);
    expect((await dryRun()).pricesNeedReview).toBe(true);
    await publish({ pricesReviewed: true });
    const r = (await root.get()).data()!;
    expect(r.pricesNeedReview).toBe(false);
    expect(r.publishedCurrency).toBe("AED");
  });

  it("summarises changes against the live version", async () => {
    const m = await sampleMenu();
    await publish();
    await root.collection("items").doc(m.idli).update({ priceMinor: 13900 });
    await newItem(m.mains, "Biryani");
    await root.collection("categories").doc(m.starters).update({ name: "Tiffin" });
    const s = (await dryRun()).summary;
    expect(s.firstPublish).toBe(false);
    expect(s.items.added.map((i) => i.name)).toEqual(["Biryani"]);
    expect(s.items.changed.map((i) => i.name)).toEqual(["Idli"]);
    expect(s.categories.changed.map((c) => c.name)).toEqual(["Tiffin"]);
    const result = await publish();
    expect(result.version).toBe(2);
    expect((await data(`restaurants/${RID}/versions/2`))!.summary).toEqual({
      added: 1,
      changed: 2,
      removed: 0,
      profileChanged: false,
      themeChanged: false,
    });
  });

  it("keeps only the last 10 versions", async () => {
    const m = await sampleMenu();
    for (let i = 1; i <= 12; i++) {
      await root.collection("items").doc(m.idli).update({ priceMinor: 10000 + i });
      await publish();
    }
    const versions = await root.collection("versions").orderBy("n").get();
    expect(versions.docs.map((d) => d.get("n"))).toEqual([3, 4, 5, 6, 7, 8, 9, 10, 11, 12]);
    expect((await db.doc(`restaurants/${RID}/versions/2/private/source`).get()).exists).toBe(false);
    expect((await db.doc(`restaurants/${RID}/versions/3/private/source`).get()).exists).toBe(true);
    const history = (await root.get()).get("versionHistory") as { n: number }[];
    expect(history.map((h) => h.n)).toEqual([12, 11, 10, 9, 8, 7, 6, 5, 4, 3]);
  }, 60000);

  it("readers see the old or the new version during a publish, never a mix (AC-022)", async () => {
    const m = await sampleMenu();
    await publish();
    const oldNames = ["Idli", "Vada", "Thali"].join("|");
    await root.collection("items").doc(m.idli).update({ name: "Mini idli" });
    await root.collection("items").doc(m.thali).update({ name: "Veg thali" });
    const newNames = ["Mini idli", "Vada", "Veg thali"].join("|");

    let done = false;
    const seen = new Set<string>();
    const reader = (async () => {
      for (let last = false; !last; ) {
        // One more pass after the publish resolved, so the new version is read too.
        last = done;
        // How the public menu reads: the pointer, then that immutable version.
        const n = (await root.get()).get("publishedVersion") as number;
        const v = await db.doc(`restaurants/${RID}/versions/${n}`).get();
        const names = (v.get("snapshot") as MenuSnapshot).items.map((i) => i.name).join("|");
        seen.add(`${n}:${names}`);
      }
    })();
    await publish();
    done = true;
    await reader;
    for (const s of seen) expect([`1:${oldNames}`, `2:${newNames}`]).toContain(s);
    expect(seen).toContain(`2:${newNames}`);
  });
});

describe("unpublished changes and availability", () => {
  it("availability changes go live without a publish and are not draft changes (FR-095)", async () => {
    const m = await sampleMenu();
    await publish();
    const before = (await root.get()).data()!;
    await root.collection("items").doc(m.idli).update({ available: false, updatedAt: Timestamp.now() });
    await waitFor(() => data(`restaurants/${RID}/live/availability`), (d) => (d?.items as Record<string, boolean>)[m.idli] === false);
    const after = (await root.get()).data()!;
    expect(after.publishedVersion).toBe(1);
    expect(millis(after.draftUpdatedAt)).toBe(millis(before.draftUpdatedAt));
    expect((await dryRun()).summary.items.changed).toEqual([]);
  });

  it("a content edit after publishing marks the draft as changed", async () => {
    const m = await sampleMenu();
    await publish();
    const publishedDraftAt = millis((await root.get()).get("publishedDraftAt"))!;
    await root.collection("items").doc(m.idli).update({ name: "Mini idli", updatedAt: Timestamp.now() });
    const r = await waitFor(() => root.get(), (s) => (millis(s.get("draftUpdatedAt")) ?? 0) > publishedDraftAt);
    expect(millis(r.get("draftUpdatedAt"))).toBeGreaterThan(publishedDraftAt);
  });
});

describe("rollbackMenu", () => {
  it("publishes an earlier version as a new one and replaces the draft (AC-013)", async () => {
    const m = await sampleMenu();
    await publish(); // v1: Idli, Vada, Thali
    await root.collection("items").doc(m.idli).update({ name: "Mini idli" });
    const biryani = await newItem(m.mains, "Biryani");
    await root.collection("items").doc(m.vada).update({ deletedAt: Timestamp.now() });
    await root.update({ description: "Changed" });
    await publish(); // v2
    await root.collection("items").doc(m.thali).update({ available: false });

    const result = await rollbackMenu(db, owner(), { restaurantId: RID, version: 1 });
    expect(result.version).toBe(3);
    expect(result.summary.items.added.map((i) => i.name)).toEqual(["Vada"]);
    expect(result.summary.items.removed.map((i) => i.name)).toEqual(["Biryani"]);

    const v3 = (await data(`restaurants/${RID}/versions/3`))!;
    expect(v3).toMatchObject({ kind: "rollback", rollbackOf: 1 });
    const s = v3.snapshot as MenuSnapshot;
    expect(s.items.map((i) => i.name)).toEqual(["Idli", "Vada", "Thali"]);
    // Today's availability, not version 1's.
    expect(s.items.find((i) => i.id === m.thali)!.available).toBe(false);

    const items = await root.collection("items").get();
    const byId = Object.fromEntries(items.docs.map((d) => [d.id, d.data()]));
    expect(byId[m.idli].name).toBe("Idli");
    expect(byId[m.vada].deletedAt).toBeNull();
    expect(byId[biryani].deletedAt).toBeInstanceOf(Timestamp);
    expect(byId[m.thali].available).toBe(false);
    const r = (await root.get()).data()!;
    expect(r.description).toBeNull();
    expect(r.publishedVersion).toBe(3);
    expect(r.counts).toEqual({ categories: 2, items: 3 });
    expect(millis(r.publishedDraftAt)).toBe(millis(r.draftUpdatedAt));
  });

  it("can keep the draft, which then shows as unpublished", async () => {
    const m = await sampleMenu();
    await publish();
    await root.collection("items").doc(m.idli).update({ name: "Mini idli" });
    await publish();
    await rollbackMenu(db, owner(), { restaurantId: RID, version: 1, replaceDraft: false });
    expect((await root.collection("items").doc(m.idli).get()).get("name")).toBe("Mini idli");
    expect((await root.get()).get("publishedDraftAt")).toBeNull();
  });

  it("fails for a version that is not kept", async () => {
    await sampleMenu();
    await publish();
    expect((await codeOf(rollbackMenu(db, owner(), { restaurantId: RID, version: 7 }))).code).toBe("not-found");
  });
});

describe("discardDraft", () => {
  it("rewrites the draft from the live version without publishing", async () => {
    const m = await sampleMenu();
    await publish();
    await root.collection("items").doc(m.idli).update({ name: "Mini idli", priceMinor: 1 });
    const extra = await newItem(m.mains, "Biryani");
    await root.collection("categories").doc(m.mains).update({ active: false });
    await root.update({ currency: "AED", pricesNeedReview: true, themeSettings: { mode: "dark" } });

    expect(await discardDraft(db, owner(), { restaurantId: RID })).toEqual({ version: 1 });

    const items = Object.fromEntries((await root.collection("items").get()).docs.map((d) => [d.id, d.data()]));
    expect(items[m.idli]).toMatchObject({ name: "Idli", priceMinor: 12900, deletedAt: null });
    expect(items[extra].deletedAt).toBeInstanceOf(Timestamp);
    expect((await root.collection("categories").doc(m.mains).get()).get("active")).toBe(true);
    const r = (await root.get()).data()!;
    expect(r.publishedVersion).toBe(1);
    expect(r.currency).toBe("INR");
    expect(r.themeSettings).toEqual({});
    expect(r.pricesNeedReview).toBe(false);
    expect((await root.collection("versions").get()).size).toBe(1);
    expect((await dryRun()).summary.items).toEqual({ added: [], changed: [], removed: [] });

    // The triggers that follow do not mark the draft as changed again.
    await new Promise((res) => setTimeout(res, 3000));
    const later = (await root.get()).data()!;
    expect(millis(later.draftUpdatedAt)).toBe(millis(later.publishedDraftAt));
    expect(later.pricesNeedReview).toBe(false);
  });

  it("needs a published version", async () => {
    expect((await codeOf(discardDraft(db, owner(), { restaurantId: RID }))).code).toBe("not-found");
  });
});

describe("previewMenu", () => {
  it("renders the draft with noindex for the owner only", async () => {
    await sampleMenu();
    const { html, problems } = await previewMenu(db, owner(), { restaurantId: RID }, deps);
    expect(html).toContain("noindex");
    expect(html).toContain("Idli");
    expect(html).toContain("₹129.00");
    expect(problems).toEqual([]);
    expect((await codeOf(previewMenu(db, owner(true, "other"), { restaurantId: RID }, deps))).code).toBe("permission-denied");
  });
});

// storageUrlResolver (getDownloadURL) cannot run under Jest (the Storage
// client uses a dynamic import that Jest's VM refuses); scripts/check-storage-urls.mjs
// checks it against the Storage emulator after this suite.
