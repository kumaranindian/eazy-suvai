import type { Timestamp } from "firebase-admin/firestore";

import { sampleSnapshot } from "../public/sample-menu";
import { admin, resetEmulators } from "../testing/emulator";
import { LiveMenuCache, RateLimiter, handleCollect, type CollectRequest } from "./collect";

const { db } = admin();
const UA = "Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Mobile Safari/537.36";
const HOSTING = "http://127.0.0.1:5000";
const RID = "rest_an";

// 23:50 in Chennai on 15 Nov (18:20 UTC); 10 minutes later is the 16th there.
const LATE = new Date("2026-11-15T18:20:00Z");
const AFTER_MIDNIGHT = new Date("2026-11-15T18:40:00Z");

const post = (body: unknown, extra: Partial<CollectRequest> = {}, now = LATE, limiter = new RateLimiter(1000, 60_000)) =>
  handleCollect(
    db,
    { method: "POST", body: typeof body === "string" ? body : JSON.stringify(body), userAgent: UA, ip: "203.0.113.9", ...extra },
    { now: () => now, limiter, cache: new LiveMenuCache() },
  );

const daily = async (day: string) => (await db.doc(`restaurants/${RID}/analyticsDaily/${day}`).get()).data();

beforeEach(async () => {
  await resetEmulators();
  await Promise.all([
    db.doc(`restaurants/${RID}`).set({ name: "Spice Garden", slug: "spice-garden", status: "active", timezone: "Asia/Kolkata", publishedVersion: 1 }),
    db.doc("slugs/spice-garden").set({ restaurantId: RID, current: true }),
    db.doc(`restaurants/${RID}/versions/1`).set({ n: 1, snapshot: sampleSnapshot() }),
    db.doc("restaurants/not_live").set({ name: "X", slug: "not-live", status: "active", timezone: "Asia/Kolkata", publishedVersion: null }),
    db.doc("slugs/not-live").set({ restaurantId: "not_live", current: true }),
    db.doc("restaurants/susp").set({ name: "S", slug: "paused", status: "suspended", timezone: "Asia/Kolkata", publishedVersion: 1 }),
    db.doc("slugs/paused").set({ restaurantId: "susp", current: true }),
  ]);
});

describe("collectEvent (FR-071 to FR-075)", () => {
  it("counts views, QR visits, category taps and item opens on the restaurant's day", async () => {
    expect(await post({ type: "view", slug: "spice-garden", src: "qr" })).toMatchObject({ counted: true, day: "2026-11-15" });
    await post({ type: "view", slug: "spice-garden", src: "direct" });
    await post({ type: "cat", slug: "spice-garden", src: "qr", id: "biryani" });
    await post({ type: "item", slug: "spice-garden", src: "qr", id: "tiffin-2" });
    await post({ type: "item", slug: "spice-garden", src: "qr", id: "tiffin-2" });
    // Ten minutes later it is the next day in India (not in UTC).
    expect(await post({ type: "view", slug: "spice-garden", src: "qr" }, {}, AFTER_MIDNIGHT)).toMatchObject({ day: "2026-11-16" });

    expect(await daily("2026-11-15")).toMatchObject({
      day: "2026-11-15",
      views: 2,
      qrVisits: 1,
      categoryTaps: { biryani: 1 },
      itemOpens: { "tiffin-2": 2 },
    });
    expect(await daily("2026-11-16")).toMatchObject({ views: 1, qrVisits: 1 });
    expect((await db.doc("stats/platform").get()).data()).toMatchObject({ menuViews: 3, qrVisits: 2 });
  });

  it("writes raw events with a 90-day expireAt and no IP, user agent or session", async () => {
    await post({ type: "item", slug: "spice-garden", src: "direct", id: "tiffin-1" });
    const events = await db.collection("analyticsEvents").get();
    expect(events.size).toBe(1);
    const e = events.docs[0].data();
    expect(Object.keys(e).sort()).toEqual(["at", "day", "expireAt", "id", "restaurantId", "src", "type"]);
    expect((e.expireAt as Timestamp).toMillis() - (e.at as Timestamp).toMillis()).toBe(90 * 86_400_000);
    const all = JSON.stringify([e, await daily("2026-11-15"), (await db.doc("stats/platform").get()).data()]);
    expect(all).not.toContain("203.0.113.9");
    expect(all).not.toContain("Android");
  });

  it("does not count bots, malformed bodies, unknown ids or menus that are not live", async () => {
    for (const ua of ["Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)", "WhatsApp/2.23.20.0", ""]) {
      expect(await post({ type: "view", slug: "spice-garden" }, { userAgent: ua })).toMatchObject({ counted: false, reason: "bot" });
    }
    expect(await post("{not json")).toMatchObject({ status: 400, counted: false });
    expect(await post({ type: "view", slug: "spice-garden", sid: "abc" })).toMatchObject({ status: 400 });
    expect(await post({ type: "cat", slug: "spice-garden", id: "invented" })).toMatchObject({ counted: false, reason: "unknown-id" });
    expect(await post({ type: "view", slug: "not-live" })).toMatchObject({ status: 404 });
    expect(await post({ type: "view", slug: "paused" })).toMatchObject({ status: 404 });
    expect(await post({ type: "view", slug: "nobody" })).toMatchObject({ status: 404 });
    expect(await post({ type: "view", slug: "spice-garden" }, { method: "GET" })).toMatchObject({ status: 405 });
    expect(await daily("2026-11-15")).toBeUndefined();
    expect((await db.collection("analyticsEvents").get()).size).toBe(0);
  });

  it("rate-limits one address", async () => {
    const limiter = new RateLimiter(2, 60_000);
    const results = [];
    for (let i = 0; i < 3; i++) results.push(await post({ type: "view", slug: "spice-garden" }, {}, LATE, limiter));
    expect(results.map((r) => r.status)).toEqual([204, 204, 429]);
    expect(await daily("2026-11-15")).toMatchObject({ views: 2 });
  });
});

describe("through Hosting (/e rewrite)", () => {
  it("routes POST /e to collectEvent and counts a beacon body", async () => {
    const res = await fetch(`${HOSTING}/e`, {
      method: "POST",
      headers: { "content-type": "text/plain;charset=UTF-8", "user-agent": UA },
      body: JSON.stringify({ type: "view", slug: "spice-garden", src: "qr" }),
    });
    expect(res.status).toBe(204);
    expect(res.headers.get("cache-control")).toBe("no-store");
    const today = new Intl.DateTimeFormat("en-CA", { timeZone: "Asia/Kolkata" }).format(new Date());
    expect(await daily(today)).toMatchObject({ views: 1, qrVisits: 1 });
    // The menu page now carries the beacon attribute.
    const page = await (await fetch(`${HOSTING}/spice-garden`)).text();
    expect(page).toContain("data-beacon=\"/e\"");
    expect(page).toContain("data-slug=\"spice-garden\"");
  });
});
