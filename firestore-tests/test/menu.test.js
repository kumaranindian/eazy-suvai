// M04: categories, items, dietary labels and item tags (architecture §5,
// FR-015 to FR-033, BR-005, BR-011, BR-019, AC-017).
import { after, before, beforeEach, describe, it } from "node:test";

import { assertFails, assertSucceeds } from "@firebase/rules-unit-testing";
import {
  collection,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  serverTimestamp,
  setDoc,
  Timestamp,
  updateDoc,
  writeBatch,
} from "firebase/firestore";

import { adminClaims, createEnv, mfaAdminClaims, ownerClaims } from "./helpers.js";

const RID = "rest_1";
const OTHER = "rest_2";

const restaurant = (ownerUid, extra = {}) => ({
  name: "Spice Garden",
  ownerUid,
  status: "active",
  planId: "free",
  counts: { categories: 1, items: 1 },
  ...extra,
});

const IMAGE = { path: `restaurants/${RID}/images/abcdefghijklmnop0001/original.png`, status: "ready" };

const category = (extra = {}) => ({
  name: "Dosa",
  description: "",
  image: IMAGE,
  sequence: 1000,
  active: true,
  deletedAt: null,
  ...extra,
});

const item = (extra = {}) => ({
  categoryId: "c1",
  name: "Masala dosa",
  description: "",
  image: IMAGE,
  priceMinor: 12900,
  dietaryLabelId: "vegetarian",
  tagIds: [],
  available: true,
  featured: false,
  sequence: 1000,
  hiddenOverLimit: false,
  deletedAt: null,
  deletedWith: null,
  ...extra,
});

let env;
before(async () => {
  env = await createEnv();
});
after(async () => {
  await env?.cleanup();
});
beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, `restaurants/${RID}`), restaurant("u1"));
    await setDoc(doc(db, `restaurants/${OTHER}`), restaurant("u2"));
    await setDoc(doc(db, "restaurants/susp"), restaurant("u3", { status: "suspended" }));
    for (const rid of [RID, OTHER, "susp"]) {
      await setDoc(doc(db, `restaurants/${rid}/categories/c1`), category());
      await setDoc(doc(db, `restaurants/${rid}/categories/gone`), category({ deletedAt: Timestamp.now() }));
      await setDoc(doc(db, `restaurants/${rid}/items/i1`), item());
      await setDoc(doc(db, `restaurants/${rid}/items/gone`), item({ deletedAt: Timestamp.now() }));
    }
    for (let n = 2; n <= 40; n++) {
      await setDoc(doc(db, `restaurants/${RID}/items/i${n}`), item({ sequence: n * 1000 }));
    }
    await setDoc(doc(db, "dietaryLabels/vegetarian"), { name: "Vegetarian", sort: 10 });
    await setDoc(doc(db, "dietaryLabels/vegan"), { name: "Vegan", sort: 30 });
    await setDoc(doc(db, "itemTags/spicy"), { name: "Spicy", sort: 10 });
  });
});

const ownerDb = (rid = RID, uid = "u1") => env.authenticatedContext(uid, ownerClaims(rid)).firestore();
const stamp = (fields) => ({ ...fields, updatedAt: serverTimestamp() });

describe("menu reads", () => {
  it("the owner reads and lists their own categories and items", async () => {
    const db = ownerDb();
    await assertSucceeds(getDoc(doc(db, `restaurants/${RID}/categories/c1`)));
    await assertSucceeds(getDocs(collection(db, `restaurants/${RID}/categories`)));
    await assertSucceeds(getDocs(collection(db, `restaurants/${RID}/items`)));
  });

  it("another restaurant's owner, a suspended owner and strangers cannot (AC-017)", async () => {
    await assertFails(getDoc(doc(ownerDb(OTHER, "u2"), `restaurants/${RID}/items/i1`)));
    await assertFails(getDocs(collection(ownerDb(OTHER, "u2"), `restaurants/${RID}/categories`)));
    await assertFails(getDoc(doc(ownerDb("susp", "u3"), "restaurants/susp/items/i1")));
    await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(), `restaurants/${RID}/items/i1`)));
    const unverified = env.authenticatedContext("u1", { ...ownerClaims(RID), email_verified: false }).firestore();
    await assertFails(getDoc(doc(unverified, `restaurants/${RID}/items/i1`)));
  });

  it("an admin needs TOTP (FR-084)", async () => {
    await assertSucceeds(getDoc(doc(env.authenticatedContext("a1", mfaAdminClaims).firestore(), `restaurants/${RID}/items/i1`)));
    await assertFails(getDoc(doc(env.authenticatedContext("a1", adminClaims).firestore(), `restaurants/${RID}/items/i1`)));
  });

  it("owners and admins read dietary labels and tags; others cannot; nobody writes them", async () => {
    await assertSucceeds(getDocs(collection(ownerDb(), "dietaryLabels")));
    await assertSucceeds(getDocs(collection(ownerDb(), "itemTags")));
    await assertSucceeds(getDocs(collection(env.authenticatedContext("a1", mfaAdminClaims).firestore(), "itemTags")));
    await assertFails(getDocs(collection(env.unauthenticatedContext().firestore(), "dietaryLabels")));
    await assertFails(getDocs(collection(env.authenticatedContext("x", { email_verified: true }).firestore(), "itemTags")));
    await assertFails(setDoc(doc(ownerDb(), "dietaryLabels/halal"), { name: "Halal" }));
    await assertFails(updateDoc(doc(ownerDb(), "itemTags/spicy"), { name: "Hot" }));
  });
});

describe("clients cannot create or delete menu content (BR-011)", () => {
  it("create and hard delete are denied, even for the owner", async () => {
    const db = ownerDb();
    await assertFails(setDoc(doc(db, `restaurants/${RID}/categories/new`), stamp(category())));
    await assertFails(setDoc(doc(db, `restaurants/${RID}/items/new`), stamp(item())));
    await assertFails(deleteDoc(doc(db, `restaurants/${RID}/items/i1`)));
    await assertFails(deleteDoc(doc(db, `restaurants/${RID}/categories/c1`)));
  });

  it("soft delete, restore, moves and system fields are not in the whitelist", async () => {
    const db = ownerDb();
    const ref = doc(db, `restaurants/${RID}/items/i1`);
    await assertFails(updateDoc(ref, stamp({ deletedAt: serverTimestamp() })));
    await assertFails(updateDoc(ref, stamp({ categoryId: "c2" })));
    await assertFails(updateDoc(ref, stamp({ hiddenOverLimit: true })));
    await assertFails(updateDoc(doc(db, `restaurants/${RID}/items/gone`), stamp({ deletedAt: null })));
    await assertFails(updateDoc(doc(db, `restaurants/${RID}/categories/gone`), stamp({ deletedAt: null })));
    await assertFails(updateDoc(doc(db, `restaurants/${RID}`), { "counts.items": 0 }));
  });
});

describe("category updates (FR-016, FR-017, FR-019)", () => {
  const ref = () => doc(ownerDb(), `restaurants/${RID}/categories/c1`);

  it("allows the whitelisted fields with updatedAt = server time", async () => {
    await assertSucceeds(
      updateDoc(ref(), stamp({ name: "x".repeat(60), description: "y".repeat(250), sequence: 1500, active: false })),
    );
    await assertSucceeds(updateDoc(ref(), stamp({ image: null })));
  });

  it("requires updatedAt to be the server time", async () => {
    await assertFails(updateDoc(ref(), { name: "Dosa varieties" }));
    await assertFails(updateDoc(ref(), { name: "Dosa varieties", updatedAt: Timestamp.fromMillis(0) }));
  });

  it("checks values", async () => {
    for (const bad of [
      { name: "x".repeat(61) },
      { name: "   " },
      { name: 5 },
      { description: "y".repeat(251) },
      { image: { ...IMAGE, path: "restaurants/rest_1/images/zzzzzzzzzzzzzzzz0002/original.png" } },
      { sequence: 1.5 },
      { sequence: -1 },
      { active: "yes" },
      { itemCount: 3 },
    ]) {
      await assertFails(updateDoc(ref(), stamp(bad)));
    }
  });

  it("another owner cannot update; a suspended owner cannot update their own", async () => {
    await assertFails(updateDoc(doc(ownerDb(OTHER, "u2"), `restaurants/${RID}/categories/c1`), stamp({ active: false })));
    await assertFails(updateDoc(doc(ownerDb("susp", "u3"), "restaurants/susp/categories/c1"), stamp({ active: false })));
  });
});

describe("item updates (FR-022 to FR-033)", () => {
  const ref = (id = "i1") => doc(ownerDb(), `restaurants/${RID}/items/${id}`);

  it("allows every whitelisted field at once", async () => {
    await assertSucceeds(
      updateDoc(
        ref(),
        stamp({
          name: "x".repeat(80),
          description: "y".repeat(500),
          image: null,
          priceMinor: 1250,
          dietaryLabelId: "vegan",
          tagIds: ["spicy", "new"],
          featured: true,
          sequence: 500,
          available: false,
        }),
      ),
    );
  });

  it("availability alone (FR-025, FR-095)", async () => {
    await assertSucceeds(updateDoc(ref(), stamp({ available: false })));
  });

  it("checks prices are integer minor units (BR-019)", async () => {
    await assertSucceeds(updateDoc(ref(), stamp({ priceMinor: 0 })));
    await assertSucceeds(updateDoc(ref(), stamp({ priceMinor: 999999999 })));
    for (const p of [12.5, -1, 1000000000, "1250"]) {
      await assertFails(updateDoc(ref(), stamp({ priceMinor: p })));
    }
  });

  it("checks the other values", async () => {
    for (const bad of [
      { name: "x".repeat(81) },
      { name: "" },
      { description: "y".repeat(501) },
      { image: { ...IMAGE, path: "restaurants/rest_1/images/zzzzzzzzzzzzzzzz0002/original.png" } },
      { dietaryLabelId: "pescatarian" },
      { dietaryLabelId: null },
      { tagIds: "spicy" },
      { tagIds: Array.from({ length: 11 }, (_, i) => `t${i}`) },
      { featured: 1 },
      { available: null },
      { sequence: "1" },
    ]) {
      await assertFails(updateDoc(ref(), stamp(bad)));
    }
  });

  it("another owner cannot update", async () => {
    await assertFails(updateDoc(doc(ownerDb(OTHER, "u2"), `restaurants/${RID}/items/i1`), stamp({ available: false })));
  });

  it("a reorder or bulk availability batch of 40 items fits the rules budget", async () => {
    const db = ownerDb();
    const batch = writeBatch(db);
    for (let n = 1; n <= 40; n++) {
      batch.update(doc(db, `restaurants/${RID}/items/i${n}`), stamp({ sequence: (41 - n) * 1000, available: false }));
    }
    await assertSucceeds(batch.commit());
  });
});
