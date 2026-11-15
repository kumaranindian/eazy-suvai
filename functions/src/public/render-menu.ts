/**
 * Renders a menu snapshot as one HTML page (architecture §3).
 *
 * M06 uses it for the owner's draft preview (`draft: true`: a "Preview"
 * banner, `noindex`, no scripts). M07's `renderMenu` serves the published
 * version with the same function, adding SEO tags and JSON-LD
 * (`canonicalUrl`), the inline script and the "Open now" state, so the
 * preview and the public page never drift apart.
 *
 * Everything is escaped. Colours come only from the contrast-fixed theme
 * (`snapshot.theme.resolved`, FR-060). Unavailable items are "dimmed"
 * without opacity, which would break AA: their photo turns grey, the card
 * gets a dashed border and a "Currently unavailable" badge (FR-043).
 *
 * Layout (M07 plan): one column below 600 px; two columns from 600 px;
 * from 1024 px the category bar becomes a left sidebar and grid menus get
 * three columns, content at most 1200 px wide.
 */
import { cssVariables, type ResolvedTheme } from "../theme";
import type { MenuSnapshot, SnapshotImage, SnapshotItem, SnapshotLabel } from "../publishing/snapshot";
import { WEEKDAYS } from "../publishing/snapshot";
import { BODY_SCRIPT, HEAD_SCRIPT } from "./client-script";
import { formatDayHours, formatPrice } from "./format";
import { isOpenAt, localTime } from "./hours";
import { anchorId, esc, safeUrl } from "./html";
import { pageTitle, seoHead } from "./seo";
import { MENU_TEXT_EN, menuText, type MenuText } from "./text";

/** Customer-facing words (kept as an export for the M06 callers). */
export const MENU_TEXT = MENU_TEXT_EN;

export interface RenderOptions {
  /** Draft preview: banner, `noindex`, no scripts (FR-061, FR-062). */
  draft?: boolean;
  /** `live/availability.items`, laid over the snapshot (FR-095). */
  availability?: Record<string, boolean>;
  /** Show "Powered by EazySuvai" (Free plan; `limits.removeBranding` hides it). */
  branding?: boolean;
  /** The live menu's URL: adds canonical, Open Graph, Twitter and JSON-LD (M07). */
  canonicalUrl?: string;
  /** The slug, for the analytics hook (`<body data-slug>`). */
  slug?: string;
  /** The analytics endpoint, for example `/e` (M09). Unset: the hook sends nothing. */
  beacon?: string;
  /** Include the inline script. Default: on for public pages, off for the draft. */
  scripts?: boolean;
  /** The time used for "Open now" (default: now). */
  now?: Date;
  /** Extra tags for `<head>`. Must be safe HTML. */
  headExtra?: string;
  /** Extra HTML before `</body>`. Must be safe HTML. */
  bodyExtra?: string;
}

interface ImgOptions {
  sizes: string;
  cls: string;
  alt?: string;
  eager?: boolean;
  /** Original-size hint for the lightbox caption. */
  dataAlt?: string;
}

function imgTag(image: SnapshotImage, o: ImgOptions): string {
  const urls = [image.w320, image.w640, image.w1280].map(safeUrl);
  if (urls.some((u) => u === null)) return "";
  const [a, b, c] = urls as string[];
  const dims = image.width > 0 && image.height > 0 ? ` width="${image.width}" height="${image.height}"` : "";
  const loading = o.eager ? " fetchpriority=\"high\"" : " loading=\"lazy\"";
  const dataAlt = o.dataAlt ? ` data-alt="${esc(o.dataAlt)}"` : "";
  return `<img class="${o.cls}" src="${esc(b)}" srcset="${esc(a)} 320w, ${esc(b)} 640w, ${esc(c)} 1280w" sizes="${esc(o.sizes)}"${dims}${loading} decoding="async" alt="${esc(o.alt ?? "")}"${dataAlt}>`;
}

/** An image that opens the large rendition: in the lightbox with JS, as a page without (FR-041). */
function zoomable(image: SnapshotImage, o: ImgOptions & { label: string }): string {
  const tag = imgTag(image, o);
  const big = safeUrl(image.w1280);
  if (!tag || !big) return "";
  return `<a class="zoom" href="${esc(big)}" aria-label="${esc(o.label)}">${tag}</a>`;
}

/** India's veg / non-veg marks (FR-023), drawn inline; other labels get a dot. */
function labelIcon(label: SnapshotLabel): string {
  const color = /^#[0-9A-Fa-f]{6}$/.test(label.color ?? "") ? label.color! : null;
  if (label.icon === "veg") {
    const c = color ?? "#0F7B0F";
    return `<svg class="mark" viewBox="0 0 16 16" aria-hidden="true"><rect x="1" y="1" width="14" height="14" fill="#fff" stroke="${c}" stroke-width="2"/><circle cx="8" cy="8" r="4" fill="${c}"/></svg>`;
  }
  if (label.icon === "nonVeg") {
    const c = color ?? "#8B2E16";
    return `<svg class="mark" viewBox="0 0 16 16" aria-hidden="true"><rect x="1" y="1" width="14" height="14" fill="#fff" stroke="${c}" stroke-width="2"/><path d="M8 3.5 12.5 12h-9z" fill="${c}"/></svg>`;
  }
  const c = color ?? "currentColor";
  return `<svg class="mark" viewBox="0 0 16 16" aria-hidden="true"><circle cx="8" cy="8" r="5" fill="${c}"/></svg>`;
}

function itemHtml(item: SnapshotItem, s: MenuSnapshot, available: boolean, t: MenuText): string {
  const price = formatPrice(item.priceMinor, s.currency, s.locale);
  const badges: string[] = [];
  if (item.dietaryLabel) {
    badges.push(`<span class="label">${labelIcon(item.dietaryLabel)}${esc(item.dietaryLabel.name)}</span>`);
  }
  for (const tag of item.tags) badges.push(`<span class="tag">${esc(tag.name)}</span>`);
  const image = item.image
    ? zoomable(item.image, {
      sizes: "(min-width: 1024px) 300px, (min-width: 600px) 45vw, 88px",
      cls: "item-img",
      dataAlt: item.name,
      label: `${t.enlarge} ${item.name}`,
    })
    : "";
  const cls = `item${available ? "" : " sold-out"}${image ? " has-img" : ""}${item.featured ? " is-featured" : ""}`;
  return `<li class="${cls}" data-id="${esc(item.id)}"${available ? "" : " aria-disabled=\"true\""}>
${image}<div class="item-body">
<h3 class="item-name">${esc(item.name)}${item.featured ? ` <span class="badge featured">${esc(t.featured)}</span>` : ""}</h3>
${item.description ? `<p class="item-desc">${esc(item.description)}</p>` : ""}
<div class="item-meta"><span class="price">${esc(price)}</span>${available ? "" : ` <span class="badge sold">${esc(t.soldOut)}</span>`}</div>
${badges.length > 0 ? `<div class="badges">${badges.join("")}</div>` : ""}
</div></li>`;
}

function contactHtml(s: MenuSnapshot, t: MenuText): string {
  const c = s.profile.contact;
  const links: string[] = [];
  if (c.phone) {
    links.push(`<a class="act" href="tel:${esc(c.phone.replace(/[^+0-9]/g, ""))}">${esc(t.call)} <span class="num">${esc(c.phone)}</span></a>`);
  }
  const address = [c.address, c.city, c.postalCode].filter(Boolean).join(", ");
  const mapUrl = safeUrl(c.social?.googleMaps) ??
    (address ? `https://www.google.com/maps/search/?api=1&query=${encodeURIComponent(`${s.profile.name}, ${address}`)}` : null);
  if (mapUrl) links.push(`<a class="act" href="${esc(mapUrl)}" rel="noopener" target="_blank">${esc(t.map)}</a>`);
  if (c.email) links.push(`<a class="act" href="mailto:${esc(c.email)}">${esc(c.email)}</a>`);
  const web = safeUrl(c.website);
  if (web) links.push(`<a class="act" href="${esc(web)}" rel="noopener" target="_blank">${esc(t.website)}</a>`);
  for (const [k, v] of Object.entries(c.social ?? {})) {
    if (k === "googleMaps") continue;
    const url = safeUrl(v);
    if (url) links.push(`<a class="act" href="${esc(url)}" rel="noopener" target="_blank">${esc(t.social[k] ?? k)}</a>`);
  }
  const rows: string[] = [];
  if (address) rows.push(`<p class="addr">${esc(address)}</p>`);
  if (links.length > 0) rows.push(`<p class="acts">${links.join("")}</p>`);
  return rows.length > 0 ? `<div class="contact">${rows.join("")}</div>` : "";
}

function hoursHtml(s: MenuSnapshot, t: MenuText, now: Date | null): string {
  const h = s.profile.openingHours;
  if (!h) return "";
  const today = now ? localTime(now, s.timezone).day : null;
  const rows = WEEKDAYS.map((d) => {
    const cur = d === today ? " class=\"today\"" : "";
    return `<tr${cur}><th scope="row">${esc(t.days[d])}</th><td>${esc(formatDayHours(h[d] ?? "", t))}</td></tr>`;
  }).join("");
  return `<details class="hours"><summary>${esc(t.hours)}</summary><table><tbody>${rows}</tbody></table></details>`;
}

function openNowHtml(s: MenuSnapshot, t: MenuText, now: Date | null): string {
  if (!now) return "";
  const open = isOpenAt(s.profile.openingHours, s.timezone, now);
  if (open === null) return "";
  return `<p class="now ${open ? "is-open" : "is-closed"}"><span class="dot" aria-hidden="true"></span>${esc(open ? t.openNow : t.closedNow)}</p>`;
}

/**
 * The theme font from Google Fonts. On the public page it does not block
 * the first paint (LCP budget): the stylesheet starts as `media="print"` and
 * the inline script switches it on when loaded; `<noscript>` keeps it
 * without JavaScript. Text shows in the system font until then (`swap`).
 */
function fontLink(font: string, nonBlocking: boolean): string {
  if (!/^[A-Za-z ]{1,40}$/.test(font)) return "";
  const family = encodeURIComponent(font).replace(/%20/g, "+");
  const href = `https://fonts.googleapis.com/css2?family=${family}:wght@400;600;700&amp;display=swap`;
  const pre = "<link rel=\"preconnect\" href=\"https://fonts.googleapis.com\"><link rel=\"preconnect\" href=\"https://fonts.gstatic.com\" crossorigin>";
  if (!nonBlocking) return `${pre}<link rel="stylesheet" href="${href}">`;
  return `${pre}<link id="es-font" rel="stylesheet" href="${href}" media="print"><noscript><link rel="stylesheet" href="${href}"></noscript>`;
}

/** Shared base styles (also used by the state pages). */
export const BASE_CSS = `*{box-sizing:border-box}html{-webkit-text-size-adjust:100%}
body{margin:0;background:var(--es-background);color:var(--es-text);font-family:var(--es-font),system-ui,-apple-system,"Segoe UI",Roboto,sans-serif;line-height:1.5}
a{color:var(--es-accent)}:focus-visible{outline:3px solid var(--es-accent);outline-offset:2px}
.wrap{max-width:1200px;margin:0 auto;padding-inline:16px}
h1{margin:0;font-size:1.6rem;line-height:1.2;color:var(--es-text)}`;

const CSS = `${BASE_CSS}
@media (prefers-reduced-motion:no-preference){html{scroll-behavior:smooth}}
.skip{position:absolute;inset-inline-start:-999px;top:8px}.skip:focus{inset-inline-start:8px;background:var(--es-surface);color:var(--es-surface-text);padding:8px;z-index:20}
.draft{background:#1A1A1A;color:#fff;padding:10px 16px;font-size:14px;text-align:center}
.hero .cover{display:block;width:100%;height:180px;object-fit:cover}
.hero-main{display:flex;gap:16px;align-items:center;padding:16px 0 8px}
.logo{width:72px;height:72px;border-radius:16px;object-fit:cover;background:var(--es-surface);flex:none}
.desc{margin:4px 0 0;color:var(--es-muted-text)}
.now{margin:6px 0 0;font-weight:600;font-size:.95rem;display:flex;align-items:center;gap:6px}
.dot{width:10px;height:10px;border-radius:50%;border:2px solid currentColor}.is-open .dot{background:currentColor}
.contact{margin:0 0 4px}.addr{margin:0;color:var(--es-muted-text)}
.acts{margin:0;display:flex;flex-wrap:wrap;column-gap:16px}
.act{display:inline-flex;align-items:center;gap:4px;min-height:44px;font-weight:600}.num{font-weight:400}
.hours{margin:0 0 12px}.hours summary{cursor:pointer;color:var(--es-accent);font-weight:600;min-height:44px;display:flex;align-items:center}
.hours table{border-collapse:collapse}.hours th{text-align:start;font-weight:400;padding-block:2px;padding-inline:0 16px}.hours td{padding:2px 0}
.hours .today th,.hours .today td{font-weight:700}
.page{padding-bottom:8px}
.cats{position:sticky;top:0;z-index:5;background:var(--es-background);border-bottom:1px solid var(--es-border);margin-inline:-16px;padding-inline:16px}
.cats ul{position:relative;display:flex;gap:8px;list-style:none;margin:0;padding:10px 0;overflow-x:auto;scrollbar-width:none}
.cats a{display:inline-flex;align-items:center;min-height:44px;padding:0 16px;border-radius:999px;border:1px solid var(--es-border);background:var(--es-surface);color:var(--es-surface-text);text-decoration:none;white-space:nowrap}
.cats a[aria-current]{background:var(--es-primary);color:var(--es-on-primary);border-color:var(--es-primary);font-weight:600}
section{padding:16px 0 8px;scroll-margin-top:72px}
h2{margin:0 0 4px;font-size:1.3rem;color:var(--es-accent)}
.cat-desc{margin:0 0 8px;color:var(--es-muted-text)}
.items{list-style:none;margin:0;padding:0;display:grid;gap:12px;grid-template-columns:1fr}
.item{background:var(--es-surface);color:var(--es-surface-text);border:1px solid var(--es-border);border-radius:12px;overflow:hidden;display:flex;gap:12px;padding:12px}
.is-featured{border:2px solid var(--es-secondary)}
.zoom{display:block;flex:none;border-radius:8px;overflow:hidden;line-height:0}
.item-img{width:88px;height:88px;object-fit:cover}
.item-body{min-width:0;flex:1}
h3{margin:0;font-size:1.05rem;color:var(--es-surface-text)}
.item-desc{margin:4px 0;color:var(--es-muted-text);font-size:.95rem;overflow-wrap:anywhere}
.js .item-desc{display:-webkit-box;-webkit-line-clamp:3;line-clamp:3;-webkit-box-orient:vertical;overflow:hidden}
.js .item-desc.open{display:block}
.more{background:none;border:0;padding:0;margin:0 0 4px;color:var(--es-accent);font:inherit;font-weight:600;font-size:.9rem;cursor:pointer;min-height:32px;text-decoration:underline}
.item-meta{display:flex;gap:8px;align-items:center;flex-wrap:wrap;margin-top:4px}
.price{font-weight:700;color:var(--es-accent)}
.badge{display:inline-block;font-size:.75rem;font-weight:600;padding:2px 8px;border-radius:999px;vertical-align:middle}
.featured{background:var(--es-secondary);color:var(--es-on-secondary)}
.sold{background:var(--es-surface-text);color:var(--es-surface)}
.sold-out{border-style:dashed;border-color:var(--es-muted-text)}.sold-out .item-img{filter:grayscale(1)}.sold-out .price{color:var(--es-muted-text)}
.badges{display:flex;gap:6px;flex-wrap:wrap;margin-top:6px;font-size:.85rem}
.label,.tag{display:inline-flex;align-items:center;gap:4px;border:1px solid var(--es-border);border-radius:999px;padding:1px 8px}
.mark{width:14px;height:14px;flex:none}
.card-compact .zoom{display:none}
.card-image-top .item,.layout-grid .item{flex-direction:column}
.card-image-top .item-img,.layout-grid .item-img{width:100%;height:auto;aspect-ratio:4/3}
.empty{padding:32px 0;color:var(--es-muted-text)}
footer{padding:24px 0 32px;color:var(--es-muted-text);font-size:.85rem;text-align:center}
.lb{padding:0;border:0;margin:0;width:100%;height:100%;max-width:100%;max-height:100%;background:transparent;overflow:hidden}
.lb::backdrop{background:rgba(0,0,0,.88)}
.lb img{position:absolute;inset:0;margin:auto;max-width:100%;max-height:100%;object-fit:contain;transition:transform .15s}
.lb-close{position:absolute;top:8px;inset-inline-end:8px;z-index:1;width:48px;height:48px;border-radius:50%;border:0;background:#fff;color:#111;font-size:28px;line-height:1;cursor:pointer}
@media (min-width:600px){.items{grid-template-columns:repeat(2,1fr)}.hero .cover{height:240px}}
@media (min-width:1024px){.hero .cover{height:300px}
.page{display:grid;grid-template-columns:220px minmax(0,1fr);gap:32px;align-items:start}
.cats{top:0;margin:0;padding:16px 0;border:0;max-height:100vh;overflow-y:auto}
.cats ul{flex-direction:column;gap:4px;padding:0;overflow:visible}
.cats a{border-radius:8px;white-space:normal;width:100%;border-color:transparent;background:transparent;color:var(--es-text)}
.cats a[aria-current]{background:var(--es-primary);color:var(--es-on-primary)}
section{scroll-margin-top:16px}
.layout-grid .items{grid-template-columns:repeat(3,1fr)}}`;

/** The theme's CSS custom properties for `:root`. */
export function rootCss(theme: MenuSnapshot["theme"]["resolved"]): string {
  const vars = cssVariables({ ...theme, issues: [] } as ResolvedTheme);
  return Object.entries(vars)
    .map(([k, v]) => `${k}:${v}`)
    .concat(`--es-font:${JSON.stringify(theme.font.replace(/[^A-Za-z ]/g, ""))}`)
    .join(";");
}

/**
 * Renders the menu page for a snapshot.
 *
 * @param s The snapshot (published version or draft).
 * @param options Draft mode, availability overlay, SEO, scripts, branding.
 * @return A complete HTML document.
 */
export function renderMenuPage(s: MenuSnapshot, options: RenderOptions = {}): string {
  const t = menuText(s.locale);
  const theme = s.theme.resolved;
  const availability = options.availability ?? {};
  const isAvailable = (i: SnapshotItem) => availability[i.id] ?? i.available;
  const scripts = options.scripts ?? !options.draft;
  const now = options.draft ? null : options.now ?? new Date();

  const byCategory = new Map<string, SnapshotItem[]>();
  for (const i of s.items) {
    const list = byCategory.get(i.categoryId) ?? [];
    list.push(i);
    byCategory.set(i.categoryId, list);
  }
  // Categories without items are not shown.
  const categories = s.categories.filter((c) => (byCategory.get(c.id) ?? []).length > 0);
  const featured = s.items.filter((i) => i.featured);

  const nav = categories.length > 1
    ? `<nav class="cats" aria-label="${esc(t.categories)}"><ul>${categories
      .map((c, i) => `<li><a href="#${anchorId("c", c.id)}"${i === 0 ? " aria-current=\"true\"" : ""}>${esc(c.name)}</a></li>`)
      .join("")}</ul></nav>`
    : "";

  const sections = categories
    .map((c) => {
      const items = byCategory.get(c.id) ?? [];
      const id = anchorId("c", c.id);
      return `<section id="${id}" aria-labelledby="${id}-h"><h2 id="${id}-h">${esc(c.name)}</h2>${
        c.description ? `<p class="cat-desc">${esc(c.description)}</p>` : ""
      }<ul class="items">${items.map((i) => itemHtml(i, s, isAvailable(i), t)).join("")}</ul></section>`;
    })
    .join("\n");

  const featuredHtml = featured.length > 0 && categories.length > 0
    ? `<section id="featured" aria-labelledby="featured-h"><h2 id="featured-h">${esc(t.featured)}</h2><ul class="items">${featured
      .map((i) => itemHtml(i, s, isAvailable(i), t))
      .join("")}</ul></section>`
    : "";

  const p = s.profile;
  const robots = options.draft ? "<meta name=\"robots\" content=\"noindex,nofollow\">" : "";
  const seo = options.canonicalUrl && !options.draft ? seoHead(s, options.canonicalUrl, availability) : "";
  const bodyClass = `layout-${theme.layout} card-${theme.cardLayout} mode-${theme.mode}`;
  const data = [
    options.slug ? ` data-slug="${esc(options.slug)}"` : "",
    options.beacon ? ` data-beacon="${esc(options.beacon)}"` : "",
    scripts ? ` data-more="${esc(t.more)}" data-less="${esc(t.less)}" data-close="${esc(t.close)}"` : "",
  ].join("");

  return `<!DOCTYPE html>
<html lang="${esc(s.locale)}" dir="ltr">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>${esc(pageTitle(s))}</title>
${robots}
<meta name="color-scheme" content="${theme.mode === "dark" ? "dark" : "light"}">
<meta name="theme-color" content="${esc(theme.primary)}">
${scripts ? `<script>${HEAD_SCRIPT}</script>` : ""}
${fontLink(theme.font, scripts)}
<style>:root{${rootCss(theme)}}${CSS}</style>
${seo}
${options.headExtra ?? ""}
</head>
<body class="${esc(bodyClass)}"${data}>
<a class="skip" href="#menu">${esc(t.skip)}</a>
${options.draft ? `<div class="draft" role="note">${esc(t.previewBanner)}</div>` : ""}
<header class="hero">
${p.cover ? imgTag(p.cover, { sizes: "100vw", cls: "cover", eager: true }) : ""}
<div class="wrap">
<div class="hero-main">${p.logo ? imgTag(p.logo, { sizes: "72px", cls: "logo", alt: p.name, eager: true }) : ""}<div><h1>${esc(p.name)}</h1>${
    p.description ? `<p class="desc">${esc(p.description)}</p>` : ""
  }${openNowHtml(s, t, now)}</div></div>
${contactHtml(s, t)}
${hoursHtml(s, t, now)}
</div>
</header>
<div class="wrap page">
${nav}
<main id="menu">
${featuredHtml}
${sections || `<p class="empty">${esc(t.empty)}</p>`}
</main>
</div>
${options.branding === false ? "" : `<footer class="wrap">${esc(t.poweredBy)}</footer>`}
${scripts ? `<script>${BODY_SCRIPT}</script>` : ""}
${options.bodyExtra ?? ""}
</body>
</html>`;
}
