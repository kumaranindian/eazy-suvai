// M13: the MVP journey end to end through the deployed-style entry points
// (Auth REST, callable HTTP endpoints on the Functions emulator, and the
// Hosting emulator for the public menu, the QR redirect and the beacon):
// sign-up → profile → menu → publish → scan → analytics → upgrade (offline
// payment) → downgrade (hidden, not deleted) → upgrade (restored) →
// suspension (503) → reactivation.
import { getAuth } from "firebase-admin/auth";

import {
  AUTH_HOST,
  FUNCTIONS_HOST,
  PROJECT_ID,
  admin,
  identityToolkit,
  resetEmulators,
} from "../testing/emulator";
import { DIETARY_LABELS, ITEM_TAGS } from "../menu/seed-data";
import { SEED_PLANS } from "../subscriptions/seed-plans";
import { SEED_THEMES } from "../theme";

const { db } = admin();
const HOSTING = "http://127.0.0.1:5000";
const UA = "Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Mobile Safari/537.36";

async function call(name: string, idToken: string, data: unknown): Promise<Record<string, unknown>> {
  const res = await fetch(`http://${FUNCTIONS_HOST}/${PROJECT_ID}/asia-south1/${name}`, {
    method: "POST",
    headers: { "content-type": "application/json", authorization: `Bearer ${idToken}` },
    body: JSON.stringify({ data }),
  });
  const json = (await res.json()) as { result?: Record<string, unknown>; error?: { details?: { code: string } } };
  if (json.error) throw Object.assign(new Error(`${name}: ${json.error.details?.code}`), { code: json.error.details?.code });
  return json.result ?? {};
}

async function codeOf(p: Promise<unknown>): Promise<string | undefined> {
  try {
    await p;
  } catch (e) {
    return (e as { code?: string }).code;
  }
  throw new Error("expected rejection");
}

async function signIn(email: string, password: string): Promise<string> {
  const r = await identityToolkit("signInWithPassword", { email, password, returnSecureToken: true });
  return r.json.idToken as string;
}

async function verifyEmail(email: string, idToken: string): Promise<void> {
  await identityToolkit("sendOobCode", { requestType: "VERIFY_EMAIL", idToken });
  const codes = (await (await fetch(`http://${AUTH_HOST}/emulator/v1/projects/${PROJECT_ID}/oobCodes`)).json()) as {
    oobCodes: { email: string; requestType: string; oobCode: string }[];
  };
  const code = codes.oobCodes.find((c) => c.email === email && c.requestType === "VERIFY_EMAIL")!;
  await identityToolkit("update", { oobCode: code.oobCode });
}

const waitFor = async <T>(read: () => Promise<T>, ok: (v: T) => boolean, ms = 20000): Promise<T> => {
  const end = Date.now() + ms;
  for (;;) {
    const v = await read();
    if (ok(v) || Date.now() > end) return v;
    await new Promise((r) => setTimeout(r, 250));
  }
};

beforeAll(async () => {
  await resetEmulators();
  const w: Promise<unknown>[] = [];
  for (const { id, ...d } of DIETARY_LABELS) w.push(db.doc(`dietaryLabels/${id}`).set(d));
  for (const { id, ...d } of ITEM_TAGS) w.push(db.doc(`itemTags/${id}`).set(d));
  for (const t of SEED_THEMES) w.push(db.doc(`themes/${t.id}`).set({ name: t.name, premium: t.premium, tokens: t.tokens }));
  for (const { id, ...p } of SEED_PLANS) w.push(db.doc(`plans/${id}`).set(p));
  w.push(db.doc("config/platform").set({ graceDays: 14, supportEmail: "help@eazysuvai.com" }));
  await Promise.all(w);
});

it("runs the MVP journey end to end", async () => {
  // 1. Sign-up, registration, verification (AC-001).
  const email = "journey@example.com";
  const password = "Secret123!";
  const up = await identityToolkit("signUp", { email, password, returnSecureToken: true });
  const reg = await call("completeRegistration", up.json.idToken as string, {
    restaurantName: "Journey Kitchen", ownerName: "Asha", mobile: "9876543210", country: "IN", businessType: "restaurant", city: "Chennai",
  });
  const rid = reg.restaurantId as string;
  const slug = reg.slug as string;
  const qrCode = reg.qrCode as string;
  await verifyEmail(email, up.json.idToken as string);
  let token = await signIn(email, password);

  // 2. Profile (direct write is the app's path; the rules are tested elsewhere).
  await db.doc(`restaurants/${rid}`).update({ description: "Tiffin and meals", themeId: "saffron", "contact.phone": "+914423456789" });

  // 3. Menu: 2 categories, 52 items (Free allows 50, AC-018).
  const starters = (await call("createCategory", token, { restaurantId: rid, name: "Starters" })).id as string;
  const mains = (await call("createCategory", token, { restaurantId: rid, name: "Mains" })).id as string;
  for (let i = 0; i < 50; i++) {
    await call("createItem", token, { restaurantId: rid, categoryId: i < 25 ? starters : mains, name: `Dish ${i}`, priceMinor: 10000 + i, dietaryLabelId: "vegetarian" });
  }
  expect(await codeOf(call("createItem", token, { restaurantId: rid, categoryId: mains, name: "One too many", priceMinor: 1, dietaryLabelId: "vegetarian" }))).toBe("limit-reached");

  // 4. Publish (AC-013) and scan (AC-011, AC-019).
  const pub = await call("publishMenu", token, { restaurantId: rid });
  expect(pub.version).toBe(1);
  // FRD §13: the first publish is stamped, once.
  const firstPublishedAt = (await db.doc(`restaurants/${rid}`).get()).get("firstPublishedAt");
  expect(firstPublishedAt).toBeTruthy();
  const qr = await fetch(`${HOSTING}/q/${qrCode.toLowerCase()}`, { redirect: "manual" });
  expect(qr.status).toBe(302);
  expect(qr.headers.get("location")).toBe(`/${slug}?src=qr`);
  const page = await fetch(`${HOSTING}/${slug}?src=qr`, { headers: { "user-agent": UA } });
  expect(page.status).toBe(200);
  const html = await page.text();
  expect(html).toContain("<h1>Journey Kitchen</h1>");
  expect(html).toContain("Dish 49");
  expect(html).toContain("application/ld+json");
  expect(html).toContain("data-beacon=\"/e\"");

  // 5. Analytics: a QR view and an item open through the beacon (AC-015).
  const beacon = (body: unknown) => fetch(`${HOSTING}/e`, { method: "POST", headers: { "content-type": "text/plain", "user-agent": UA }, body: JSON.stringify(body) });
  const firstItem = (await db.collection(`restaurants/${rid}/items`).orderBy("sequence").limit(1).get()).docs[0].id;
  expect((await beacon({ type: "view", slug, src: "qr" })).status).toBe(204);
  expect((await beacon({ type: "item", slug, src: "qr", id: firstItem })).status).toBe(204);
  const today = new Intl.DateTimeFormat("en-CA", { timeZone: "Asia/Kolkata" }).format(new Date());
  const daily = (await db.doc(`restaurants/${rid}/analyticsDaily/${today}`).get()).data();
  expect(daily).toMatchObject({ views: 1, qrVisits: 1, itemOpens: { [firstItem]: 1 } });
  const month = today.slice(0, 7);
  expect((await db.doc("stats/platform").get()).get(`monthly.${month}`)).toMatchObject({ views: 1, qrVisits: 1 });

  // 6. Upgrade through an offline payment recorded by an admin (AC-030).
  const adminEmail = "ops@example.com";
  const adminUser = await getAuth().createUser({ email: adminEmail, password, emailVerified: true });
  await getAuth().setCustomUserClaims(adminUser.uid, { role: "platformAdmin" });
  const adminToken = await signIn(adminEmail, password);
  await call("requestUpgrade", token, { restaurantId: rid, planId: "pro", billing: "annual" });
  const queue = await call("adminListUpgradeRequests", adminToken, {});
  expect((queue.requests as unknown[]).length).toBe(1);
  await call("recordPaymentAndActivate", adminToken, {
    restaurantId: rid, planId: "pro", billing: "annual", amountMinor: 999900, currency: "INR", method: "bank-transfer",
    reference: "NEFT-JOURNEY", paidAt: "2026-11-15", startAt: "2026-11-15", endAt: "2099-11-15",
  });
  await call("createItem", token, { restaurantId: rid, categoryId: mains, name: "Dish 50", priceMinor: 1, dietaryLabelId: "vegetarian" });
  await call("createItem", token, { restaurantId: rid, categoryId: mains, name: "Dish 51", priceMinor: 1, dietaryLabelId: "vegetarian" });
  await call("publishMenu", token, { restaurantId: rid });

  // 7. Downgrade: last items hidden, not deleted; the menu stays live (AC-025).
  await call("changeSubscription", adminToken, { action: "downgrade", restaurantId: rid, reason: "Journey test" });
  const items = await db.collection(`restaurants/${rid}/items`).get();
  expect(items.size).toBe(52);
  expect(items.docs.filter((d) => d.get("hiddenOverLimit") === true).map((d) => d.get("name")).sort()).toEqual(["Dish 50", "Dish 51"]);
  const afterDowngrade = await (await fetch(`${HOSTING}/${slug}`)).text();
  expect(afterDowngrade).not.toContain("Dish 51");
  expect(afterDowngrade).toContain("Dish 49");

  // 8. Upgrade again: hidden content back in the draft (AC-026).
  await call("recordPaymentAndActivate", adminToken, {
    restaurantId: rid, planId: "pro", billing: "monthly", amountMinor: 99900, currency: "INR", method: "upi",
    reference: "UPI-JOURNEY", paidAt: "2026-11-15", startAt: "2026-11-15", endAt: "2099-12-15",
  });
  const restored = await db.collection(`restaurants/${rid}/items`).where("hiddenOverLimit", "==", true).get();
  expect(restored.size).toBe(0);
  // FRD §13: two conversions (Free → Pro, and again after the downgrade to
  // Free); paying again while on Pro is a renewal.
  await call("recordPaymentAndActivate", adminToken, {
    restaurantId: rid, planId: "pro", billing: "monthly", amountMinor: 99900, currency: "INR", method: "upi",
    reference: "UPI-RENEW", paidAt: "2026-11-15", startAt: "2026-11-15", endAt: "2100-01-15",
  });
  const after2 = (await db.doc("stats/platform").get()).data()!;
  expect(after2).toMatchObject({ conversions: 2, renewals: 1 });
  expect((await db.doc(`restaurants/${rid}`).get()).get("firstPublishedAt")).toEqual(firstPublishedAt);

  // 9. Suspension: the menu answers 503 and the owner can't publish (AC-016, AC-024).
  await call("setRestaurantStatus", adminToken, { restaurantId: rid, status: "suspended", reason: "Journey test" });
  // The CDN cache doesn't exist on the emulator; the function answers directly.
  const suspended = await waitFor(() => fetch(`${HOSTING}/${slug}`), (r) => r.status === 503);
  expect(suspended.status).toBe(503);
  token = await signIn(email, password);
  expect(await codeOf(call("publishMenu", token, { restaurantId: rid }))).toBe("account-inactive");
  expect((await db.doc(`users/${(await getAuth().getUserByEmail(email)).uid}`).get()).get("accountStatus")).toBe("suspended");

  // 10. Reactivation: live again.
  await call("setRestaurantStatus", adminToken, { restaurantId: rid, status: "active", reason: "Paid" });
  expect((await fetch(`${HOSTING}/${slug}`)).status).toBe(200);

  // FRD §13 counters after the nightly recount.
  await call("recomputePlatformStats", adminToken, {});
  const st = await call("adminDashboard", adminToken, {});
  expect(st.stats).toMatchObject({ activated: 1, publishedMenus: 1, conversions: 2, renewals: 1 });
  expect((st.stats as { medianMinutesToFirstPublish: number }).medianMinutesToFirstPublish).toBeGreaterThanOrEqual(0);

  // Privacy policy and terms are static pages on the menu site (M13).
  for (const p of ["privacy", "terms"]) {
    const r = await fetch(`${HOSTING}/${p}`);
    expect(r.status).toBe(200);
    expect(await r.text()).toContain(p === "privacy" ? "<h1>Privacy policy</h1>" : "<h1>Terms of service</h1>");
  }
  expect(html).toContain("<a href=\"/privacy\">Privacy</a>");

  // Every admin action above is in the audit log (BR-014, AC-030).
  const actions = (await db.collection("auditLogs").where("restaurantId", "==", rid).get()).docs.map((d) => d.get("action"));
  expect(actions).toEqual(expect.arrayContaining([
    "restaurant.register", "menu.publish", "subscription.requestUpgrade", "subscription.activate",
    "subscription.downgrade", "subscription.applyLimits", "restaurant.suspend", "restaurant.activate",
  ]));
}, 180_000);
