// M06: published versions and the Functions-only publishing fields
// (FR-062, FR-096, BR-005, BR-011, AC-017).
import { after, before, beforeEach, describe, it } from "node:test";

import { assertFails, assertSucceeds } from "@firebase/rules-unit-testing";
import {
  collection,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  orderBy,
  query,
  serverTimestamp,
  setDoc,
  updateDoc,
} from "firebase/firestore";

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
    for (const [rid, uid, status] of [[RID, "u1", "active"], [OTHER, "u2", "active"], ["susp", "u3", "suspended"]]) {
      await setDoc(doc(db, `restaurants/${rid}`), {
        name: "Spice Garden",
        ownerUid: uid,
        status,
        publishedVersion: 2,
        pricesNeedReview: false,
      });
      for (const n of [1, 2]) {
        await setDoc(doc(db, `restaurants/${rid}/versions/${n}`), { n, snapshot: { items: [] } });
        await setDoc(doc(db, `restaurants/${rid}/versions/${n}/private/source`), { items: [] });
      }
      await setDoc(doc(db, `restaurants/${rid}/live/availability`), { items: { i1: true } });
    }
  });
});

const owner = (uid = "u1", rid = RID, extra = {}) =>
  env.authenticatedContext(uid, { ...ownerClaims(rid), ...extra }).firestore();
const mfaAdmin = () => env.authenticatedContext("admin1", mfaAdminClaims).firestore();

describe("versions (FR-096)", () => {
  it("the owner and MFA admins can read and list versions", async () => {
    for (const db of [owner(), mfaAdmin()]) {
      await assertSucceeds(getDoc(doc(db, `restaurants/${RID}/versions/1`)));
      await assertSucceeds(getDocs(query(collection(db, `restaurants/${RID}/versions`), orderBy("n", "desc"))));
    }
  });

  it("other tenants, unverified, suspended owners and admins without MFA cannot", async () => {
    for (const db of [
      owner("u2", OTHER),
      owner("u1", RID, { email_verified: false }),
      env.authenticatedContext("admin1", adminClaims).firestore(),
      env.unauthenticatedContext().firestore(),
    ]) {
      await assertFails(getDoc(doc(db, `restaurants/${RID}/versions/1`)));
      await assertFails(getDocs(collection(db, `restaurants/${RID}/versions`)));
    }
    await assertFails(getDoc(doc(owner("u3", "susp"), "restaurants/susp/versions/1")));
  });

  it("nobody writes versions from a client (immutable, Functions only)", async () => {
    for (const db of [owner(), mfaAdmin()]) {
      await assertFails(setDoc(doc(db, `restaurants/${RID}/versions/3`), { n: 3 }));
      await assertFails(updateDoc(doc(db, `restaurants/${RID}/versions/1`), { n: 9 }));
      await assertFails(deleteDoc(doc(db, `restaurants/${RID}/versions/1`)));
    }
  });

  it("the draft source and the availability overlay stay closed", async () => {
    for (const db of [owner(), mfaAdmin()]) {
      await assertFails(getDoc(doc(db, `restaurants/${RID}/versions/1/private/source`)));
      await assertFails(setDoc(doc(db, `restaurants/${RID}/versions/1/private/source`), { items: [] }));
      await assertFails(getDoc(doc(db, `restaurants/${RID}/live/availability`)));
      await assertFails(setDoc(doc(db, `restaurants/${RID}/live/availability`), { items: { i1: false } }));
    }
  });
});

describe("publishing fields on the restaurant root", () => {
  it("owners cannot set them, even with a draft stamp", async () => {
    for (const fields of [
      { publishedVersion: 3 },
      { publishedVersion: null },
      { publishedAt: serverTimestamp() },
      { publishedDraftAt: serverTimestamp() },
      { publishedCurrency: "AED" },
      { versionHistory: [] },
      { pricesNeedReview: true },
    ]) {
      await assertFails(updateDoc(doc(owner(), `restaurants/${RID}`), { ...fields, draftUpdatedAt: serverTimestamp() }));
    }
  });
});
