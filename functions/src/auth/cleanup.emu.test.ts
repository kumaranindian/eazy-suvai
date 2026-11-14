import { admin, passwordCaller, resetEmulators, validInput } from "../testing/emulator";
import { cleanupUnverifiedUsers } from "./cleanup";
import { registerOwner } from "./register";

const { db, auth } = admin();
const DAY = 24 * 60 * 60 * 1000;

async function registered(email: string, verified = false) {
  const user = await auth.createUser({ email, password: "Secret123!", emailVerified: verified });
  const r = await registerOwner({ db, auth }, passwordCaller(user.uid, email), validInput);
  return { uid: user.uid, ...r };
}

beforeEach(resetEmulators);

describe("cleanupUnverifiedUsers (FR-091)", () => {
  it("deletes accounts unverified for 7 days with restaurant, slug and QR code", async () => {
    const stale = await registered("stale@example.com");
    const verified = await registered("verified@example.com", true);
    const orphan = await auth.createUser({ email: "orphan@example.com", password: "Secret123!" });
    const admin1 = await auth.createUser({ email: "admin@example.com", password: "Secret123!" });
    await auth.setCustomUserClaims(admin1.uid, { role: "platformAdmin" });
    await db.doc(`restaurants/${stale.restaurantId}/categories/c1`).set({ name: "x" });

    // Not yet 7 days: nothing happens.
    expect(await cleanupUnverifiedUsers({ db, auth, now: new Date(Date.now() + 6 * DAY) })).toEqual([]);

    const deleted = await cleanupUnverifiedUsers({ db, auth, now: new Date(Date.now() + 7 * DAY + 60_000) });
    expect(deleted.sort()).toEqual([stale.uid, orphan.uid].sort());

    await expect(auth.getUser(stale.uid)).rejects.toMatchObject({ code: "auth/user-not-found" });
    expect((await db.doc(`users/${stale.uid}`).get()).exists).toBe(false);
    expect((await db.doc(`restaurants/${stale.restaurantId}`).get()).exists).toBe(false);
    expect((await db.doc(`restaurants/${stale.restaurantId}/categories/c1`).get()).exists).toBe(false);
    expect((await db.doc(`slugs/${stale.slug}`).get()).exists).toBe(false);
    expect((await db.doc(`qrCodes/${stale.qrCode}`).get()).exists).toBe(false);

    // The verified owner and the admin are untouched.
    expect((await auth.getUser(verified.uid)).uid).toBe(verified.uid);
    expect((await db.doc(`restaurants/${verified.restaurantId}`).get()).exists).toBe(true);
    expect((await db.doc(`slugs/${verified.slug}`).get()).exists).toBe(true);
    expect((await auth.getUser(admin1.uid)).uid).toBe(admin1.uid);

    const audit = await db.collection("auditLogs").where("action", "==", "account.purgeUnverified").get();
    expect(audit.size).toBe(2);
    const entry = audit.docs.find((d) => d.get("restaurantId") === stale.restaurantId)!;
    expect(entry.get("details")).toMatchObject({ slugs: [stale.slug], qrCodes: [stale.qrCode] });
  });

  it("releases the email and slug for a new registration", async () => {
    const stale = await registered("again@example.com");
    await cleanupUnverifiedUsers({ db, auth, now: new Date(Date.now() + 8 * DAY) });
    const again = await registered("again@example.com");
    expect(again.slug).toBe(stale.slug);
  });
});
