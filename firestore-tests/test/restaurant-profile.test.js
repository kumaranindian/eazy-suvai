// M03: owner updates of restaurants/{rid} – the profile field whitelist
// (architecture §5, FR-011 to FR-013, BR-005, BR-011, AC-002, AC-017).
import { after, before, beforeEach, describe, it } from "node:test";

import { assertFails, assertSucceeds } from "@firebase/rules-unit-testing";
import { deleteDoc, deleteField, doc, serverTimestamp, setDoc, Timestamp, updateDoc } from "firebase/firestore";

import { adminClaims, createEnv, mfaAdminClaims, ownerClaims } from "./helpers.js";

const RID = "rest_1";
const OTHER = "rest_2";

const LOGO = {
  path: `restaurants/${RID}/images/abcdefghijklmnop0001/original.png`,
  status: "ready",
  renditions: { w320: "x" },
};

const restaurant = (ownerUid, extra = {}) => ({
  name: "Spice Garden",
  nameLower: "spice garden",
  ownerUid,
  ownerName: "Priya",
  ownerEmail: "priya@example.com",
  ownerMobile: "+919876543210",
  businessType: "restaurant",
  country: "IN",
  currency: "INR",
  timezone: "Asia/Kolkata",
  contact: { city: "Chennai" },
  slug: "spice-garden",
  qrCode: "ABCDEFGH",
  status: "active",
  planId: "free",
  subscription: { status: "free", expiresAt: null, graceEndsAt: null },
  counts: { categories: 0, items: 0 },
  publishedVersion: null,
  pricesNeedReview: false,
  themeId: null,
  logo: LOGO,
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
    await setDoc(doc(db, `restaurants/${OTHER}`), restaurant("u2", { slug: "other" }));
    await setDoc(doc(db, "restaurants/susp"), restaurant("u3", { status: "suspended" }));
    await setDoc(doc(db, "themes/saffron"), { name: "Saffron", premium: false });
  });
});

const owner = (uid = "u1", rid = RID, extra = {}) =>
  env.authenticatedContext(uid, { ...ownerClaims(rid), ...extra }).firestore();

const ref = (db, rid = RID) => doc(db, `restaurants/${rid}`);

/** A draft update as the app sends it. */
const draft = (fields) => ({ ...fields, draftUpdatedAt: serverTimestamp() });

const FULL_PROFILE = {
  name: "Spice Garden Café",
  businessType: "cafe",
  description: "South Indian breakfast and filter coffee since 1998.",
  contact: {
    phone: "+914423456789",
    email: "hello@spicegarden.in",
    address: "12 Anna Salai, T. Nagar",
    city: "Chennai",
    postalCode: "600017",
    website: "https://spicegarden.in/menu",
    social: {
      instagram: "https://instagram.com/spicegarden",
      facebook: "https://www.facebook.com/spicegarden",
      x: "https://x.com/spicegarden",
      youtube: "https://youtube.com/@spicegarden",
      googleMaps: "https://maps.app.goo.gl/abc123",
    },
  },
  openingHours: {
    mon: "07:00-11:00,12:00-15:00,18:00-23:30",
    tue: "07:00-22:00",
    wed: "",
    thu: "18:00-02:00",
    fri: "07:00-22:00",
    sat: "07:00-22:00",
    sun: "",
  },
  visibility: { phone: true, email: false, address: true, hours: true, social: false, unavailableItems: false },
  currency: "AED",
  timezone: "Asia/Dubai",
};

describe("owner profile updates (AC-002)", () => {
  it("an owner can write the full FR-011 profile in one update", async () => {
    await assertSucceeds(updateDoc(ref(owner()), draft(FULL_PROFILE)));
  });

  it("each whitelisted field can be updated on its own", async () => {
    for (const [key, value] of Object.entries(FULL_PROFILE)) {
      await assertSucceeds(updateDoc(ref(owner()), draft({ [key]: value })));
    }
    await assertSucceeds(updateDoc(ref(owner()), draft({ themeId: "saffron", themeSettings: { mode: "light" } })));
  });

  it("visibility toggles are stored as booleans (FR-013)", async () => {
    await assertSucceeds(updateDoc(ref(owner()), draft({ visibility: { phone: false } })));
    await assertFails(updateDoc(ref(owner()), draft({ visibility: { phone: "no" } })));
    await assertFails(updateDoc(ref(owner()), draft({ visibility: { menu: false } })));
    // FR-043: show or hide unavailable items.
    await assertSucceeds(updateDoc(ref(owner()), draft({ visibility: { unavailableItems: false } })));
    await assertFails(updateDoc(ref(owner()), draft({ visibility: { unavailableItems: "no" } })));
  });

  it("an owner can remove the logo or cover, but never set an image object (M02)", async () => {
    await assertSucceeds(updateDoc(ref(owner()), draft({ logo: null })));
    await assertSucceeds(updateDoc(ref(owner()), draft({ cover: null })));
    await assertFails(updateDoc(ref(owner()), draft({ logo: { ...LOGO, path: "elsewhere/x.png" } })));
    await assertFails(updateDoc(ref(owner()), draft({ cover: { status: "ready", path: "x" } })));
  });

  it("a draft change must stamp draftUpdatedAt with the server time (FR-012)", async () => {
    await assertFails(updateDoc(ref(owner()), { description: "No stamp" }));
    await assertFails(updateDoc(ref(owner()), { description: "Old stamp", draftUpdatedAt: Timestamp.fromMillis(0) }));
    await assertFails(updateDoc(ref(owner()), { draftUpdatedAt: Timestamp.fromMillis(0) }));
  });

  it("finishing the setup wizard stamps setupCompletedAt with the server time", async () => {
    await assertSucceeds(updateDoc(ref(owner()), { setupCompletedAt: serverTimestamp() }));
    await assertFails(updateDoc(ref(owner()), { setupCompletedAt: Timestamp.fromMillis(0) }));
  });
});

describe("fields owners cannot change (BR-011)", () => {
  const forbidden = {
    status: "deactivated",
    planId: "pro",
    slug: "stolen-slug",
    counts: { categories: 999, items: 999 },
    qrCode: "ZZZZZZZZ",
    publishedVersion: 7,
    pricesNeedReview: true,
    nameLower: "something else",
    ownerUid: "u9",
    ownerEmail: "evil@example.com",
    ownerName: "Someone",
    ownerMobile: "+919999999999",
    country: "AE",
    subscription: { status: "active" },
    createdAt: Timestamp.fromMillis(0),
    hacked: true,
  };

  for (const [key, value] of Object.entries(forbidden)) {
    it(`${key}`, async () => {
      await assertFails(updateDoc(ref(owner()), draft({ [key]: value })));
      // Not even hidden inside an otherwise valid update.
      await assertFails(updateDoc(ref(owner()), draft({ description: "ok", [key]: value })));
    });
  }

  it("counts and nested system fields cannot be changed with a field path", async () => {
    await assertFails(updateDoc(ref(owner()), { "counts.items": 5, draftUpdatedAt: serverTimestamp() }));
    await assertFails(updateDoc(ref(owner()), { "subscription.status": "active" }));
  });

  it("system fields cannot be deleted", async () => {
    await assertFails(updateDoc(ref(owner()), { publishedVersion: deleteField() }));
    await assertFails(updateDoc(ref(owner()), { qrCode: deleteField() }));
  });

  it("owners cannot create or delete restaurants", async () => {
    await assertFails(setDoc(doc(owner(), "restaurants/new"), restaurant("u1")));
    await assertFails(deleteDoc(ref(owner())));
  });
});

describe("value checks", () => {
  const bad = {
    "an empty name": { name: "" },
    "a blank name": { name: "   " },
    "a name over 80 characters": { name: "x".repeat(81) },
    "a number as name": { name: 42 },
    "an unknown business type": { businessType: "casino" },
    "a description over 500 characters": { description: "x".repeat(501) },
    "a phone not in E.164": { contact: { phone: "98765 43210" } },
    "a bad email": { contact: { email: "not-an-email" } },
    "an http website": { contact: { website: "http://spicegarden.in" } },
    "a javascript: website": { contact: { website: "javascript:alert(1)" } },
    "an unknown contact key": { contact: { fax: "123" } },
    "an http social link": { contact: { social: { instagram: "http://instagram.com/x" } } },
    "an unknown social network": { contact: { social: { tiktok: "https://tiktok.com/@x" } } },
    "a long address": { contact: { address: "x".repeat(201) } },
    "a bad postal code": { contact: { postalCode: "<script>" } },
    "four slots in a day": { openingHours: { mon: "01:00-02:00,03:00-04:00,05:00-06:00,07:00-08:00" } },
    "a slot list instead of a string": { openingHours: { mon: [{ open: "09:00", close: "10:00" }] } },
    "minutes instead of a string": { openingHours: { mon: 540 } },
    "a bad time": { openingHours: { mon: "9am-10:00" } },
    "24:00": { openingHours: { mon: "09:00-24:00" } },
    "a missing close": { openingHours: { mon: "09:00" } },
    "a trailing comma": { openingHours: { mon: "09:00-10:00," } },
    "a separator smuggled into a day": { openingHours: { mon: "09:00-10:00;10:00-11:00" } },
    "free text": { openingHours: { mon: "closed" } },
    "an unknown weekday": { openingHours: { holiday: [] } },
    "a lowercase currency": { currency: "inr" },
    "a long currency": { currency: "RUPEE" },
    "a bad time zone": { timezone: "Kolkata time" },
    "a non-map contact": { contact: "Chennai" },
    "a number as phone": { contact: { phone: 919876543210 } },
    "a separator smuggled into the email": { contact: { email: "a@b.co|+911234567" } },
    "a separator smuggled into a social link": {
      contact: { social: { instagram: "https://instagram.com/a|https://evil.example" } },
    },
    "a social link list": { contact: { social: { x: ["https://x.com/a"] } } },
    "a number as city": { contact: { city: 600017 } },
  };

  for (const [what, fields] of Object.entries(bad)) {
    it(`refuses ${what}`, async () => {
      await assertFails(updateDoc(ref(owner()), draft(fields)));
    });
  }

  it("accepts edge values", async () => {
    await assertSucceeds(updateDoc(ref(owner()), draft({ name: "x".repeat(80), description: "" })));
    await assertSucceeds(updateDoc(ref(owner()), draft({ contact: {} })));
    await assertSucceeds(updateDoc(ref(owner()), draft({ timezone: "America/Argentina/Buenos_Aires" })));
    await assertSucceeds(updateDoc(ref(owner()), draft({ timezone: "UTC" })));
    await assertSucceeds(
      updateDoc(ref(owner()), draft({ openingHours: { sun: "00:00-00:00", mon: "" } })),
    );
    await assertSucceeds(
      updateDoc(ref(owner()), draft({ contact: { postalCode: "SW1A 1AA", phone: "+12125550123" } })),
    );
    // Removing the opening hours altogether.
    await assertSucceeds(updateDoc(ref(owner()), draft({ openingHours: null })));
  });

  it("the heaviest update fits the rules budget: every field, 3 slots on all 7 days", async () => {
    const week = Object.fromEntries(
      ["mon", "tue", "wed", "thu", "fri", "sat", "sun"].map((d) => [d, FULL_PROFILE.openingHours.mon]),
    );
    await assertSucceeds(
      updateDoc(
        ref(owner()),
        draft({
          ...FULL_PROFILE,
          openingHours: week,
          logo: null,
          cover: null,
          themeId: "saffron",
          // Every theme override at its longest (M05).
          themeSettings: {
            primary: "#A8550A",
            secondary: "#3B7A20",
            background: "#FFF8EE",
            font: "Playfair Display",
            layout: "grid",
            cardLayout: "image-left",
            mode: "dark",
          },
          setupCompletedAt: serverTimestamp(),
        }),
      ),
    );
  });
});

describe("who can update", () => {
  it("another tenant's owner cannot (AC-017)", async () => {
    await assertFails(updateDoc(ref(owner(), OTHER), draft({ description: "mine now" })));
    await assertFails(updateDoc(ref(owner("u2", OTHER), RID), draft({ description: "mine now" })));
  });

  it("an unverified owner cannot (FR-091)", async () => {
    await assertFails(updateDoc(ref(owner("u1", RID, { email_verified: false })), draft({ description: "x" })));
  });

  it("the owner of a suspended restaurant cannot (FR-010)", async () => {
    await assertFails(updateDoc(ref(owner("u3", "susp"), "susp"), draft({ description: "x" })));
  });

  it("a signed-out user cannot", async () => {
    await assertFails(updateDoc(ref(env.unauthenticatedContext().firestore()), draft({ description: "x" })));
  });

  it("admins do not write directly, with or without MFA (Functions only)", async () => {
    for (const claims of [mfaAdminClaims, adminClaims]) {
      const db = env.authenticatedContext("admin1", claims).firestore();
      await assertFails(updateDoc(ref(db), draft({ description: "x" })));
      await assertFails(updateDoc(ref(db), { status: "suspended" }));
    }
  });
});
