// M09: analytics aggregates (FR-072, BR-005, AC-015). Only collectEvent
// (Admin SDK) writes; the owner and TOTP admins read.
import { after, before, beforeEach, describe, it } from "node:test";

import { assertFails, assertSucceeds } from "@firebase/rules-unit-testing";
import {
  collection,
  deleteDoc,
  doc,
  documentId,
  getDoc,
  getDocs,
  orderBy,
  query,
  setDoc,
  updateDoc,
  where,
} from "firebase/firestore";

import { adminClaims, createEnv, mfaAdminClaims, ownerClaims } from "./helpers.js";

const RID = "rest_1";
const OTHER = "rest_2";
const DAY = "2026-11-15";

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
      await setDoc(doc(db, `restaurants/${rid}`), { name: "R", ownerUid: uid, status });
      await setDoc(doc(db, `restaurants/${rid}/analyticsDaily/${DAY}`), { day: DAY, views: 4, qrVisits: 2 });
    }
    await setDoc(doc(db, "analyticsEvents/e1"), { restaurantId: RID, type: "view" });
    await setDoc(doc(db, "stats/platform"), { menuViews: 10 });
  });
});

const owner = (uid = "u1", rid = RID, extra = {}) =>
  env.authenticatedContext(uid, { ...ownerClaims(rid), ...extra }).firestore();
const mfaAdmin = () => env.authenticatedContext("admin1", mfaAdminClaims).firestore();

describe("analyticsDaily", () => {
  it("the owner and MFA admins read a day and a range", async () => {
    for (const db of [owner(), mfaAdmin()]) {
      await assertSucceeds(getDoc(doc(db, `restaurants/${RID}/analyticsDaily/${DAY}`)));
      const range = query(
        collection(db, `restaurants/${RID}/analyticsDaily`),
        orderBy(documentId()),
        where(documentId(), ">=", "2026-11-01"),
        where(documentId(), "<=", "2026-11-30"),
      );
      await assertSucceeds(getDocs(range));
    }
  });

  it("another owner, unverified or suspended owners, admins without MFA and strangers cannot", async () => {
    for (const db of [
      owner("u2", OTHER),
      owner("u1", RID, { email_verified: false }),
      env.authenticatedContext("admin1", adminClaims).firestore(),
      env.authenticatedContext("stranger").firestore(),
      env.unauthenticatedContext().firestore(),
    ]) {
      await assertFails(getDoc(doc(db, `restaurants/${RID}/analyticsDaily/${DAY}`)));
      await assertFails(getDocs(collection(db, `restaurants/${RID}/analyticsDaily`)));
    }
    await assertFails(getDoc(doc(owner("u3", "susp"), `restaurants/susp/analyticsDaily/${DAY}`)));
  });

  it("no client writes aggregates, raw events or platform stats", async () => {
    for (const db of [owner(), mfaAdmin(), env.unauthenticatedContext().firestore()]) {
      await assertFails(setDoc(doc(db, `restaurants/${RID}/analyticsDaily/2026-11-16`), { views: 1 }));
      await assertFails(updateDoc(doc(db, `restaurants/${RID}/analyticsDaily/${DAY}`), { views: 999 }));
      await assertFails(deleteDoc(doc(db, `restaurants/${RID}/analyticsDaily/${DAY}`)));
      await assertFails(setDoc(doc(db, "analyticsEvents/e2"), { restaurantId: RID, type: "view" }));
      await assertFails(setDoc(doc(db, "stats/platform"), { menuViews: 0 }));
    }
  });

  it("raw events and platform stats are not readable by owners", async () => {
    await assertFails(getDoc(doc(owner(), "analyticsEvents/e1")));
    await assertFails(getDocs(collection(owner(), "analyticsEvents")));
    await assertFails(getDoc(doc(owner(), "stats/platform")));
  });
});

describe("QR download counter (M13, FRD §13)", () => {
  const owner = () => env.authenticatedContext("u1", ownerClaims(RID)).firestore();

  it("lets the owner add exactly one, alone", async () => {
    await assertSucceeds(updateDoc(doc(owner(), `restaurants/${RID}`), { qrDownloads: 1 }));
    await assertSucceeds(updateDoc(doc(owner(), `restaurants/${RID}`), { qrDownloads: 2 }));
  });

  it("refuses jumps, decreases and extra fields", async () => {
    await assertFails(updateDoc(doc(owner(), `restaurants/${RID}`), { qrDownloads: 5 }));
    await assertFails(updateDoc(doc(owner(), `restaurants/${RID}`), { qrDownloads: -1 }));
    await assertFails(updateDoc(doc(owner(), `restaurants/${RID}`), { qrDownloads: 1, status: "active", planId: "pro" }));
    await assertFails(updateDoc(doc(owner(), `restaurants/${RID}`), { qrDownloads: "1" }));
  });

  it("refuses other tenants and signed-out users", async () => {
    await assertFails(updateDoc(doc(owner(), `restaurants/${OTHER}`), { qrDownloads: 1 }));
    await assertFails(updateDoc(doc(env.unauthenticatedContext().firestore(), `restaurants/${RID}`), { qrDownloads: 1 }));
  });
});
