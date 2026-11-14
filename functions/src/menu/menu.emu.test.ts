import { Timestamp } from "firebase-admin/firestore";

import { appErrorCodeOf } from "../lib/errors";
import { admin, resetEmulators } from "../testing/emulator";
import {
  createCategory,
  createItem,
  deleteCategory,
  deleteItems,
  moveItems,
  restoreDeleted,
} from "./menu-callables";
import { DIETARY_LABELS, ITEM_TAGS } from "./seed-data";

const { db } = admin();

const RID = "rest_1";
const OTHER = "rest_2";
const root = db.doc(`restaurants/${RID}`);

const owner = (uid = "u1", rid = RID) => ({
  uid,
  token: { email_verified: true, role: "owner", restaurantId: rid },
});

async function seed(): Promise<void> {
  const restaurant = (ownerUid: string, extra: Record<string, unknown> = {}) => ({
    name: "Spice Garden",
    ownerUid,
    status: "active",
    planId: "free",
    currency: "INR",
    counts: { categories: 0, items: 0 },
    draftUpdatedAt: Timestamp.fromMillis(0),
    ...extra,
  });
  const writes: Promise<unknown>[] = [
    root.set(restaurant("u1")),
    db.doc(`restaurants/${OTHER}`).set(restaurant("u2")),
    db.doc("restaurants/susp").set(restaurant("u3", { status: "suspended" })),
  ];
  for (const { id, ...data } of DIETARY_LABELS) writes.push(db.doc(`dietaryLabels/${id}`).set(data));
  for (const { id, ...data } of ITEM_TAGS) writes.push(db.doc(`itemTags/${id}`).set(data));
  writes.push(db.doc("itemTags/retired-tag").set({ name: "Old", retired: true }));
  await Promise.all(writes);
}

async function codeOf(p: Promise<unknown>): Promise<string | undefined> {
  try {
    await p;
  } catch (e) {
    return appErrorCodeOf(e) ?? String(e);
  }
  throw new Error("expected rejection");
}

const newCategory = (name: string, extra: Record<string, unknown> = {}) =>
  createCategory(db, owner(), { restaurantId: RID, name, ...extra });

const newItem = (categoryId: string, name: string, extra: Record<string, unknown> = {}) =>
  createItem(db, owner(), {
    restaurantId: RID,
    categoryId,
    name,
    priceMinor: 12900,
    dietaryLabelId: "vegetarian",
    ...extra,
  });

async function data(path: string) {
  return (await db.doc(path).get()).data();
}

async function counts() {
  return (await root.get()).get("counts");
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

beforeEach(async () => {
  await resetEmulators();
  await seed();
});

describe("createCategory / createItem (FR-015, FR-022, AC-003, AC-004)", () => {
  it("creates categories at the end with gaps of 1000 and keeps counts", async () => {
    const a = await newCategory("  Starters ", { description: "Small plates" });
    const b = await newCategory("Mains", { active: false });
    expect(a.sequence).toBe(1000);
    expect(b.sequence).toBe(2000);
    expect(await data(`restaurants/${RID}/categories/${a.id}`)).toMatchObject({
      name: "Starters",
      description: "Small plates",
      image: null,
      active: true,
      deletedAt: null,
      sequence: 1000,
    });
    expect((await data(`restaurants/${RID}/categories/${b.id}`))?.active).toBe(false);
    expect(await counts()).toEqual({ categories: 2, items: 0 });
    expect(((await root.get()).get("draftUpdatedAt") as Timestamp).toMillis()).toBeGreaterThan(0);
  });

  it("creates an item with every FR-022 field, last in its category", async () => {
    const c = await newCategory("Dosa");
    const first = await newItem(c.id, "Plain dosa");
    const second = await newItem(c.id, "Masala dosa", {
      description: "With potato",
      priceMinor: 0,
      dietaryLabelId: "vegan",
      tagIds: ["spicy", "new"],
      available: false,
      featured: true,
    });
    expect(first.sequence).toBe(1000);
    expect(second.sequence).toBe(2000);
    expect(await data(`restaurants/${RID}/items/${second.id}`)).toMatchObject({
      categoryId: c.id,
      name: "Masala dosa",
      description: "With potato",
      image: null,
      priceMinor: 0,
      dietaryLabelId: "vegan",
      tagIds: ["spicy", "new"],
      available: false,
      featured: true,
      hiddenOverLimit: false,
      deletedAt: null,
    });
    expect(await counts()).toEqual({ categories: 1, items: 2 });
  });

  it("stores a KWD price of 1.250 as 1250 minor units (AC-029)", async () => {
    await root.update({ currency: "KWD" });
    const c = await newCategory("Drinks");
    const item = await newItem(c.id, "Tea", { priceMinor: 1250 });
    expect((await data(`restaurants/${RID}/items/${item.id}`))?.priceMinor).toBe(1250);
  });

  it("refuses a deleted or missing category, an unknown label and a retired tag (BR-004, FR-104)", async () => {
    const c = await newCategory("Dosa");
    expect(await codeOf(newItem("nope", "X"))).toBe("not-found");
    expect(await codeOf(newItem(c.id, "X", { dietaryLabelId: "pescatarian" }))).toBe("invalid-input");
    expect(await codeOf(newItem(c.id, "X", { tagIds: ["retired-tag"] }))).toBe("invalid-input");
    expect(await codeOf(newItem(c.id, "X", { tagIds: ["unknown"] }))).toBe("invalid-input");
    await deleteCategory(db, owner(), { restaurantId: RID, categoryId: c.id, mode: "deleteAll" });
    expect(await codeOf(newItem(c.id, "X"))).toBe("category-deleted");
    expect(await counts()).toEqual({ categories: 0, items: 0 });
  });

  it("refuses other tenants, suspended accounts and unverified callers (AC-017)", async () => {
    expect(await codeOf(createCategory(db, owner("u2", OTHER), { restaurantId: RID, name: "X" }))).toBe(
      "permission-denied",
    );
    expect(await codeOf(createCategory(db, owner("u3", "susp"), { restaurantId: "susp", name: "X" }))).toBe(
      "account-inactive",
    );
    expect(
      await codeOf(
        createCategory(db, { uid: "u1", token: { role: "owner", restaurantId: RID } }, { restaurantId: RID, name: "X" }),
      ),
    ).toBe("email-not-verified");
    expect((await db.collection(`restaurants/${RID}/categories`).get()).size).toBe(0);
  });
});

describe("plan limits on create (BR-011, AC-018)", () => {
  it("stops at the Free plan's 10 categories without a plan document", async () => {
    for (let i = 0; i < 10; i++) await newCategory(`C${i}`);
    expect(await codeOf(newCategory("Eleventh"))).toBe("limit-reached");
    expect(await counts()).toEqual({ categories: 10, items: 0 });
  });

  it("uses plans/{planId}.limits and counts only non-deleted items", async () => {
    await db.doc("plans/free").set({ limits: { maxItems: 2, maxCategories: 5 } });
    const c = await newCategory("Dosa");
    const a = await newItem(c.id, "A");
    await newItem(c.id, "B");
    expect(await codeOf(newItem(c.id, "C"))).toBe("limit-reached");
    await deleteItems(db, owner(), { restaurantId: RID, itemIds: [a.id] });
    await newItem(c.id, "C");
    expect(await counts()).toEqual({ categories: 1, items: 2 });
  });

  it("lets exactly the allowed number through when devices create at the same time", async () => {
    await db.doc("plans/free").set({ limits: { maxItems: 3, maxCategories: 3 } });
    const c = await newCategory("Dosa");
    await newItem(c.id, "Existing");

    const results = await Promise.allSettled(Array.from({ length: 6 }, (_, i) => newItem(c.id, `Racer ${i}`)));
    const ok = results.filter((r) => r.status === "fulfilled");
    const refused = results.filter((r) => r.status === "rejected").map((r) => appErrorCodeOf(r.reason));
    expect(ok).toHaveLength(2);
    expect(refused).toEqual(Array(4).fill("limit-reached"));

    const live = await db.collection(`restaurants/${RID}/items`).where("deletedAt", "==", null).get();
    expect(live.size).toBe(3);
    expect((await counts()).items).toBe(3);

    const cats = await Promise.allSettled(Array.from({ length: 4 }, (_, i) => newCategory(`Cat ${i}`)));
    expect(cats.filter((r) => r.status === "fulfilled")).toHaveLength(2);
    expect((await counts()).categories).toBe(3);
  });
});

describe("deleteCategory (FR-018, AC-027)", () => {
  it("deletes an empty category with a single confirmation", async () => {
    const c = await newCategory("Empty");
    expect(await deleteCategory(db, owner(), { restaurantId: RID, categoryId: c.id, mode: "deleteAll" })).toEqual({
      moved: 0,
      deleted: 0,
    });
    expect((await data(`restaurants/${RID}/categories/${c.id}`))?.deletedAt).toBeInstanceOf(Timestamp);
    expect(await counts()).toEqual({ categories: 0, items: 0 });
  });

  it("moves the items to the end of another category, in order", async () => {
    const from = await newCategory("Old");
    const to = await newCategory("New");
    const kept = await newItem(to.id, "Kept");
    const a = await newItem(from.id, "A");
    const b = await newItem(from.id, "B");

    expect(
      await codeOf(deleteCategory(db, owner(), { restaurantId: RID, categoryId: from.id, mode: "move" })),
    ).toBe("invalid-input");
    expect(
      await codeOf(
        deleteCategory(db, owner(), { restaurantId: RID, categoryId: from.id, mode: "move", targetCategoryId: from.id }),
      ),
    ).toBe("invalid-input");

    const r = await deleteCategory(db, owner(), {
      restaurantId: RID,
      categoryId: from.id,
      mode: "move",
      targetCategoryId: to.id,
    });
    expect(r).toEqual({ moved: 2, deleted: 0 });
    const items = await Promise.all([kept, a, b].map((i) => data(`restaurants/${RID}/items/${i.id}`)));
    expect(items.map((i) => [i?.name, i?.categoryId, i?.sequence])).toEqual([
      ["Kept", to.id, 1000],
      ["A", to.id, 2000],
      ["B", to.id, 3000],
    ]);
    expect(await counts()).toEqual({ categories: 1, items: 3 });
  });

  it("deletes the category and its items only when the typed name matches", async () => {
    const c = await newCategory("Main Course");
    await newItem(c.id, "A");
    await newItem(c.id, "B");
    expect(
      await codeOf(deleteCategory(db, owner(), { restaurantId: RID, categoryId: c.id, mode: "deleteAll" })),
    ).toBe("invalid-input");
    expect(
      await codeOf(
        deleteCategory(db, owner(), { restaurantId: RID, categoryId: c.id, mode: "deleteAll", confirmName: "Main" }),
      ),
    ).toBe("invalid-input");
    expect(await counts()).toEqual({ categories: 1, items: 2 });

    const r = await deleteCategory(db, owner(), {
      restaurantId: RID,
      categoryId: c.id,
      mode: "deleteAll",
      confirmName: " main  course",
    });
    expect(r).toEqual({ moved: 0, deleted: 2 });
    const items = await db.collection(`restaurants/${RID}/items`).get();
    for (const d of items.docs) {
      expect(d.get("deletedAt")).toBeInstanceOf(Timestamp);
      expect(d.get("deletedWith")).toBe(c.id);
    }
    expect(await counts()).toEqual({ categories: 0, items: 0 });
    expect(await codeOf(deleteCategory(db, owner(), { restaurantId: RID, categoryId: c.id, mode: "deleteAll" }))).toBe(
      "not-found",
    );
  });

  it("refuses moving into a deleted category", async () => {
    const a = await newCategory("A");
    const b = await newCategory("B");
    await newItem(a.id, "X");
    await deleteCategory(db, owner(), { restaurantId: RID, categoryId: b.id, mode: "deleteAll" });
    expect(
      await codeOf(
        deleteCategory(db, owner(), { restaurantId: RID, categoryId: a.id, mode: "move", targetCategoryId: b.id }),
      ),
    ).toBe("category-deleted");
  });
});

describe("moveItems and deleteItems (FR-097, FR-024)", () => {
  it("moves items in bulk to the end of the target, in the order given", async () => {
    const a = await newCategory("A");
    const b = await newCategory("B");
    const x = await newItem(a.id, "X");
    const y = await newItem(a.id, "Y");
    const z = await newItem(b.id, "Z");
    expect(await moveItems(db, owner(), { restaurantId: RID, itemIds: [y.id, x.id, z.id], targetCategoryId: b.id }))
      .toEqual({ moved: 2 });
    const seq = async (id: string) => (await data(`restaurants/${RID}/items/${id}`))?.sequence;
    expect([await seq(z.id), await seq(y.id), await seq(x.id)]).toEqual([1000, 2000, 3000]);
    expect((await data(`restaurants/${RID}/items/${x.id}`))?.categoryId).toBe(b.id);
    expect(await codeOf(moveItems(db, owner(), { restaurantId: RID, itemIds: ["nope"], targetCategoryId: b.id })))
      .toBe("not-found");
    expect(
      await codeOf(moveItems(db, owner("u2", OTHER), { restaurantId: RID, itemIds: [x.id], targetCategoryId: a.id })),
    ).toBe("permission-denied");
  });

  it("soft-deletes items and skips ones already deleted", async () => {
    const a = await newCategory("A");
    const x = await newItem(a.id, "X");
    const y = await newItem(a.id, "Y");
    expect(await deleteItems(db, owner(), { restaurantId: RID, itemIds: [x.id] })).toEqual({ deleted: 1 });
    expect(await deleteItems(db, owner(), { restaurantId: RID, itemIds: [x.id, y.id] })).toEqual({ deleted: 1 });
    expect(await counts()).toEqual({ categories: 1, items: 0 });
    const doc = await data(`restaurants/${RID}/items/${x.id}`);
    expect(doc?.deletedAt).toBeInstanceOf(Timestamp);
    expect(doc?.deletedWith).toBeNull();
  });
});

describe("restoreDeleted (FR-098, AC-028)", () => {
  it("restores a category with the items deleted with it, at the end", async () => {
    const a = await newCategory("A");
    const b = await newCategory("B");
    const x = await newItem(a.id, "X");
    const lone = await newItem(a.id, "Deleted earlier");
    await deleteItems(db, owner(), { restaurantId: RID, itemIds: [lone.id] });
    await deleteCategory(db, owner(), { restaurantId: RID, categoryId: a.id, mode: "deleteAll", confirmName: "A" });
    await newCategory("C");

    const r = await restoreDeleted(db, owner(), { restaurantId: RID, kind: "category", id: a.id });
    expect(r).toEqual({ categories: 1, items: 1, categoryId: a.id });
    const cat = await data(`restaurants/${RID}/categories/${a.id}`);
    expect(cat?.deletedAt).toBeNull();
    expect(cat?.sequence).toBe(4000);
    expect((await data(`restaurants/${RID}/items/${x.id}`))?.deletedAt).toBeNull();
    // An item deleted on its own stays in Recently deleted.
    expect((await data(`restaurants/${RID}/items/${lone.id}`))?.deletedAt).toBeInstanceOf(Timestamp);
    expect(await counts()).toEqual({ categories: 3, items: 1 });
    expect(b.id).toBeTruthy();
  });

  it("restores an item to its category, or asks for another when that one is deleted", async () => {
    const a = await newCategory("A");
    const b = await newCategory("B");
    const x = await newItem(a.id, "X");
    await newItem(b.id, "Y");
    await deleteItems(db, owner(), { restaurantId: RID, itemIds: [x.id] });
    expect(await restoreDeleted(db, owner(), { restaurantId: RID, kind: "item", id: x.id })).toMatchObject({
      items: 1,
      categoryId: a.id,
    });

    await deleteItems(db, owner(), { restaurantId: RID, itemIds: [x.id] });
    await deleteCategory(db, owner(), { restaurantId: RID, categoryId: a.id, mode: "deleteAll" });
    expect(await codeOf(restoreDeleted(db, owner(), { restaurantId: RID, kind: "item", id: x.id }))).toBe(
      "category-deleted",
    );
    await restoreDeleted(db, owner(), { restaurantId: RID, kind: "item", id: x.id, targetCategoryId: b.id });
    const item = await data(`restaurants/${RID}/items/${x.id}`);
    expect(item).toMatchObject({ categoryId: b.id, deletedAt: null, sequence: 2000 });
    expect(await counts()).toEqual({ categories: 1, items: 2 });
  });

  it("refuses after 30 days, for live content, and past the plan limit", async () => {
    await db.doc("plans/free").set({ limits: { maxItems: 1, maxCategories: 5 } });
    const a = await newCategory("A");
    const x = await newItem(a.id, "X");
    await deleteItems(db, owner(), { restaurantId: RID, itemIds: [x.id] });
    const later = new Date(Date.now() + 31 * 86_400_000);
    expect(
      await codeOf(restoreDeleted(db, owner(), { restaurantId: RID, kind: "item", id: x.id }, { now: later })),
    ).toBe("not-found");

    await newItem(a.id, "Y");
    expect(await codeOf(restoreDeleted(db, owner(), { restaurantId: RID, kind: "item", id: x.id }))).toBe(
      "limit-reached",
    );
    expect(await codeOf(restoreDeleted(db, owner(), { restaurantId: RID, kind: "category", id: a.id }))).toBe(
      "not-found",
    );
  });
});

describe("onItemWrite / onCategoryWrite through the Functions emulator", () => {
  it("writes availability changes to live/availability at once, without a draft change (FR-095, AC-007)", async () => {
    const c = await newCategory("Dosa");
    const x = await newItem(c.id, "X");
    const live = db.doc(`restaurants/${RID}/live/availability`);
    await waitFor(
      async () => (await live.get()).data(),
      (d) => d?.items?.[x.id] === true,
    );
    const draftBefore = ((await root.get()).get("draftUpdatedAt") as Timestamp).toMillis();

    // What the owner app does: a direct whitelisted update.
    await db.doc(`restaurants/${RID}/items/${x.id}`).update({ available: false, updatedAt: Timestamp.now() });
    await waitFor(
      async () => (await live.get()).data(),
      (d) => d?.items?.[x.id] === false,
    );
    await new Promise((r) => setTimeout(r, 1500));
    expect(((await root.get()).get("draftUpdatedAt") as Timestamp).toMillis()).toBe(draftBefore);
  });

  it("bumps draftUpdatedAt for a direct content edit and recounts after removals", async () => {
    const c = await newCategory("Dosa");
    const x = await newItem(c.id, "X");
    await newItem(c.id, "Y");
    await root.update({ draftUpdatedAt: Timestamp.fromMillis(0) });

    await db.doc(`restaurants/${RID}/items/${x.id}`).update({ priceMinor: 15000, updatedAt: Timestamp.now() });
    await waitFor(
      async () => ((await root.get()).get("draftUpdatedAt") as Timestamp).toMillis(),
      (ms) => ms > 0,
    );

    // A removal outside the callables (console, M12 purge) is recounted.
    await db.doc(`restaurants/${RID}/items/${x.id}`).delete();
    await db.doc(`restaurants/${RID}/categories/${c.id}`).update({ deletedAt: Timestamp.now() });
    await waitFor(counts, (n) => n.items === 1 && n.categories === 0);
    await waitFor(
      async () => (await db.doc(`restaurants/${RID}/live/availability`).get()).data(),
      (d) => d !== undefined && !(x.id in (d.items ?? {})),
    );
  });
});
