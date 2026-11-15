// M10: plans, premium themes and the Functions-only subscription data
// (FR-076, FR-078, FR-106, BR-011).
import { after, before, beforeEach, describe, it } from "node:test";

import { assertFails, assertSucceeds } from "@firebase/rules-unit-testing";
import { collection, doc, getDoc, getDocs, serverTimestamp, setDoc, updateDoc } from "firebase/firestore";

import { adminClaims, createEnv, mfaAdminClaims, ownerClaims } from "./helpers.js";

const RID = "rest_1";
const PRO = "rest_pro";

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
    const base = { name: "Spice Garden", status: "active", themeId: null, themeSettings: {} };
    await setDoc(doc(db, `restaurants/${RID}`), { ...base, ownerUid: "u1", planId: "free", planFeatures: { premiumThemes: false } });
    await setDoc(doc(db, `restaurants/${PRO}`), { ...base, ownerUid: "u2", planId: "pro", planFeatures: { premiumThemes: true } });
    await setDoc(doc(db, "restaurants/legacy"), { ...base, ownerUid: "u3", planId: "free" });
    await setDoc(doc(db, "themes/saffron"), { name: "Saffron", premium: false });
    await setDoc(doc(db, "themes/midnight"), { name: "Midnight", premium: true });
    await setDoc(doc(db, "plans/free"), { name: "Free", limits: { maxItems: 50 } });
    await setDoc(doc(db, "plans/pro"), { name: "Pro", limits: { maxItems: 500 } });
    await setDoc(doc(db, `restaurants/${RID}/payments/p1`), { amountMinor: 99900 });
    await setDoc(doc(db, `restaurants/${RID}/subscriptionHistory/h1`), { action: "activate" });
    await setDoc(doc(db, "upgradeRequests/r1"), { restaurantId: RID, status: "pending" });
  });
});

const owner = (uid, rid) => env.authenticatedContext(uid, ownerClaims(rid)).firestore();
const draft = (fields) => ({ ...fields, draftUpdatedAt: serverTimestamp() });

describe("plans", () => {
  it("owners and MFA admins read plans; nobody writes them", async () => {
    for (const db of [owner("u1", RID), env.authenticatedContext("admin1", mfaAdminClaims).firestore()]) {
      await assertSucceeds(getDoc(doc(db, "plans/pro")));
      await assertSucceeds(getDocs(collection(db, "plans")));
      await assertFails(setDoc(doc(db, "plans/pro"), { limits: { maxItems: 99999 } }));
    }
    for (const db of [env.unauthenticatedContext().firestore(), env.authenticatedContext("admin1", adminClaims).firestore()]) {
      await assertFails(getDoc(doc(db, "plans/pro")));
    }
  });
});

describe("premium themes (BR-011)", () => {
  it("Free restaurants can pick only non-premium themes", async () => {
    await assertSucceeds(updateDoc(doc(owner("u1", RID), `restaurants/${RID}`), draft({ themeId: "saffron" })));
    await assertFails(updateDoc(doc(owner("u1", RID), `restaurants/${RID}`), draft({ themeId: "midnight" })));
    // No planFeatures yet (created before M10): treated as Free.
    await assertFails(updateDoc(doc(owner("u3", "legacy"), "restaurants/legacy"), draft({ themeId: "midnight" })));
  });

  it("Pro restaurants can pick premium themes", async () => {
    await assertSucceeds(updateDoc(doc(owner("u2", PRO), `restaurants/${PRO}`), draft({ themeId: "midnight" })));
  });

  it("owners cannot change their plan, subscription or flags", async () => {
    const db = owner("u1", RID);
    for (const patch of [
      { planId: "pro" },
      { planFeatures: { premiumThemes: true } },
      { subscription: { status: "active" } },
      { pendingUpgradeRequestId: null },
      { planNotice: null },
    ]) {
      await assertFails(updateDoc(doc(db, `restaurants/${RID}`), draft(patch)));
    }
  });
});

describe("subscription data is Functions-only", () => {
  it("payments, history, requests and mail are closed to clients", async () => {
    for (const db of [owner("u1", RID), env.authenticatedContext("admin1", mfaAdminClaims).firestore()]) {
      await assertFails(getDoc(doc(db, `restaurants/${RID}/payments/p1`)));
      await assertFails(setDoc(doc(db, `restaurants/${RID}/payments/p2`), { amountMinor: 1 }));
      await assertFails(getDoc(doc(db, `restaurants/${RID}/subscriptionHistory/h1`)));
      await assertFails(getDoc(doc(db, "upgradeRequests/r1")));
      await assertFails(setDoc(doc(db, "upgradeRequests/r2"), { restaurantId: RID, status: "pending" }));
      await assertFails(setDoc(doc(db, "mail/m1"), { to: "x@example.com" }));
    }
  });
});
