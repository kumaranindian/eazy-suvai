// Baseline: nobody can read or write anything from a client except the paths
// a module has opened (listed in OPENED below and tested in their own file).
// Later modules add their paths to OPENED and a test file per collection.
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
  [`restaurants/${RID}/versions/1/private/source`]: { items: [] },
  [`restaurants/${RID}/live/availability`]: { items: { i1: true } },
  [`slugs/saravana-bhavan`]: { restaurantId: RID, current: true },
  [`qrCodes/abc123`]: { restaurantId: RID, kind: "restaurant" },
  [`plans/free`]: { name: "Free", isFree: true, active: true },
  [`config/platform`]: { graceDays: 14 },
  [`auditLogs/a1`]: { action: "restaurant.suspend" },
  [`analyticsEvents/e1`]: { type: "view" },
  [`stats/platform`]: { restaurants: 1 },
  [`upgradeRequests/r1`]: { restaurantId: RID, status: "pending" },
  [`dietaryLabels/vegetarian`]: { name: "Vegetarian" },
  [`itemTags/spicy`]: { name: "Spicy" },
  [`themes/saffron`]: { name: "Saffron", premium: false },
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
  "verified owner": () => env.authenticatedContext("u1", ownerClaims(RID)),
  "platform admin without MFA": () => env.authenticatedContext("admin1", adminClaims),
};

// Paths each caller may read, opened by a module (M01: accounts.test.js,
// M03: restaurant-profile.test.js, M04: menu.test.js, M05: theme.test.js,
// M06: publishing.test.js).
// Everything else stays denied.
const OPENED = {
  "verified owner": [
    "users/u1",
    `restaurants/${RID}`,
    `restaurants/${RID}/categories/c1`,
    `restaurants/${RID}/items/i1`,
    `restaurants/${RID}/versions/1`,
    "dietaryLabels/vegetarian",
    "itemTags/spicy",
    "themes/saffron",
    "config/platform",
  ],
};

// Collections each caller may list (M04: menu.test.js, M05: theme.test.js,
// M06: publishing.test.js).
const OPENED_LISTS = {
  "verified owner": [`restaurants/${RID}/items`, `restaurants/${RID}/versions`, "dietaryLabels", "itemTags", "themes"],
};

describe("Firestore deny-all baseline", () => {
  for (const [who, context] of Object.entries(callers)) {
    describe(who, () => {
      it("cannot read any document", async () => {
        const db = context().firestore();
        for (const path of Object.keys(SEED)) {
          if (OPENED[who]?.includes(path)) continue;
          await assertFails(getDoc(doc(db, path)));
        }
      });

      it("cannot list any collection", async () => {
        const db = context().firestore();
        for (const name of [
          "users", "restaurants", "slugs", "qrCodes", "plans", "auditLogs",
          "analyticsEvents", "upgradeRequests", `restaurants/${RID}/items`,
          "dietaryLabels", "itemTags", "themes", "config", `restaurants/${RID}/versions`,
          `restaurants/${RID}/versions/1/private`,
        ]) {
          if (OPENED_LISTS[who]?.includes(name)) continue;
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

// M02 opened restaurants/{rid}/images/** for its owner (storage.test.js).
// Everyone else still reaches nothing, and nobody reaches any other path.
describe("Storage deny-all baseline", () => {
  const path = `restaurants/${RID}/images/img1abcdefghijklmnop/original.png`;

  before(async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await uploadString(ref(ctx.storage(), path), "png-bytes");
      await uploadString(ref(ctx.storage(), "anything/else.txt"), "x");
    });
  });

  for (const [who, context] of Object.entries(callers)) {
    it(`${who} cannot read or write outside restaurant images`, async () => {
      const storage = context().storage();
      await assertFails(getBytes(ref(storage, "anything/else.txt")));
      await assertFails(uploadString(ref(storage, "anything/else.txt"), "x"));
      await assertFails(uploadString(ref(storage, `restaurants/${RID}/logo.png`), "x"));
      await assertFails(uploadString(ref(storage, `users/u1/avatar.png`), "x"));
    });

    if (who === "verified owner") continue;
    it(`${who} cannot read or upload restaurant images`, async () => {
      const storage = context().storage();
      await assertFails(getBytes(ref(storage, path)));
      await assertFails(
        uploadString(ref(storage, `restaurants/${RID}/images/img2abcdefghijklmnop/original.png`), "x", "raw", {
          contentType: "image/png",
          customMetadata: { purpose: "logo", targetPath: `restaurants/${RID}`, field: "logo" },
        }),
      );
    });
  }
});
