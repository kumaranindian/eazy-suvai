// M11: owners cannot read or write admin data; the account status and the
// announcement reach the owner app (FR-084, FR-090, FR-099, BR-014).
import { after, before, beforeEach, describe, it } from "node:test";

import { assertFails, assertSucceeds } from "@firebase/rules-unit-testing";
import { collection, doc, getDoc, getDocs, setDoc, updateDoc } from "firebase/firestore";

import { createEnv, mfaAdminClaims, ownerClaims } from "./helpers.js";

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
    await setDoc(doc(db, "restaurants/rest_1"), { name: "Spice", ownerUid: "u1", status: "active" });
    await setDoc(doc(db, "users/u1"), { email: "owner@example.com", role: "owner", restaurantId: "rest_1", accountStatus: "suspended" });
    await setDoc(doc(db, "config/platform"), { announcement: { text: "Maintenance", active: true, level: "info" } });
    await setDoc(doc(db, "auditLogs/a1"), { action: "restaurant.suspend", restaurantId: "rest_1" });
    await setDoc(doc(db, "stats/platform"), { restaurants: 1 });
    await setDoc(doc(db, "upgradeRequests/r1"), { restaurantId: "rest_1", status: "pending" });
  });
});

const owner = () => env.authenticatedContext("u1", ownerClaims("rest_1")).firestore();

describe("admin data", () => {
  it("owners read their account status and the announcement, nothing admin-only", async () => {
    const db = owner();
    await assertSucceeds(getDoc(doc(db, "users/u1")));
    await assertSucceeds(getDoc(doc(db, "config/platform")));
    for (const path of ["auditLogs/a1", "stats/platform", "upgradeRequests/r1", "paymentArchive/x", "config/purge"]) await assertFails(getDoc(doc(db, path)));
    for (const name of ["auditLogs", "upgradeRequests", "users"]) await assertFails(getDocs(collection(db, name)));
  });

  it("nobody writes account status, settings, audit or stats from a client", async () => {
    for (const db of [owner(), env.authenticatedContext("admin1", mfaAdminClaims).firestore()]) {
      await assertFails(updateDoc(doc(db, "users/u1"), { accountStatus: "active" }));
      await assertFails(setDoc(doc(db, "config/platform"), { graceDays: 30 }, { merge: true }));
      await assertFails(setDoc(doc(db, "auditLogs/a2"), { action: "x" }));
      await assertFails(updateDoc(doc(db, "stats/platform"), { restaurants: 9 }));
      await assertFails(updateDoc(doc(db, "restaurants/rest_1"), { status: "suspended" }));
    }
  });
});
