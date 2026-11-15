import { Timestamp } from "firebase-admin/firestore";

import { createCategory, createItem } from "../menu/menu-callables";
import { DIETARY_LABELS, ITEM_TAGS } from "../menu/seed-data";
import { publishMenu } from "../publishing/publish";
import { admin, resetEmulators } from "../testing/emulator";
import { SEED_THEMES } from "../theme";
import { loadMenu, resolveQr, sitemapEntries } from "./loader";
import { sampleSnapshot } from "./sample-menu";
import { CACHE_PUBLIC, handleMenuRequest, type MenuResponse } from "./serve";

const { db } = admin();
const BASE = "https://menu.eazysuvai.com";
const HOSTING = "http://127.0.0.1:5000";

let run = 0;

const get = (path: string, headers: Record<string, string> = {}): Promise<MenuResponse> => {
  const q = path.indexOf("?");
  return handleMenuRequest(
    db,
    { method: "GET", path: q >= 0 ? path.slice(0, q) : path, query: q >= 0 ? path.slice(q) : "", headers },
    { baseUrl: BASE },
  );
};

async function waitFor<T>(read: () => Promise<T>, done: (v: T) => boolean, timeoutMs = 20000): Promise<T> {
  const end = Date.now() + timeoutMs;
  for (;;) {
    const v = await read();
    if (done(v)) return v;
    if (Date.now() > end) throw new Error(`timed out; last value ${JSON.stringify(v)}`);
    await new Promise((r) => setTimeout(r, 200));
  }
}

/** A restaurant with slug, QR code and (optionally) a published version written directly. */
async function restaurant(slug: string, fields: Record<string, unknown>, code: string, published = true): Promise<string> {
  const rid = `rest_pm_${++run}`;
  const s = sampleSnapshot();
  s.profile.name = fields.name as string ?? s.profile.name;
  await Promise.all([
    db.doc(`restaurants/${rid}`).set({
      name: s.profile.name,
      slug,
      qrCode: code,
      status: "active",
      planId: "free",
      publishedVersion: published ? 2 : null,
      publishedAt: published ? Timestamp.fromDate(new Date("2026-11-15T10:00:00Z")) : null,
      ...fields,
    }),
    db.doc(`slugs/${slug}`).set({ restaurantId: rid, current: true, createdAt: Timestamp.now() }),
    db.doc(`qrCodes/${code}`).set({ restaurantId: rid, kind: "restaurant", createdAt: Timestamp.now() }),
    ...(published
      ? [
        db.doc(`restaurants/${rid}/versions/2`).set({ n: 2, kind: "publish", publishedAt: Timestamp.now(), snapshot: s }),
        // An older version that must never be served.
        db.doc(`restaurants/${rid}/versions/1`).set({ n: 1, kind: "publish", publishedAt: Timestamp.now(), snapshot: { ...s, profile: { ...s.profile, name: "OLD VERSION" } } }),
        db.doc(`restaurants/${rid}/live/availability`).set({ items: { "tiffin-1": false }, updatedAt: Timestamp.now() }),
      ]
      : []),
  ]);
  return rid;
}

beforeEach(async () => {
  await resetEmulators();
});

describe("loader and states (FR-099, AC-024)", () => {
  it("serves an active, published menu with the live availability overlay", async () => {
    await restaurant("spice-garden", {}, "AB3K7MNP");
    const res = await get("/spice-garden");
    expect(res.status).toBe(200);
    expect(res.headers["Cache-Control"]).toBe(CACHE_PUBLIC);
    expect(res.headers["Content-Type"]).toBe("text/html; charset=utf-8");
    expect(res.headers.ETag).toBeDefined();
    expect(res.body).toContain("<h1>Spice Garden</h1>");
    expect(res.body).not.toContain("OLD VERSION");
    expect(res.body).toContain(`<link rel="canonical" href="${BASE}/spice-garden">`);
    // tiffin-1 from the overlay, biryani-2 from the snapshot.
    expect(res.body.match(/<li class="item sold-out/g)).toHaveLength(2);
    expect(res.body).toContain("Powered by EazySuvai");
    expect(res.body).not.toContain("noindex");

    const again = await get("/spice-garden", { "if-none-match": res.headers.ETag });
    expect(again.status).toBe(304);
  });

  it("serves the grace period as live and hides branding on Pro", async () => {
    await restaurant("pro-place", { planId: "pro", subscription: { status: "grace" } }, "AB3K7MNQ");
    const res = await get("/pro-place");
    expect(res.status).toBe(200);
    expect(res.body).not.toContain("Powered by EazySuvai");
    await db.doc("plans/free").set({ limits: { removeBranding: true } });
    await restaurant("free-place", {}, "AB3K7MNR");
    expect((await get("/free-place")).body).not.toContain("Powered by EazySuvai");
  });

  it.each([
    ["never published", { status: "active" }, false, 404, "Menu coming soon", true],
    ["suspended", { status: "suspended" }, true, 503, "Menu temporarily unavailable", true],
    ["deactivated", { status: "deactivated" }, true, 410, "Menu no longer available", false],
    ["deleted", { status: "deleted" }, true, 410, "Menu no longer available", false],
  ])("%s → %s", async (_label, fields, published, status, text, showsName) => {
    await restaurant("state-place", { name: "Dosa Corner", ...fields }, "AB3K7MNS", published as boolean);
    const res = await get("/state-place");
    expect(res.status).toBe(status);
    expect(res.body).toContain(text);
    expect(res.body).toContain("noindex");
    expect(res.headers["X-Robots-Tag"]).toBe("noindex");
    expect(res.body.includes("Dosa Corner")).toBe(showsName);
    expect(res.body).not.toContain("₹");
    if (status === 503) expect(res.headers["Retry-After"]).toBe("3600");
  });

  it("answers 410 for a held slug whose restaurant is gone, 404 for an unknown slug", async () => {
    await db.doc("slugs/held-slug").set({ restaurantId: "gone_rid", current: true });
    expect((await get("/held-slug")).status).toBe(410);
    const nf = await get("/no-such-menu");
    expect(nf.status).toBe(404);
    expect(nf.body).toContain("Menu not found");
    expect(nf.body).toContain("noindex");
  });

  it("redirects an old slug with 301 to the current one, keeping the query (AC-023)", async () => {
    const rid = await restaurant("new-name", {}, "AB3K7MNT");
    await db.doc("slugs/old-name").set({ restaurantId: rid, current: false, replacedAt: Timestamp.now() });
    const res = await get("/old-name?src=qr");
    expect(res.status).toBe(301);
    expect(res.headers.Location).toBe("/new-name?src=qr");
    expect(await loadMenu(db, "old-name")).toEqual({ kind: "redirect", slug: "new-name" });
  });

  it("redirects /q/{code} with 302 to the current slug and follows slug changes (FR-048, FR-051)", async () => {
    const rid = await restaurant("first-slug", {}, "AB3K7MNU");
    let res = await get("/q/ab3k7mnu");
    expect(res.status).toBe(302);
    expect(res.headers.Location).toBe("/first-slug?src=qr");
    await db.doc(`restaurants/${rid}`).update({ slug: "second-slug" });
    res = await get("/q/AB3K7MNU");
    expect(res.headers.Location).toBe("/second-slug?src=qr");
    expect((await get("/q/ZZZZZZZZ")).status).toBe(404);
    await db.doc("qrCodes/AB3K7MNV").set({ restaurantId: "missing" });
    expect(await resolveQr(db, "AB3K7MNV")).toEqual({ kind: "gone" });
  });

  it("lists only active, published menus in the sitemap", async () => {
    await restaurant("live-one", {}, "AB3K7MNW");
    await restaurant("not-yet", {}, "AB3K7MNX", false);
    await restaurant("paused", { status: "suspended" }, "AB3K7MNY");
    await restaurant("closed", { status: "deactivated" }, "AB3K7MNZ");
    expect((await sitemapEntries(db)).map((e) => e.slug)).toEqual(["live-one"]);
    const res = await get("/sitemap.xml");
    expect(res.status).toBe(200);
    expect(res.headers["Content-Type"]).toBe("application/xml; charset=utf-8");
    expect(res.body).toContain(`<loc>${BASE}/live-one</loc><lastmod>2026-11-15T10:00:00.000Z</lastmod>`);
    expect(res.body).not.toContain("not-yet");
    expect(res.body).not.toContain("paused");
    expect(res.body).not.toContain("closed");
  });
});

describe("published through M06 (FR-044, FR-045)", () => {
  const RIDP = "rest_pm_publish";
  const owner = { uid: "u1", token: { email_verified: true, role: "owner", restaurantId: RIDP } };
  const deps = { resolveImageUrls: async (paths: string[]) => Object.fromEntries(paths.map((p) => [p, `https://img.test/${p}`])) };

  beforeEach(async () => {
    const writes: Promise<unknown>[] = [
      db.doc(`restaurants/${RIDP}`).set({
        name: "Spice Garden",
        ownerUid: "u1",
        ownerEmail: "owner-secret@example.com",
        ownerMobile: "+919999999999",
        status: "active",
        planId: "free",
        slug: "spice-garden",
        qrCode: "AB3K7MNP",
        country: "KW",
        currency: "KWD",
        timezone: "Asia/Kuwait",
        businessType: "restaurant",
        contact: { city: "Kuwait City", phone: "+96522222222", email: "hidden@example.com" },
        visibility: { phone: true, email: false },
        themeId: "saffron",
        themeSettings: {},
        counts: { categories: 0, items: 0 },
        publishedVersion: null,
        pricesNeedReview: false,
        draftUpdatedAt: Timestamp.fromMillis(0),
      }),
      db.doc("slugs/spice-garden").set({ restaurantId: RIDP, current: true }),
    ];
    for (const { id, ...d } of DIETARY_LABELS) writes.push(db.doc(`dietaryLabels/${id}`).set(d));
    for (const { id, ...d } of ITEM_TAGS) writes.push(db.doc(`itemTags/${id}`).set(d));
    for (const t of SEED_THEMES) writes.push(db.doc(`themes/${t.id}`).set({ name: t.name, tokens: t.tokens }));
    await Promise.all(writes);
  });

  it("shows only the published version and public fields, and availability without a publish", async () => {
    const cat = (await createCategory(db, owner, { restaurantId: RIDP, name: "Mains" })).id;
    const hidden = (await createCategory(db, owner, { restaurantId: RIDP, name: "Secret Category" })).id;
    await db.doc(`restaurants/${RIDP}/categories/${hidden}`).update({ active: false, updatedAt: Timestamp.now() });
    const kebab = (await createItem(db, owner, { restaurantId: RIDP, categoryId: cat, name: "Kebab", priceMinor: 1250, dietaryLabelId: "non-vegetarian" })).id;
    await createItem(db, owner, { restaurantId: RIDP, categoryId: hidden, name: "Hidden Dish", priceMinor: 1000, dietaryLabelId: "vegetarian" });
    await publishMenu(db, owner, { restaurantId: RIDP }, deps);

    // A draft edit after the publish must not show (FR-045, FR-062).
    await db.doc(`restaurants/${RIDP}/items/${kebab}`).update({ name: "DRAFT NAME", updatedAt: Timestamp.now() });
    await db.doc(`restaurants/${RIDP}`).update({ description: "DRAFT DESCRIPTION", draftUpdatedAt: Timestamp.now() });

    let res = await get("/spice-garden");
    expect(res.status).toBe(200);
    expect(res.body).toContain("Kebab");
    expect(res.body).toContain("KWD 1.250"); // 3 decimals
    for (const secret of ["DRAFT NAME", "DRAFT DESCRIPTION", "Secret Category", "Hidden Dish", "owner-secret@example.com", "+919999999999", "hidden@example.com", "ownerUid", RIDP]) {
      expect(res.body).not.toContain(secret);
    }
    expect(res.body).toContain("+96522222222");
    expect(res.body).not.toContain("<li class=\"item sold-out");

    // Availability is live (FR-095): the M04 trigger updates the overlay, the page follows.
    await db.doc(`restaurants/${RIDP}/items/${kebab}`).update({ available: false, updatedAt: Timestamp.now() });
    res = await waitFor(() => get("/spice-garden"), (r) => r.body.includes("<li class=\"item sold-out"));
    expect(res.body).toContain("Currently unavailable");
    expect(res.body).toContain("\"availability\":\"https://schema.org/OutOfStock\"");
  });
});

describe("through the Hosting emulator (firebase.json rewrite)", () => {
  it("routes the menu site to renderMenu", async () => {
    await restaurant("hosted-menu", {}, "AB3K7MNP");
    const page = await fetch(`${HOSTING}/hosted-menu`);
    expect(page.status).toBe(200);
    expect(page.headers.get("cache-control")).toBe(CACHE_PUBLIC);
    expect(await page.text()).toContain("<h1>Spice Garden</h1>");
    const qr = await fetch(`${HOSTING}/q/AB3K7MNP`, { redirect: "manual" });
    expect(qr.status).toBe(302);
    expect(qr.headers.get("location")).toMatch(/\/hosted-menu\?src=qr$/);
    const robots = await fetch(`${HOSTING}/robots.txt`);
    expect(await robots.text()).toContain("Disallow: /q/");
    // The favicon is a static file, not a function call.
    expect((await fetch(`${HOSTING}/favicon.ico`)).status).toBe(200);
  });
});
