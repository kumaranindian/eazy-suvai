import { appErrorCodeOf } from "../lib/errors";
import { admin, passwordCaller, resetEmulators, validInput } from "../testing/emulator";
import { registerOwner } from "./register";

const { db, auth } = admin();
const deps = { db, auth };

let n = 0;
async function newUser(email = `owner${++n}@example.com`) {
  const user = await auth.createUser({ email, password: "Secret123!" });
  return passwordCaller(user.uid, email);
}

async function codeOf(p: Promise<unknown>): Promise<string | undefined> {
  try {
    await p;
  } catch (e) {
    return appErrorCodeOf(e) ?? String(e);
  }
  throw new Error("expected rejection");
}

beforeEach(resetEmulators);

describe("registerOwner on the emulators", () => {
  it("creates user, restaurant, slug, QR code, audit and claims (AC-001)", async () => {
    const caller = await newUser("Priya@Example.com");
    const r = await registerOwner(deps, caller, validInput);

    expect(r).toMatchObject({ slug: "spice-garden", created: true });
    expect(r.qrCode).toMatch(/^[23456789ABCDEFGHJKMNPQRSTUVWXYZ]{8}$/);

    const user = (await db.doc(`users/${caller.uid}`).get()).data();
    expect(user).toMatchObject({
      email: "priya@example.com",
      displayName: "Priya Raman",
      mobile: "+919876543210",
      role: "owner",
      restaurantId: r.restaurantId,
    });

    const rest = (await db.doc(`restaurants/${r.restaurantId}`).get()).data()!;
    expect(rest).toMatchObject({
      name: "Spice Garden",
      nameLower: "spice garden",
      ownerUid: caller.uid,
      ownerEmail: "priya@example.com",
      ownerMobile: "+919876543210",
      businessType: "restaurant",
      country: "IN",
      currency: "INR",
      timezone: "Asia/Kolkata",
      contact: { city: "Chennai" },
      slug: "spice-garden",
      qrCode: r.qrCode,
      status: "active",
      planId: "free",
      subscription: { status: "free", expiresAt: null, graceEndsAt: null },
      counts: { categories: 0, items: 0 },
      publishedVersion: null,
      pricesNeedReview: false,
    });
    expect(r.restaurantId).toMatch(/^[A-Za-z0-9]{20}$/);

    expect((await db.doc("slugs/spice-garden").get()).data()).toMatchObject({
      restaurantId: r.restaurantId,
      current: true,
    });
    expect((await db.doc(`qrCodes/${r.qrCode}`).get()).data()).toMatchObject({
      restaurantId: r.restaurantId,
      kind: "restaurant",
    });

    const audit = await db.collection("auditLogs").where("action", "==", "restaurant.register").get();
    expect(audit.size).toBe(1);
    expect(audit.docs[0].get("restaurantId")).toBe(r.restaurantId);

    const claims = (await auth.getUser(caller.uid)).customClaims;
    expect(claims).toEqual({ role: "owner", restaurantId: r.restaurantId });
  });

  it("is idempotent: a second call returns the same restaurant (FR-004, BR-017)", async () => {
    const caller = await newUser();
    const first = await registerOwner(deps, caller, validInput);
    const second = await registerOwner(deps, caller, { ...validInput, restaurantName: "Other Place" });
    expect(second).toEqual({ ...first, created: false });
    expect((await db.collection("restaurants").get()).size).toBe(1);
  });

  it("creates only one restaurant when two calls race", async () => {
    const caller = await newUser();
    const results = await Promise.all([
      registerOwner(deps, caller, validInput),
      registerOwner(deps, caller, validInput),
    ]);
    expect(results[0].restaurantId).toBe(results[1].restaurantId);
    expect((await db.collection("restaurants").get()).size).toBe(1);
    expect((await db.collection("slugs").get()).size).toBe(1);
  });

  it("re-applies lost claims on retry", async () => {
    const caller = await newUser();
    const r = await registerOwner(deps, caller, validInput);
    await auth.setCustomUserClaims(caller.uid, null);
    const again = await registerOwner(deps, caller, undefined);
    expect(again.restaurantId).toBe(r.restaurantId);
    expect((await auth.getUser(caller.uid)).customClaims).toEqual({ role: "owner", restaurantId: r.restaurantId });
  });

  it("suffixes the city, then a number, on collision (FR-092)", async () => {
    const slugs = [];
    for (let i = 0; i < 3; i++) {
      slugs.push((await registerOwner(deps, await newUser(), validInput)).slug);
    }
    const noCity = await registerOwner(deps, await newUser(), { ...validInput, city: undefined });
    expect(slugs).toEqual(["spice-garden", "spice-garden-chennai", "spice-garden-chennai-2"]);
    expect(noCity.slug).toBe("spice-garden-2");
  });

  it("treats old and released slugs as taken (FR-093)", async () => {
    await db.doc("slugs/spice-garden").set({ restaurantId: "gone", current: false, releasedAt: new Date() });
    const r = await registerOwner(deps, await newUser(), validInput);
    expect(r.slug).toBe("spice-garden-chennai");
  });

  it("skips reserved words from config/platform", async () => {
    await db.doc("config/platform").set({ reservedSlugs: ["spice-garden", "Menu"] });
    expect((await registerOwner(deps, await newUser(), validInput)).slug).toBe("spice-garden-chennai");
    expect((await registerOwner(deps, await newUser(), { ...validInput, restaurantName: "Menu" })).slug).toBe(
      "menu-chennai",
    );
  });

  it("uses the FR-092 defaults when config/platform is missing", async () => {
    const r = await registerOwner(deps, await newUser(), { ...validInput, restaurantName: "Admin", city: undefined });
    expect(r.slug).toBe("admin-2");
  });

  it("retries when the QR code is taken (BR-006)", async () => {
    await db.doc("qrCodes/22222222").set({ restaurantId: "other", kind: "restaurant" });
    let calls = 0;
    const random = (max: number) => (calls++ < 8 ? 0 : (calls * 7) % max);
    const r = await registerOwner({ ...deps, random }, await newUser(), validInput);
    expect(r.qrCode).not.toBe("22222222");
    expect((await db.doc("qrCodes/22222222").get()).get("restaurantId")).toBe("other");
  });

  it("sets currency and time zone from the country (FRD §6)", async () => {
    const r = await registerOwner(deps, await newUser(), {
      ...validInput,
      country: "KW",
      mobile: "+965 5123 4567",
    });
    const rest = (await db.doc(`restaurants/${r.restaurantId}`).get()).data()!;
    expect(rest).toMatchObject({ currency: "KWD", timezone: "Asia/Kuwait", ownerMobile: "+96551234567" });
  });

  it("rejects bad callers and input", async () => {
    const caller = await newUser();
    expect(await codeOf(registerOwner(deps, null, validInput))).toBe("unauthenticated");
    expect(await codeOf(registerOwner(deps, caller, undefined))).toBe("registration-incomplete");
    expect(await codeOf(registerOwner(deps, caller, {}))).toBe("registration-incomplete");
    expect(await codeOf(registerOwner(deps, caller, { ...validInput, mobile: "123" }))).toBe("invalid-input");
    const asAdmin = { ...caller, token: { ...caller.token, role: "platformAdmin" } };
    expect(await codeOf(registerOwner(deps, asAdmin, validInput))).toBe("permission-denied");
    const anonymous = { ...caller, token: { ...caller.token, firebase: { sign_in_provider: "anonymous" } } };
    expect(await codeOf(registerOwner(deps, anonymous, validInput))).toBe("permission-denied");
    expect((await db.collection("restaurants").get()).size).toBe(0);
  });
});
