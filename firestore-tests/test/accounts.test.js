// M01: users/{uid} and restaurants/{rid} reads (FR-091, AC-017, FR-084).
import { after, before, beforeEach, describe, it } from "node:test";

import { assertFails, assertSucceeds } from "@firebase/rules-unit-testing";
import { collection, doc, getDoc, getDocs, setDoc, updateDoc, deleteDoc } from "firebase/firestore";

import { adminClaims, createEnv, mfaAdminClaims, ownerClaims } from "./helpers.js";

const RID = "rest_1";
const OTHER = "rest_2";

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
    await setDoc(doc(db, "users/u1"), { email: "a@example.com", role: "owner", restaurantId: RID });
    await setDoc(doc(db, "users/u2"), { email: "b@example.com", role: "owner", restaurantId: OTHER });
    await setDoc(doc(db, `restaurants/${RID}`), { name: "Spice Garden", status: "active", ownerUid: "u1" });
    await setDoc(doc(db, `restaurants/${OTHER}`), { name: "Other", status: "active", ownerUid: "u2" });
    await setDoc(doc(db, "restaurants/suspended1"), { name: "S", status: "suspended", ownerUid: "u3" });
  });
});

const owner = (uid = "u1", rid = RID, extra = {}) =>
  env.authenticatedContext(uid, { ...ownerClaims(rid), ...extra }).firestore();

describe("users/{uid}", () => {
  it("a verified user can read their own profile", async () => {
    await assertSucceeds(getDoc(doc(owner(), "users/u1")));
  });

  it("an unverified user cannot read their own profile, even with claims (FR-091)", async () => {
    await assertFails(getDoc(doc(owner("u1", RID, { email_verified: false }), "users/u1")));
    const noClaims = env.authenticatedContext("u1", { email_verified: false }).firestore();
    await assertFails(getDoc(doc(noClaims, "users/u1")));
  });

  it("nobody can read another user's profile or list users", async () => {
    await assertFails(getDoc(doc(owner(), "users/u2")));
    await assertFails(getDocs(collection(owner(), "users")));
    await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(), "users/u1")));
  });

  it("clients cannot write profiles (Functions only)", async () => {
    await assertFails(setDoc(doc(owner(), "users/u1"), { role: "platformAdmin" }, { merge: true }));
    await assertFails(setDoc(doc(owner("u9", RID), "users/u9"), { role: "owner", restaurantId: RID }));
    await assertFails(deleteDoc(doc(owner(), "users/u1")));
  });

  it("an admin with TOTP can read and list; without MFA cannot (FR-084)", async () => {
    const admin = env.authenticatedContext("admin1", mfaAdminClaims).firestore();
    await assertSucceeds(getDoc(doc(admin, "users/u1")));
    await assertSucceeds(getDocs(collection(admin, "users")));
    const noMfa = env.authenticatedContext("admin1", adminClaims).firestore();
    await assertFails(getDoc(doc(noMfa, "users/u1")));
  });
});

describe("restaurants/{rid}", () => {
  it("a verified owner can read their own restaurant", async () => {
    await assertSucceeds(getDoc(doc(owner(), `restaurants/${RID}`)));
  });

  it("an unverified owner cannot read it, even with valid claims (FR-091)", async () => {
    await assertFails(getDoc(doc(owner("u1", RID, { email_verified: false }), `restaurants/${RID}`)));
  });

  it("an owner cannot read another tenant's restaurant (AC-017)", async () => {
    await assertFails(getDoc(doc(owner(), `restaurants/${OTHER}`)));
    await assertFails(getDocs(collection(owner(), "restaurants")));
  });

  it("a claim for a restaurant without the owner role is refused", async () => {
    const db = env.authenticatedContext("u1", { email_verified: true, restaurantId: RID }).firestore();
    await assertFails(getDoc(doc(db, `restaurants/${RID}`)));
  });

  it("an owner of a suspended restaurant cannot read it (FR-010)", async () => {
    await assertFails(getDoc(doc(owner("u3", "suspended1"), "restaurants/suspended1")));
  });

  it("owners cannot create or delete the tenant root, or change system fields (M03 whitelist: restaurant-profile.test.js)", async () => {
    await assertFails(updateDoc(doc(owner(), `restaurants/${RID}`), { planId: "pro" }));
    await assertFails(setDoc(doc(owner(), "restaurants/new"), { ownerUid: "u1", status: "active" }));
    await assertFails(deleteDoc(doc(owner(), `restaurants/${RID}`)));
  });

  it("an admin with TOTP can read any restaurant; without MFA cannot", async () => {
    const admin = env.authenticatedContext("admin1", mfaAdminClaims).firestore();
    await assertSucceeds(getDoc(doc(admin, `restaurants/${OTHER}`)));
    await assertSucceeds(getDocs(collection(admin, "restaurants")));
    const noMfa = env.authenticatedContext("admin1", adminClaims).firestore();
    await assertFails(getDoc(doc(noMfa, `restaurants/${OTHER}`)));
    await assertFails(updateDoc(doc(admin, `restaurants/${OTHER}`), { status: "suspended" }));
  });
});

describe("slugs and qrCodes", () => {
  it("stay closed to clients", async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), "slugs/spice-garden"), { restaurantId: RID, current: true });
      await setDoc(doc(ctx.firestore(), "qrCodes/ABCDEFGH"), { restaurantId: RID, kind: "restaurant" });
    });
    for (const db of [owner(), env.authenticatedContext("admin1", mfaAdminClaims).firestore()]) {
      await assertFails(getDoc(doc(db, "slugs/spice-garden")));
      await assertFails(getDoc(doc(db, "qrCodes/ABCDEFGH")));
      await assertFails(setDoc(doc(db, "slugs/taken"), { restaurantId: RID, current: true }));
      await assertFails(setDoc(doc(db, "qrCodes/ZZZZZZZZ"), { restaurantId: RID }));
    }
  });
});
