// M05: themes, the font list and the restaurant's theme draft fields
// (FR-055 to FR-059, BR-012, AC-017).
import { after, before, beforeEach, describe, it } from "node:test";

import { assertFails, assertSucceeds } from "@firebase/rules-unit-testing";
import { collection, doc, getDoc, getDocs, serverTimestamp, setDoc, updateDoc } from "firebase/firestore";

import { adminClaims, createEnv, mfaAdminClaims, ownerClaims } from "./helpers.js";

const RID = "rest_1";
const OTHER = "rest_2";

const restaurant = (ownerUid, extra = {}) => ({
  name: "Spice Garden",
  ownerUid,
  status: "active",
  themeId: null,
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
    await setDoc(doc(db, `restaurants/${OTHER}`), restaurant("u2", { themeId: "minimal" }));
    await setDoc(doc(db, "themes/saffron"), { name: "Saffron", premium: false, tokens: { primary: "#A8550A" } });
    await setDoc(doc(db, "themes/minimal"), { name: "Minimal", premium: false, tokens: { primary: "#222222" } });
    await setDoc(doc(db, "config/platform"), { fonts: ["Poppins", "Inter"], graceDays: 14 });
  });
});

const owner = (uid = "u1", rid = RID, extra = {}) =>
  env.authenticatedContext(uid, { ...ownerClaims(rid), ...extra }).firestore();
const ref = (db, rid = RID) => doc(db, `restaurants/${rid}`);
const draft = (fields) => ({ ...fields, draftUpdatedAt: serverTimestamp() });

describe("themes and config/platform (FR-056, FR-059)", () => {
  it("verified owners and MFA admins can read themes and the font list", async () => {
    for (const db of [owner(), env.authenticatedContext("admin1", mfaAdminClaims).firestore()]) {
      await assertSucceeds(getDoc(doc(db, "themes/saffron")));
      await assertSucceeds(getDocs(collection(db, "themes")));
      await assertSucceeds(getDoc(doc(db, "config/platform")));
    }
  });

  it("unverified users, strangers and admins without MFA cannot", async () => {
    for (const db of [
      owner("u1", RID, { email_verified: false }),
      env.authenticatedContext("stranger").firestore(),
      env.unauthenticatedContext().firestore(),
      env.authenticatedContext("admin1", adminClaims).firestore(),
    ]) {
      await assertFails(getDoc(doc(db, "themes/saffron")));
      await assertFails(getDoc(doc(db, "config/platform")));
    }
  });

  it("nobody writes themes or config from a client (Functions only)", async () => {
    for (const db of [owner(), env.authenticatedContext("admin1", mfaAdminClaims).firestore()]) {
      await assertFails(setDoc(doc(db, "themes/mine"), { name: "Mine" }));
      await assertFails(updateDoc(doc(db, "themes/saffron"), { premium: true }));
      await assertFails(updateDoc(doc(db, "config/platform"), { fonts: ["Comic Sans"] }));
    }
  });
});

describe("restaurant theme draft (FR-055, FR-058)", () => {
  it("an owner can choose an existing theme and set every override", async () => {
    await assertSucceeds(
      updateDoc(
        ref(owner()),
        draft({
          themeId: "saffron",
          themeSettings: {
            primary: "#112233",
            secondary: "#AABBCC",
            background: "#FFFFFF",
            font: "Noto Sans",
            layout: "grid",
            cardLayout: "image-top",
            mode: "dark",
          },
        }),
      ),
    );
    await assertSucceeds(updateDoc(ref(owner()), draft({ themeSettings: {} })));
    await assertSucceeds(updateDoc(ref(owner()), draft({ themeSettings: { mode: "light" } })));
    await assertSucceeds(updateDoc(ref(owner()), draft({ themeSettings: null, themeId: null })));
  });

  it("the theme must exist", async () => {
    await assertFails(updateDoc(ref(owner()), draft({ themeId: "nope" })));
    await assertFails(updateDoc(ref(owner()), draft({ themeId: "../users/u1" })));
    await assertFails(updateDoc(ref(owner()), draft({ themeId: 42 })));
  });

  const bad = {
    "lower-case hex": { primary: "#aabbcc" },
    "short hex": { primary: "#ABC" },
    "named colour": { background: "red" },
    "colour as a number": { secondary: 0xffffff },
    "unknown layout": { layout: "masonry" },
    "unknown card layout": { cardLayout: "huge" },
    "unknown mode": { mode: "sepia" },
    "font with symbols": { font: "<script>" },
    "font too long": { font: "A".repeat(41) },
    "extra key": { text: "#000000" },
    "nested map": { primary: { r: 1 } },
  };
  for (const [name, settings] of Object.entries(bad)) {
    it(`rejects themeSettings with ${name}`, async () => {
      await assertFails(updateDoc(ref(owner()), draft({ themeSettings: settings })));
    });
  }

  it("themeSettings must be a map", async () => {
    await assertFails(updateDoc(ref(owner()), draft({ themeSettings: "dark" })));
  });

  it("a theme change must stamp draftUpdatedAt (FR-012)", async () => {
    await assertFails(updateDoc(ref(owner()), { themeId: "saffron" }));
  });

  it("one restaurant's theme never changes another's (BR-012, AC-017)", async () => {
    await assertFails(updateDoc(ref(owner(), OTHER), draft({ themeId: "saffron" })));
    await assertFails(updateDoc(ref(owner(), OTHER), draft({ themeSettings: { mode: "dark" } })));
    await assertFails(updateDoc(ref(owner("u2", OTHER), RID), draft({ themeSettings: { primary: "#000000" } })));
    // The owner's own change leaves the other restaurant untouched.
    await assertSucceeds(updateDoc(ref(owner()), draft({ themeId: "saffron", themeSettings: { mode: "dark" } })));
    await env.withSecurityRulesDisabled(async (ctx) => {
      const other = (await getDoc(doc(ctx.firestore(), `restaurants/${OTHER}`))).data();
      if (other.themeId !== "minimal" || other.themeSettings !== undefined) {
        throw new Error(`The other restaurant changed: ${JSON.stringify(other)}`);
      }
    });
  });

  it("the owner of a suspended restaurant cannot change the theme (FR-010)", async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), "restaurants/susp"), restaurant("u3", { status: "suspended" }));
    });
    await assertFails(updateDoc(ref(owner("u3", "susp"), "susp"), draft({ themeId: "saffron" })));
  });
});
