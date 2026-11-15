/**
 * SEO for the public menu (FRD §7.6, AC-019): title, meta description,
 * canonical, Open Graph and Twitter tags, schema.org JSON-LD
 * (Restaurant → Menu → MenuSection → MenuItem) and `sitemap.xml`.
 * `robots.txt` is static: `scripts/write-robots.mjs`.
 */
import type { MenuSnapshot, SnapshotImage, SnapshotItem } from "../publishing/snapshot";
import { majorAmount } from "./format";
import { openingHoursSpecification } from "./hours";
import { esc, safeUrl } from "./html";
import { fill, menuText } from "./text";

/** Page title: "{Name} – Menu | EazySuvai". */
export function pageTitle(s: MenuSnapshot): string {
  return `${s.profile.name} – ${menuText(s.locale).titleSuffix}`;
}

/** Collapses whitespace and cuts at a word boundary, with an ellipsis. */
export function truncate(text: string, max: number): string {
  const t = text.replace(/\s+/g, " ").trim();
  if (t.length <= max) return t;
  const cut = t.slice(0, max - 1);
  const space = cut.lastIndexOf(" ");
  return `${(space > max * 0.6 ? cut.slice(0, space) : cut).replace(/[\s,.;:–-]+$/, "")}…`;
}

/** Meta description: the restaurant's description, or a sentence with its name and city. */
export function metaDescription(s: MenuSnapshot): string {
  if (s.profile.description) return truncate(s.profile.description, 160);
  const city = s.profile.contact.city;
  return truncate(fill(menuText(s.locale).defaultDescription, { name: s.profile.name, place: city ? ` in ${city}` : "" }), 160);
}

/** The share image: the cover, else the logo (FR-070). */
export function shareImage(s: MenuSnapshot): { url: string; width: number; height: number; large: boolean } | null {
  const pick = (img: SnapshotImage | undefined, large: boolean) => {
    if (!img) return null;
    const url = safeUrl(large ? img.w1280 : img.w640);
    if (!url) return null;
    // Renditions are never enlarged; scale the original's size to the rendition width.
    const target = large ? 1280 : 640;
    const width = img.width > 0 ? Math.min(img.width, target) : 0;
    const height = img.width > 0 && img.height > 0 ? Math.round((img.height * width) / img.width) : 0;
    return { url, width, height, large };
  };
  return pick(s.profile.cover, true) ?? pick(s.profile.logo, false);
}

/** `en-IN` → `en_IN` for `og:locale`. */
function ogLocale(locale: string): string {
  return locale.replace("-", "_");
}

/**
 * `<head>` tags for a live menu: description, canonical, Open Graph,
 * Twitter and JSON-LD. Every value is escaped.
 *
 * @param s The published snapshot.
 * @param canonicalUrl `https://menu.eazysuvai.com/{slug}`.
 * @param availability The live overlay, for the JSON-LD offers.
 * @return Safe HTML.
 */
export function seoHead(s: MenuSnapshot, canonicalUrl: string, availability: Record<string, boolean> = {}): string {
  const title = pageTitle(s);
  const description = metaDescription(s);
  const img = shareImage(s);
  const tags = [
    `<meta name="description" content="${esc(description)}">`,
    `<link rel="canonical" href="${esc(canonicalUrl)}">`,
    "<meta property=\"og:type\" content=\"website\">",
    "<meta property=\"og:site_name\" content=\"EazySuvai\">",
    `<meta property="og:title" content="${esc(title)}">`,
    `<meta property="og:description" content="${esc(description)}">`,
    `<meta property="og:url" content="${esc(canonicalUrl)}">`,
    `<meta property="og:locale" content="${esc(ogLocale(s.locale))}">`,
    `<meta name="twitter:card" content="${img?.large ? "summary_large_image" : "summary"}">`,
    `<meta name="twitter:title" content="${esc(title)}">`,
    `<meta name="twitter:description" content="${esc(description)}">`,
  ];
  if (img) {
    tags.push(`<meta property="og:image" content="${esc(img.url)}">`);
    if (img.width > 0 && img.height > 0) {
      tags.push(`<meta property="og:image:width" content="${img.width}">`, `<meta property="og:image:height" content="${img.height}">`);
    }
    tags.push(`<meta property="og:image:alt" content="${esc(s.profile.name)}">`, `<meta name="twitter:image" content="${esc(img.url)}">`);
  }
  tags.push(`<script type="application/ld+json">${jsonForScript(menuJsonLd(s, canonicalUrl, availability))}</script>`);
  return tags.join("\n");
}

/** JSON inside `<script>`: `<`, `>`, `&` and line separators escaped, so no value can close the tag. */
const LINE_SEPARATORS = new RegExp(`[${String.fromCharCode(0x2028, 0x2029)}]`, "g");

export function jsonForScript(value: unknown): string {
  return JSON.stringify(value)
    .replace(/</g, "\\u003c")
    .replace(/>/g, "\\u003e")
    .replace(/&/g, "\\u0026")
    .replace(LINE_SEPARATORS, (c) => `\\u${c.charCodeAt(0).toString(16)}`);
}

const SCHEMA_TYPE: Record<string, string> = {
  restaurant: "Restaurant",
  cafe: "CafeOrCoffeeShop",
  bakery: "Bakery",
  bar: "BarOrPub",
  juiceBar: "FoodEstablishment",
  sweetShop: "FoodEstablishment",
  cloudKitchen: "Restaurant",
  foodTruck: "FoodEstablishment",
  hotel: "Restaurant",
};

const DIET: Record<string, string> = {
  vegetarian: "https://schema.org/VegetarianDiet",
  vegan: "https://schema.org/VeganDiet",
};

function imageUrl(img: SnapshotImage | undefined): string | undefined {
  return img ? safeUrl(img.w1280) ?? undefined : undefined;
}

function menuItemLd(i: SnapshotItem, s: MenuSnapshot, available: boolean): Record<string, unknown> {
  const out: Record<string, unknown> = { "@type": "MenuItem", name: i.name };
  if (i.description) out.description = i.description;
  const image = imageUrl(i.image);
  if (image) out.image = image;
  out.offers = {
    "@type": "Offer",
    price: majorAmount(i.priceMinor, s.currency),
    priceCurrency: s.currency,
    availability: available ? "https://schema.org/InStock" : "https://schema.org/OutOfStock",
  };
  const diet = i.dietaryLabel ? DIET[i.dietaryLabel.id] : undefined;
  if (diet) out.suitableForDiet = diet;
  return out;
}

/**
 * schema.org JSON-LD for the menu (FRD §7.6).
 *
 * @param s The published snapshot.
 * @param canonicalUrl The menu URL.
 * @param availability The live overlay (FR-095), for `offers.availability`.
 * @return The JSON-LD object.
 */
export function menuJsonLd(s: MenuSnapshot, canonicalUrl: string, availability: Record<string, boolean> = {}): Record<string, unknown> {
  const p = s.profile;
  const c = p.contact;
  const out: Record<string, unknown> = {
    "@context": "https://schema.org",
    "@type": SCHEMA_TYPE[p.businessType] ?? "FoodEstablishment",
    name: p.name,
    url: canonicalUrl,
  };
  if (p.description) out.description = p.description;
  const images = [imageUrl(p.cover), imageUrl(p.logo)].filter((u): u is string => !!u);
  if (images.length > 0) out.image = images;
  const logo = imageUrl(p.logo);
  if (logo) out.logo = logo;
  if (c.phone) out.telephone = c.phone;
  if (c.email) out.email = c.email;
  if (c.address || c.city || c.postalCode) {
    const address: Record<string, string> = { "@type": "PostalAddress" };
    if (c.address) address.streetAddress = c.address;
    if (c.city) address.addressLocality = c.city;
    if (c.postalCode) address.postalCode = c.postalCode;
    const country = /^[a-z]{2}-([A-Z]{2})$/.exec(s.locale)?.[1];
    if (country) address.addressCountry = country;
    out.address = address;
  }
  const sameAs = [c.website, ...Object.values(c.social ?? {})].map((u) => safeUrl(u)).filter((u): u is string => !!u);
  if (sameAs.length > 0) out.sameAs = sameAs;
  const hours = openingHoursSpecification(p.openingHours);
  if (hours.length > 0) out.openingHoursSpecification = hours;
  out.currenciesAccepted = s.currency;

  const byCategory = new Map<string, SnapshotItem[]>();
  for (const i of s.items) byCategory.set(i.categoryId, [...(byCategory.get(i.categoryId) ?? []), i]);
  out.hasMenu = {
    "@type": "Menu",
    name: `${p.name} – ${menuText(s.locale).menu}`,
    url: canonicalUrl,
    inLanguage: s.locale,
    hasMenuSection: s.categories
      .filter((cat) => (byCategory.get(cat.id) ?? []).length > 0)
      .map((cat) => {
        const section: Record<string, unknown> = { "@type": "MenuSection", name: cat.name };
        if (cat.description) section.description = cat.description;
        const img = imageUrl(cat.image);
        if (img) section.image = img;
        section.hasMenuItem = (byCategory.get(cat.id) ?? []).map((i) => menuItemLd(i, s, availability[i.id] ?? i.available));
        return section;
      }),
  };
  return out;
}

export interface SitemapEntry {
  slug: string;
  lastmod: Date | null;
}

/**
 * `sitemap.xml` of active, published menus (FRD §7.6).
 *
 * @param baseUrl The menu origin, without a trailing slash.
 * @param entries One per menu.
 * @return The XML.
 */
export function sitemapXml(baseUrl: string, entries: SitemapEntry[]): string {
  const urls = entries
    .map(
      (e) =>
        `<url><loc>${esc(`${baseUrl}/${e.slug}`)}</loc>${e.lastmod ? `<lastmod>${e.lastmod.toISOString()}</lastmod>` : ""}</url>`,
    )
    .join("\n");
  return `<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n${urls}\n</urlset>\n`;
}

