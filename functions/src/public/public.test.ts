import { readFileSync } from "node:fs";
import { join } from "node:path";

import { HtmlValidate } from "html-validate";
import type { Firestore } from "firebase-admin/firestore";

import { removeBrandingFrom } from "../lib/plan-limits";
import { BODY_SCRIPT, HEAD_SCRIPT } from "./client-script";
import { formatPrice, majorAmount } from "./format";
import { isOpenAt, localTime, openingHoursSpecification } from "./hours";
import { filterBarHtml, renderMenuPage } from "./render-menu";
import { routeOf } from "./routes";
import { sampleSnapshot } from "./sample-menu";
import { jsonForScript, menuJsonLd, metaDescription, pageTitle, seoHead, sitemapXml, truncate } from "./seo";
import { CACHE_PUBLIC, MENU_ORIGINS, contentSecurityPolicy, handleMenuRequest, menuBaseUrl } from "./serve";
import { STATE_STATUS, renderStatePage, type StateKind } from "./state-pages";
import { MENU_TEXT_EN } from "./text";

const BASE = "https://menu.eazysuvai.com";
const CANONICAL = `${BASE}/spice-garden`;
// Thursday 2026-11-12 19:30 in Chennai (14:00 UTC).
const THU_EVENING = new Date("2026-11-12T14:00:00Z");

const live = (s = sampleSnapshot(), extra: Parameters<typeof renderMenuPage>[1] = {}) =>
  renderMenuPage(s, { canonicalUrl: CANONICAL, slug: "spice-garden", now: THU_EVENING, availability: {}, branding: true, ...extra });

const validator = new HtmlValidate({
  extends: ["html-validate:recommended"],
  rules: {
    // Inline styles and scripts are the design (critical CSS, < 10 KB JS).
    "no-inline-style": "off",
    "require-sri": "off",
    // `–` in titles and text is intended.
    "no-trailing-whitespace": "off",
    "long-title": "off",
  },
});

async function expectValidHtml(html: string): Promise<void> {
  const report = await validator.validateString(html);
  const messages = report.results.flatMap((r) => r.messages.map((m) => `${m.ruleId}: ${m.message} (line ${m.line})`));
  expect(messages).toEqual([]);
}

describe("routeOf", () => {
  it.each([
    ["/spice-garden", "", { kind: "menu", slug: "spice-garden" }],
    ["/spice-garden/", "?src=qr", { kind: "redirect", status: 301, location: "/spice-garden?src=qr" }],
    ["/Spice-Garden", "", { kind: "redirect", status: 301, location: "/spice-garden" }],
    ["/q/ab3k7mnp", "", { kind: "qr", code: "AB3K7MNP" }],
    ["/q/AB3K7MNP/", "", { kind: "qr", code: "AB3K7MNP" }],
    ["/q/AB0K7MNP", "", { kind: "not-found" }],
    ["/q/short", "", { kind: "not-found" }],
    ["/sitemap.xml", "", { kind: "sitemap" }],
    ["/robots.txt", "", { kind: "not-found" }],
    ["/", "", { kind: "not-found" }],
    ["/a/b", "", { kind: "not-found" }],
    ["/-bad-", "", { kind: "not-found" }],
    ["/%E0%A4", "", { kind: "not-found" }],
    ["/<script>", "", { kind: "not-found" }],
  ])("%s%s", (path, query, expected) => {
    expect(routeOf(path, query)).toEqual(expected);
  });
});

describe("opening hours", () => {
  const h = sampleSnapshot().profile.openingHours!;
  const at = (iso: string) => isOpenAt(h, "Asia/Kolkata", new Date(iso));

  it("reads the time in the restaurant's zone", () => {
    expect(localTime(THU_EVENING, "Asia/Kolkata")).toEqual({ day: "thu", minute: 19 * 60 + 30 });
    expect(localTime(THU_EVENING, "America/New_York")).toEqual({ day: "thu", minute: 9 * 60 });
    expect(localTime(THU_EVENING, "Not/AZone")).toEqual({ day: "thu", minute: 14 * 60 });
  });

  it("is open inside a slot and closed between slots", () => {
    expect(at("2026-11-12T14:00:00Z")).toBe(true); // Thu 19:30
    expect(at("2026-11-12T08:30:00Z")).toBe(false); // Thu 14:00
    expect(at("2026-11-12T01:30:00Z")).toBe(true); // Thu 07:00 (opening minute)
    expect(at("2026-11-12T18:00:00Z")).toBe(false); // Thu 23:30 (closing minute)
  });

  it("handles slots past midnight, all-day and closed days", () => {
    expect(at("2026-11-13T19:00:00Z")).toBe(true); // Sat 00:30, Friday's slot runs to 01:00 (and Saturday is all day)
    expect(isOpenAt({ ...h, sat: "" }, "Asia/Kolkata", new Date("2026-11-13T19:00:00Z"))).toBe(true); // Fri 18:00-01:00 only
    expect(isOpenAt({ ...h, sat: "" }, "Asia/Kolkata", new Date("2026-11-13T20:00:00Z"))).toBe(false); // Sat 01:30
    expect(at("2026-11-14T08:00:00Z")).toBe(true); // Sat 13:30, all day
    expect(at("2026-11-15T08:00:00Z")).toBe(false); // Sun, closed
    expect(isOpenAt(undefined, "Asia/Kolkata", THU_EVENING)).toBeNull();
    expect(isOpenAt({ mon: "", tue: "", wed: "", thu: "", fri: "", sat: "", sun: "" }, "UTC", THU_EVENING)).toBeNull();
  });

  it("maps to schema.org OpeningHoursSpecification", () => {
    const spec = openingHoursSpecification(h);
    expect(spec).toHaveLength(11); // 4 days × 2 + Fri 2 + Sat 1; Sunday closed
    expect(spec).toContainEqual({ "@type": "OpeningHoursSpecification", dayOfWeek: "https://schema.org/Saturday", opens: "00:00", closes: "23:59" });
    expect(spec).toContainEqual({ "@type": "OpeningHoursSpecification", dayOfWeek: "https://schema.org/Friday", opens: "18:00", closes: "01:00" });
  });
});

describe("prices", () => {
  it("formats with the currency and locale, exactly", () => {
    expect(formatPrice(12900, "INR", "en-IN")).toBe("₹129.00");
    expect(formatPrice(12500050, "INR", "en-IN")).toBe("₹1,25,000.50");
    expect(formatPrice(1250, "KWD", "en-KW")).toBe("KWD 1.250");
    expect(formatPrice(2500, "BHD", "en-BH")).toBe("BHD 2.500");
    expect(formatPrice(4500, "AED", "en-AE")).toBe("AED 45.00");
    expect(formatPrice(1299, "USD", "en-US")).toBe("$12.99");
    expect(majorAmount(1250, "KWD")).toBe("1.250");
    expect(majorAmount(5, "INR")).toBe("0.05");
  });
});

describe("SEO", () => {
  const s = sampleSnapshot();

  it("builds title, description and share tags", () => {
    expect(pageTitle(s)).toBe("Spice Garden – Menu | EazySuvai");
    expect(metaDescription(s)).toBe(s.profile.description);
    expect(metaDescription({ ...s, profile: { ...s.profile, description: undefined } })).toBe(
      "See the menu of Spice Garden in Chennai: dishes, prices and opening hours.",
    );
    expect(truncate("word ".repeat(100), 160).length).toBeLessThanOrEqual(160);
    const head = seoHead(s, CANONICAL);
    expect(head).toContain(`<link rel="canonical" href="${CANONICAL}">`);
    expect(head).toContain("<meta property=\"og:image\" content=\"https://img.test/cover/w1280.webp\">");
    expect(head).toContain("<meta property=\"og:image:width\" content=\"1200\">");
    expect(head).toContain("<meta name=\"twitter:card\" content=\"summary_large_image\">");
    expect(head).toContain("<meta property=\"og:locale\" content=\"en_IN\">");
    // Logo only: a small card.
    const logoOnly = seoHead({ ...s, profile: { ...s.profile, cover: undefined } }, CANONICAL);
    expect(logoOnly).toContain("https://img.test/logo/w640.webp");
    expect(logoOnly).toContain("content=\"summary\"");
  });

  it("describes the menu as Restaurant → Menu → MenuSection → MenuItem", () => {
    const ld = menuJsonLd(s, CANONICAL, { "biryani-1": false }) as Record<string, any>; // eslint-disable-line @typescript-eslint/no-explicit-any
    expect(ld["@type"]).toBe("Restaurant");
    expect(ld.url).toBe(CANONICAL);
    expect(ld.telephone).toBe("+914423456789");
    expect(ld.address).toEqual({ "@type": "PostalAddress", streetAddress: "12 Anna Salai", addressLocality: "Chennai", postalCode: "600002", addressCountry: "IN" });
    expect(ld.hasMenu["@type"]).toBe("Menu");
    expect(ld.hasMenu.hasMenuSection).toHaveLength(6);
    const biryani = ld.hasMenu.hasMenuSection[2];
    expect(biryani).toMatchObject({ "@type": "MenuSection", name: "Biryani" });
    expect(biryani.hasMenuItem[0]).toMatchObject({
      "@type": "MenuItem",
      name: "Chicken Biryani",
      offers: { "@type": "Offer", price: "240.00", priceCurrency: "INR", availability: "https://schema.org/OutOfStock" },
    });
    expect(biryani.hasMenuItem[1].offers.availability).toBe("https://schema.org/OutOfStock"); // sold out in the snapshot
    expect(biryani.hasMenuItem[3].suitableForDiet).toBe("https://schema.org/VegetarianDiet");
  });

  it("can't break out of the JSON-LD script", () => {
    const out = jsonForScript({ a: "</script><script>alert(1)</script>", b: "x y" });
    expect(out).not.toContain("</script>");
    expect(out).not.toContain(" ");
    expect(JSON.parse(out)).toEqual({ a: "</script><script>alert(1)</script>", b: "x y" });
  });

  it("writes sitemap.xml", () => {
    const xml = sitemapXml(BASE, [{ slug: "a-b", lastmod: new Date("2026-11-15T10:00:00Z") }, { slug: "c", lastmod: null }]);
    expect(xml).toContain("<url><loc>https://menu.eazysuvai.com/a-b</loc><lastmod>2026-11-15T10:00:00.000Z</lastmod></url>");
    expect(xml).toContain("<url><loc>https://menu.eazysuvai.com/c</loc></url>");
  });
});

describe("menu page", () => {
  it("matches the template snapshot (live, Free plan)", () => {
    expect(live()).toMatchSnapshot();
  });

  it("is valid HTML in every layout", async () => {
    await expectValidHtml(live());
    const s = sampleSnapshot();
    for (const [layout, cardLayout, mode] of [["grid", "image-top", "dark"], ["list", "compact", "light"]] as const) {
      await expectValidHtml(live({ ...s, theme: { ...s.theme, resolved: { ...s.theme.resolved, layout, cardLayout, mode } } }));
    }
    await expectValidHtml(renderMenuPage(s, { draft: true }));
  });

  it("has the page parts the plan lists", () => {
    const html = live(sampleSnapshot(), { availability: { "tiffin-1": false } });
    expect(html).toContain("<title>Spice Garden – Menu | EazySuvai</title>");
    expect(html).toMatch(/<html lang="en-IN"/);
    expect(html).toContain("<h1>Spice Garden</h1>");
    expect(html).toContain("Open now");
    expect(html).toContain("href=\"tel:+914423456789\"");
    expect(html).toContain("https://www.google.com/maps/search/?api=1&amp;query=");
    expect(html).toContain("<nav class=\"cats\" aria-label=\"Categories\">");
    expect(html).toContain("<section id=\"featured\"");
    expect(html).toContain("<h2 id=\"c-tiffin-h\">Tiffin</h2>");
    expect(html).toContain("₹129.00");
    expect(html).toContain("Vegetarian</span>");
    expect(html).toContain("Non-vegetarian</span>");
    expect(html).toContain("<span class=\"tag\">Bestseller</span>");
    // Sold out from the snapshot and from the live overlay.
    expect(html.match(/<li class="item sold-out/g)).toHaveLength(2);
    expect(html.match(/Currently unavailable/g)).toHaveLength(2);
    expect(html).toContain("aria-disabled=\"true\"");
    // Lightbox works as a plain link without JS.
    expect(html).toContain("<a class=\"zoom\" href=\"https://img.test/item-tiffin-1/w1280.webp\" aria-label=\"Enlarge photo of Idli (2 pcs)\">");
    expect(html).toContain("srcset=\"https://img.test/item-tiffin-1/w320.webp 320w, https://img.test/item-tiffin-1/w640.webp 640w, https://img.test/item-tiffin-1/w1280.webp 1280w\"");
    expect(html).toContain("loading=\"lazy\"");
    // The cover is the likely LCP element: never lazy.
    expect(html).toMatch(/<img class="cover"[^>]*fetchpriority="high"/);
    expect(html).not.toMatch(/<img class="cover"[^>]*loading="lazy"/);
    expect(html).toContain("<footer class=\"wrap\">Powered by EazySuvai · <a href=\"/privacy\">Privacy</a> · <a href=\"/terms\">Terms</a></footer>");
    expect(html).toContain("application/ld+json");
    expect(html).not.toContain("noindex");
    expect(html).not.toMatch(/undefined|\[object Object\]|NaN/);
  });

  it("shows Closed now outside the hours and hides branding on Pro", () => {
    const html = live(sampleSnapshot(), { now: new Date("2026-11-15T08:00:00Z"), branding: false });
    expect(html).toContain("Closed now");
    expect(html).not.toContain("Powered by EazySuvai");
    // Privacy and terms stay without branding (M13).
    expect(html).toContain("<footer class=\"wrap\"><a href=\"/privacy\">Privacy</a> · <a href=\"/terms\">Terms</a></footer>");
  });

  it("shows KWD prices with 3 decimals", () => {
    const html = live({ ...sampleSnapshot(), currency: "KWD", locale: "en-KW" });
    expect(html).toContain("KWD 6.000"); // Idli, 6000 fils
    expect(html).toContain("\"price\":\"6.000\",\"priceCurrency\":\"KWD\"");
  });

  it("escapes every value", () => {
    const x = "<img src=x onerror=alert(1)>\"'&";
    const s = sampleSnapshot();
    s.profile.name = x;
    s.profile.description = x;
    s.profile.contact = { phone: x, email: x, address: x, city: x, website: "javascript:alert(1)", social: { instagram: "javascript:alert(1)" } };
    s.categories[0].name = x;
    s.categories[0].description = x;
    s.items[0].name = x;
    s.items[0].description = x;
    s.items[0].dietaryLabel = { id: "vegetarian", name: x, icon: "veg", color: "red\"><script>" };
    s.items[0].tags = [{ id: "t", name: x, icon: null, color: null }];
    s.items[0].id = "a\"b";
    const html = live(s);
    expect(html).not.toContain("<img src=x");
    expect(html).not.toContain("javascript:");
    expect(html).not.toContain("red\"><script>");
    expect(html).toContain("&lt;img src=x onerror=alert(1)&gt;&quot;&#39;&amp;");
  });

  it("ships under 10 KB of JavaScript that parses", () => {
    const bytes = Buffer.byteLength(HEAD_SCRIPT) + Buffer.byteLength(BODY_SCRIPT);
    expect(bytes).toBeLessThan(10 * 1024);
    expect(() => new Function(BODY_SCRIPT)).not.toThrow();
    expect(() => new Function(HEAD_SCRIPT)).not.toThrow();
  });

  describe("filter bar (dietary labels and tags)", () => {
    const s = sampleSnapshot();
    const items = s.items;
    const html = live(s);

    it("offers a chip per dietary label and tag in use, hidden until the script runs", () => {
      const bar = html.match(/<div class="filters"[^>]*>[\s\S]*?<\/div>/)![0];
      expect(bar).toContain(" hidden>");
      expect(bar).toContain(`aria-label="${MENU_TEXT_EN.filters}"`);
      const dietary = new Set(items.map((i) => i.dietaryLabel?.id).filter(Boolean));
      const tags = new Set(items.flatMap((i) => i.tags.map((x) => x.id)));
      expect(bar.match(/data-g="d"/g)?.length).toBe(dietary.size);
      expect(bar.match(/data-g="t"/g)?.length).toBe(tags.size);
      expect(bar).toContain(MENU_TEXT_EN.clearFilters);
      expect(html).toContain(`<p class="no-match" hidden>${MENU_TEXT_EN.noMatch}</p>`);
    });

    it("tags each item with its label and tag ids", () => {
      const spicy = items.find((i) => i.tags.length > 0)!;
      expect(html).toContain(
        `data-id="${spicy.id}" data-d="${spicy.dietaryLabel!.id}" data-t="${spicy.tags.map((x) => x.id).join(" ")}"`,
      );
    });

    it("leaves out chips that would filter nothing", () => {
      const label = items[0].dietaryLabel!;
      const same = { ...s, items: items.map((i) => ({ ...i, dietaryLabel: label, tags: [] })) };
      expect(filterBarHtml(same.items, MENU_TEXT_EN)).toBe("");
      expect(live(same)).not.toContain("class=\"filters\"");
      // One label, but some items have none: the chip is useful.
      const mixed = same.items.map((i, n) => (n === 0 ? { ...i, dietaryLabel: null } : i));
      expect(filterBarHtml(mixed, MENU_TEXT_EN).match(/data-g="d"/g)).toHaveLength(1);
    });

    it("is valid HTML and absent from the draft preview", async () => {
      await expectValidHtml(html);
      expect(renderMenuPage(s, { draft: true })).not.toContain("class=\"filters\"");
    });
  });

  it("keeps the draft preview script-free and noindex", () => {
    const html = renderMenuPage(sampleSnapshot(), { draft: true, canonicalUrl: CANONICAL });
    expect(html).not.toContain("<script");
    expect(html).not.toContain("rel=\"canonical\"");
    expect(html).toContain("noindex");
    expect(html).not.toContain("Open now");
  });
});

describe("state pages (FR-099)", () => {
  const kinds: StateKind[] = ["coming-soon", "unavailable", "gone", "not-found", "error"];

  it.each(kinds)("%s matches its snapshot and is valid HTML", async (kind) => {
    const html = renderStatePage(kind, { name: "Spice <Garden>", retryUrl: "/spice-garden" });
    expect(html).toMatchSnapshot();
    expect(html).toContain("<meta name=\"robots\" content=\"noindex,nofollow\">");
    expect(html).not.toContain("<script");
    await expectValidHtml(html);
  });

  it("shows the name only where FR-099 allows it", () => {
    expect(renderStatePage("coming-soon", { name: "Spice" })).toContain("Spice is getting its menu ready");
    expect(renderStatePage("unavailable", { name: "Spice" })).toContain("<p class=\"name\">Spice</p>");
    expect(renderStatePage("gone", { name: "Spice" })).not.toContain("Spice");
    expect(renderStatePage("not-found", { name: "Spice" })).not.toContain("Spice");
  });

  it("maps to the HTTP codes", () => {
    expect(STATE_STATUS).toEqual({ "coming-soon": 404, "unavailable": 503, "gone": 410, "not-found": 404, "error": 500 });
  });
});

describe("handleMenuRequest without data", () => {
  const failing = { doc: () => { throw new Error("db down"); } } as unknown as Firestore;
  const req = (path: string, query = "", method = "GET") => ({ method, path, query, headers: {} });

  it("answers the sitemap with an ETag, redirects, 405 and not-found", async () => {
    const empty = { collection: () => ({ where: () => ({ select: () => ({ get: async () => ({ docs: [] }) }) }) }) } as unknown as Firestore;
    const map = await handleMenuRequest(empty, req("/sitemap.xml"), { baseUrl: BASE });
    expect(map.status).toBe(200);
    expect(map.headers["Cache-Control"]).toBe(CACHE_PUBLIC);
    expect(map.headers.ETag).toMatch(/^W\/"/);
    const again = await handleMenuRequest(empty, { ...req("/sitemap.xml"), headers: { "if-none-match": map.headers.ETag } }, { baseUrl: BASE });
    expect(again.status).toBe(304);
    expect(again.body).toBe("");

    const r = await handleMenuRequest(failing, req("/Spice-Garden/", "?src=qr"));
    expect(r).toMatchObject({ status: 301, headers: { Location: "/spice-garden?src=qr" } });

    expect((await handleMenuRequest(failing, req("/x", "", "POST"))).status).toBe(405);

    const nf = await handleMenuRequest(failing, req("/a/b/c"));
    expect(nf.status).toBe(404);
    expect(nf.headers["X-Robots-Tag"]).toBe("noindex");
  });

  it("shows the error page, uncached, when Firestore fails", async () => {
    const errors: string[] = [];
    const res = await handleMenuRequest(failing, req("/spice-garden"), { logError: (m) => errors.push(m) });
    expect(res.status).toBe(500);
    expect(res.headers["Cache-Control"]).toBe("no-store");
    expect(res.body).toContain("href=\"/spice-garden\"");
    expect(errors).toEqual(["renderMenu /spice-garden"]);
  });

  it("allows only the page's own scripts", () => {
    const csp = contentSecurityPolicy();
    expect(csp).toMatch(/script-src 'sha256-[^']+' 'sha256-[^']+'/);
    expect(csp).toContain("frame-ancestors 'none'");
    expect(csp).not.toContain("http:");
    expect(contentSecurityPolicy(true)).toContain("img-src https: data: http:");
  });

  it("reads the base URL from MENU_BASE_URL", () => {
    expect(menuBaseUrl({})).toBe(BASE);
    expect(menuBaseUrl({ GCLOUD_PROJECT: "eazy-suvai-dev" })).toBe("https://eazy-suvai-dev-menu.web.app");
    expect(menuBaseUrl({ FIREBASE_CONFIG: "{\"projectId\":\"demo-eazysuvai\"}" })).toBe("http://127.0.0.1:5000");
    expect(menuBaseUrl({ GCLOUD_PROJECT: "unknown" })).toBe(BASE);
    // scripts/write-robots.mjs keeps the same map.
    const script = readFileSync(join(__dirname, "../../scripts/write-robots.mjs"), "utf8");
    const map = /export const ORIGINS = (\{[^}]+\});/.exec(script)![1].replace(/,\s*\}/, "}");
    expect(JSON.parse(map)).toEqual(MENU_ORIGINS);
    expect(menuBaseUrl({ MENU_BASE_URL: "https://eazy-suvai-dev-menu.web.app/" })).toBe("https://eazy-suvai-dev-menu.web.app");
    expect(menuBaseUrl({ MENU_BASE_URL: "javascript:alert(1)" })).toBe(BASE);
  });

  it("hides the footer on plans with removeBranding", () => {
    expect(removeBrandingFrom("free", undefined)).toBe(false);
    expect(removeBrandingFrom("pro", undefined)).toBe(true);
    expect(removeBrandingFrom("free", { limits: { removeBranding: true } })).toBe(true);
  });
});
