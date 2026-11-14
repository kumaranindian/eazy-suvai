// M00 baseline: with deny-all rules, nobody can read or write anything from a
// client. Later modules replace these expectations path by path as they open
// access, and add a test file per collection.
import { after, before, beforeEach, describe, it } from "node:test";

import { assertFails } from "@firebase/rules-unit-testing";
import { collection, doc, getDoc, getDocs, setDoc } from "firebase/firestore";
import { getBytes, ref, uploadString } from "firebase/storage";

import { adminClaims, createEnv, ownerClaims } from "./helpers.js";

const RID = "rest_1";

// One document in every collection from architecture §4.
const SEED = {
  [`users/u1`]: { email: "owner@example.com", role: "owner", restaurantId: RID },
  [`restaurants/${RID}`]: { name: "Saravana Bhavan", status: "active", ownerUid: "u1" },
  [`restaurants/${RID}/categories/c1`]: { name: "Dosa", sequence: 1, active: true },
  [`restaurants/${RID}/items/i1`]: { name: "Masala dosa", priceMinor: 12900, categoryId: "c1" },
  [`restaurants/${RID}/versions/1`]: { n: 1 },
  [`restaurants/${RID}/live/availability`]: { items: { i1: true } },
  [`slugs/saravana-bhavan`]: { restaurantId: RID, current: true },
  [`qrCodes/abc123`]: { restaurantId: RID, kind: "restaurant" },
  [`plans/free`]: { name: "Free", isFree: true, active: true },
  [`config/platform`]: { graceDays: 14 },
  [`auditLogs/a1`]: { action: "restaurant.suspend" },
  [`analyticsEvents/e1`]: { type: "view" },
  [`stats/platform`]: { restaurants: 1 },
  [`upgradeRequests/r1`]: { restaurantId: RID, status: "pending" },
};

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
    for (const [path, data] of Object.entries(SEED)) {
      await setDoc(doc(db, path), data);
    }
  });
});

const callers = {
  "unauthenticated user": () => env.unauthenticatedContext(),
  "signed-in user with no claims": () => env.authenticatedContext("stranger"),
  "verified owner (until each module opens its paths)": () =>
    env.authenticatedContext("u1", ownerClaims(RID)),
  "platform admin (admins go through Functions)": () =>
    env.authenticatedContext("admin1", adminClaims),
};

describe("Firestore deny-all baseline", () => {
  for (const [who, context] of Object.entries(callers)) {
    describe(who, () => {
      it("cannot read any document", async () => {
        const db = context().firestore();
        for (const path of Object.keys(SEED)) {
          await assertFails(getDoc(doc(db, path)));
        }
      });

      it("cannot list any collection", async () => {
        const db = context().firestore();
        for (const name of [
          "users", "restaurants", "slugs", "qrCodes", "plans", "auditLogs",
          "analyticsEvents", "upgradeRequests", `restaurants/${RID}/items`,
        ]) {
          await assertFails(getDocs(collection(db, name)));
        }
      });

      it("cannot write any document", async () => {
        const db = context().firestore();
        for (const path of Object.keys(SEED)) {
          await assertFails(setDoc(doc(db, path), { hacked: true }, { merge: true }));
        }
        await assertFails(setDoc(doc(db, "restaurants/new"), { name: "x" }));
      });
    });
  }
});

describe("Storage deny-all baseline", () => {
  const path = `restaurants/${RID}/images/img1/original.png`;

  before(async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await uploadString(ref(ctx.storage(), path), "png-bytes");
    });
  });

  for (const [who, context] of Object.entries(callers)) {
    it(`${who} cannot read or upload images`, async () => {
      const storage = context().storage();
      await assertFails(getBytes(ref(storage, path)));
      await assertFails(uploadString(ref(storage, `restaurants/${RID}/images/img2/original.png`), "x"));
      await assertFails(uploadString(ref(storage, "anything/else.txt"), "x"));
    });
  }
});
