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
import { BODY_SCRIPT, HEAD_SCRIPT } from "./client-script";
import { formatPrice } from "./format";
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

/**
 * One dish as a compact row (many per screen): a small thumbnail, the name
 * and price on one line, a one-line description ("more" expands it) and one
 * line of small pills (dietary label, tags, featured, sold out).
 */
function itemHtml(item: SnapshotItem, s: MenuSnapshot, available: boolean, t: MenuText): string {
  const price = formatPrice(item.priceMinor, s.currency, s.locale);
  const pills: string[] = [];
  if (item.featured) pills.push(`<span class="badge featured">${esc(t.featured)}</span>`);
  if (!available) pills.push(`<span class="badge sold">${esc(t.soldOut)}</span>`);
  if (item.dietaryLabel) {
    pills.push(`<span class="label">${labelIcon(item.dietaryLabel)}${esc(item.dietaryLabel.name)}</span>`);
  }
  for (const tag of item.tags) pills.push(`<span class="tag">${esc(tag.name)}</span>`);
  const image = item.image
    ? zoomable(item.image, {
      sizes: "56px",
      cls: "item-img",
      dataAlt: item.name,
      label: `${t.enlarge} ${item.name}`,
    })
    : "";
  const cls = `item${available ? "" : " sold-out"}${image ? " has-img" : ""}${item.featured ? " is-featured" : ""}`;
  // Filter keys read by the page script (dietary label and tag ids).
  const filterData = (item.dietaryLabel ? ` data-d="${esc(item.dietaryLabel.id)}"` : "") +
    (item.tags.length > 0 ? ` data-t="${esc(item.tags.map((x) => x.id).join(" "))}"` : "");
  return `<li class="${cls}" data-id="${esc(item.id)}"${filterData}${available ? "" : " aria-disabled=\"true\""}>
${image}<div class="item-body">
<div class="item-head"><h3 class="item-name">${esc(item.name)}</h3><span class="price">${esc(price)}</span></div>
${item.description ? `<p class="item-desc">${esc(item.description)}</p>` : ""}
${pills.length > 0 ? `<div class="item-meta">${pills.join("")}</div>` : ""}
</div></li>`;
}

/** Three wisps of steam; their rise and fade is the `sp-steam` animation. */
const STEAM = `<g class="sp-steam" fill="none" stroke="currentColor" stroke-width="4" stroke-linecap="round">
<path d="M44 46c-6-8 6-12 0-22"/><path d="M60 42c-6-8 6-12 0-22"/><path d="M76 46c-6-8 6-12 0-22"/></g>`;

/** Steam rising over the logo plate. */
const WISPS_SVG = `<svg class="sp-wisps" viewBox="30 16 60 34" aria-hidden="true">${STEAM}</svg>`;

/** A bowl with rising steam, drawn in the card's colours (no logo). */
const BOWL_SVG = `<svg class="sp-bowl" viewBox="0 0 120 120" aria-hidden="true">
${STEAM}
<ellipse cx="60" cy="62" rx="44" ry="8" fill="var(--es-secondary)"/>
<circle cx="44" cy="58" r="6" fill="var(--es-surface)"/><circle cx="58" cy="55" r="7" fill="var(--es-surface)"/><circle cx="74" cy="58" r="6" fill="var(--es-surface)"/>
<path d="M14 62h92c0 26-20 42-46 42S14 88 14 62z" fill="var(--es-surface)"/>
<path d="M22 70h76" stroke="var(--es-secondary)" stroke-width="4" stroke-linecap="round"/>
<rect x="44" y="104" width="32" height="6" rx="3" fill="var(--es-surface)"/></svg>`;

/**
 * The opening splash: a 3D card that swings in with the logo on a steaming
 * plate (or a steaming bowl), the restaurant's name and "Menu", then fades out. CSS
 * only: it never blocks taps (`pointer-events:none`) or the page load, it
 * is decorative (`aria-hidden`), it shows once per tab session (see
 * HEAD_SCRIPT) and briefly and still for reduced motion.
 */
export function splashHtml(s: MenuSnapshot, t: MenuText): string {
  const p = s.profile;
  const plate = p.logo
    ? `${WISPS_SVG}<span class="sp-plate">${imgTag(p.logo, { sizes: "120px", cls: "sp-logo", eager: true })}</span>`
    : BOWL_SVG;
  return `<div class="splash" aria-hidden="true"><div class="sp-card">${plate}<p class="sp-name">${esc(p.name)}</p><p class="sp-sub">${esc(t.menu)}</p></div></div>`;
}

/**
 * Chips for the dietary labels and tags used on the menu. Within a group the
 * chips are alternatives; the groups narrow each other (the page script does
 * the filtering). A chip that every item has would filter nothing and is
 * left out; with no chips there is no bar. Rendered `hidden`: only the
 * script shows it, so the page without JavaScript never offers a dead control.
 */
export function filterBarHtml(items: SnapshotItem[], t: MenuText): string {
  const dietary = new Map<string, SnapshotLabel>();
  const tags = new Map<string, SnapshotLabel>();
  const tagCount = new Map<string, number>();
  for (const i of items) {
    if (i.dietaryLabel && !dietary.has(i.dietaryLabel.id)) dietary.set(i.dietaryLabel.id, i.dietaryLabel);
    for (const tag of i.tags) {
      if (!tags.has(tag.id)) tags.set(tag.id, tag);
      tagCount.set(tag.id, (tagCount.get(tag.id) ?? 0) + 1);
    }
  }
  const unlabelled = items.some((i) => !i.dietaryLabel);
  const chips: string[] = [];
  if (dietary.size > 1 || (dietary.size === 1 && unlabelled)) {
    for (const l of dietary.values()) {
      chips.push(`<li><button type="button" class="chip" aria-pressed="false" data-g="d" data-v="${esc(l.id)}">${labelIcon(l)}${esc(l.name)}</button></li>`);
    }
  }
  for (const tag of tags.values()) {
    if ((tagCount.get(tag.id) ?? 0) >= items.length) continue;
    chips.push(`<li><button type="button" class="chip" aria-pressed="false" data-g="t" data-v="${esc(tag.id)}">${esc(tag.name)}</button></li>`);
  }
  if (chips.length === 0) return "";
  return `<div class="filters" role="group" aria-label="${esc(t.filters)}" hidden><ul>${chips.join("")}<li><button type="button" class="chip clear" hidden>${esc(t.clearFilters)}</button></li></ul></div>
<p class="no-match" hidden>${esc(t.noMatch)}</p><p class="sr-only" role="status" data-shown="${esc(t.shown)}"></p>`;
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
[hidden]{display:none!important}
.splash{position:fixed;inset:0;z-index:50;display:grid;place-items:center;background:var(--es-background);perspective:900px;pointer-events:none;animation:sp-out .5s ease-in 1.5s forwards}
.no-splash .splash{display:none}
.sp-card{width:min(70vw,250px);aspect-ratio:3/4;border-radius:22px;background:var(--es-primary);color:var(--es-on-primary);display:flex;flex-direction:column;align-items:center;justify-content:center;gap:8px;padding:20px;text-align:center;box-shadow:0 34px 60px -24px rgba(0,0,0,.5),inset 0 0 0 6px rgba(255,255,255,.12);transform-style:preserve-3d;animation:sp-in 1.1s cubic-bezier(.2,.8,.2,1) both}
.sp-plate{display:grid;place-items:center;width:132px;height:132px;border-radius:50%;background:var(--es-surface);box-shadow:0 0 0 8px var(--es-secondary),0 14px 24px -10px rgba(0,0,0,.45);transform:translateZ(40px);animation:sp-plate 1.1s cubic-bezier(.2,.8,.2,1) both}
.sp-logo{width:96px;height:96px;border-radius:50%;object-fit:cover}
.sp-bowl{width:128px;height:128px;transform:translateZ(40px)}
.sp-wisps{width:84px;height:48px;margin-bottom:-6px;transform:translateZ(40px)}
.sp-steam path{animation:sp-steam 1.4s ease-in-out infinite}.sp-steam path:nth-child(2){animation-delay:.25s}.sp-steam path:nth-child(3){animation-delay:.5s}
.sp-name{margin:8px 0 0;font-size:1.3rem;font-weight:700;line-height:1.2;overflow-wrap:anywhere;transform:translateZ(24px)}
.sp-sub{margin:0;font-size:.8rem;letter-spacing:.3em;text-transform:uppercase;opacity:.85;transform:translateZ(16px)}
@keyframes sp-in{0%{transform:rotateY(-75deg) rotateX(20deg) translateZ(-220px);opacity:0}60%{transform:rotateY(10deg) rotateX(-4deg) translateZ(24px);opacity:1}100%{transform:none;opacity:1}}
@keyframes sp-plate{0%{transform:translateZ(40px) rotate(-120deg) scale(.6)}100%{transform:translateZ(40px) rotate(0) scale(1)}}
@keyframes sp-steam{0%{transform:translateY(6px);opacity:0}50%{opacity:.9}100%{transform:translateY(-10px);opacity:0}}
@keyframes sp-out{to{opacity:0;visibility:hidden}}
@media (prefers-reduced-motion:reduce){.sp-card,.sp-plate,.sp-steam path{animation:none}.splash{animation-duration:.2s;animation-delay:.6s}}
.sr-only{position:absolute;width:1px;height:1px;overflow:hidden;clip:rect(0 0 0 0);white-space:nowrap}
.filters ul{display:flex;gap:8px;list-style:none;margin:0;padding:12px 0 4px;overflow-x:auto;scrollbar-width:none}
.chip{display:inline-flex;align-items:center;gap:6px;min-height:44px;padding:0 14px;border-radius:999px;border:1px solid var(--es-border);background:var(--es-surface);color:var(--es-surface-text);font:inherit;font-size:.9rem;white-space:nowrap;cursor:pointer}
.chip[aria-pressed=true]{background:var(--es-primary);color:var(--es-on-primary);border-color:var(--es-primary);font-weight:600}
.chip.clear{background:none;border-color:transparent;color:var(--es-accent);text-decoration:underline}
.no-match{padding:24px 0;color:var(--es-muted-text)}
.skip{position:absolute;inset-inline-start:-999px;top:8px}.skip:focus{inset-inline-start:8px;background:var(--es-surface);color:var(--es-surface-text);padding:8px;z-index:20}
.draft{background:#1A1A1A;color:#fff;padding:10px 16px;font-size:14px;text-align:center}
.hero{position:relative;background:#1A1A1A;color:#fff}
.hero .cover{display:block;width:100%;height:180px;object-fit:cover}
.hero-band{position:absolute;inset:auto 0 0;padding:40px 0 14px;background:linear-gradient(rgba(0,0,0,0),rgba(0,0,0,.7))}
.hero-main{display:flex;gap:12px;align-items:center}
.hero h1{margin:0;font-size:1.5rem;line-height:1.2;color:#fff;text-shadow:0 1px 3px rgba(0,0,0,.6);overflow-wrap:anywhere}
.no-cover{background:var(--es-primary);color:var(--es-on-primary)}
.no-cover .hero-band{position:static;background:none;padding:20px 0}
.no-cover h1{color:var(--es-on-primary);text-shadow:none}
.logo{width:64px;height:64px;border-radius:14px;object-fit:cover;background:var(--es-surface);border:2px solid #fff;flex:none}
.page{padding-bottom:8px}
.cats{position:sticky;top:0;z-index:5;background:var(--es-background);border-bottom:1px solid var(--es-border);margin-inline:-16px;padding-inline:16px}
.cats ul{position:relative;display:flex;gap:8px;list-style:none;margin:0;padding:10px 0;overflow-x:auto;scrollbar-width:none}
.cats a{display:inline-flex;align-items:center;min-height:44px;padding:0 16px;border-radius:999px;border:1px solid var(--es-border);background:var(--es-surface);color:var(--es-surface-text);text-decoration:none;white-space:nowrap}
.cats a[aria-current]{background:var(--es-primary);color:var(--es-on-primary);border-color:var(--es-primary);font-weight:600}
section{padding:12px 0 4px;scroll-margin-top:72px}
h2{margin:0 0 6px;font-size:1.15rem;color:var(--es-accent)}
.cat-desc{margin:0 0 6px;color:var(--es-muted-text);font-size:.9rem}
.items{list-style:none;margin:0;padding:0;display:grid;grid-template-columns:1fr;background:var(--es-surface);color:var(--es-surface-text);border-radius:12px;overflow:hidden}
.item{display:flex;gap:10px;align-items:flex-start;padding:8px 12px;border-bottom:1px solid var(--es-border)}
.item:last-child{border-bottom:0}
.is-featured{box-shadow:inset 3px 0 0 var(--es-secondary)}
.zoom{display:block;flex:none;border-radius:6px;overflow:hidden;line-height:0}
.item-img{width:56px;height:56px;object-fit:cover}
.item-body{min-width:0;flex:1}
.item-head{display:flex;gap:8px;align-items:baseline;justify-content:space-between}
h3{margin:0;font-size:1rem;line-height:1.3;color:var(--es-surface-text)}
.item-desc{margin:2px 0 0;color:var(--es-muted-text);font-size:.875rem;line-height:1.35;overflow-wrap:anywhere}
.js .item-desc{display:-webkit-box;-webkit-line-clamp:1;line-clamp:1;-webkit-box-orient:vertical;overflow:hidden}
.js .item-desc.open{display:block}
.more{background:none;border:0;padding:0 2px;margin:0;margin-inline-start:auto;color:var(--es-accent);font:inherit;font-weight:600;font-size:.8rem;cursor:pointer;min-height:24px;text-decoration:underline}
.item-meta{display:flex;gap:4px 6px;align-items:center;flex-wrap:wrap;margin-top:4px;font-size:.75rem}
.price{font-weight:700;color:var(--es-accent);white-space:nowrap}
.badge{display:inline-block;font-size:.7rem;font-weight:600;padding:1px 6px;border-radius:999px}
.featured{background:var(--es-secondary);color:var(--es-on-secondary)}
.sold{background:var(--es-surface-text);color:var(--es-surface)}
.sold-out .item-img{filter:grayscale(1)}.sold-out .price,.sold-out h3{color:var(--es-muted-text)}
.label,.tag{display:inline-flex;align-items:center;gap:3px;border:1px solid var(--es-border);border-radius:999px;padding:0 6px;line-height:1.5}
.mark{width:12px;height:12px;flex:none}
.card-compact .zoom{display:none}
.empty{padding:32px 0;color:var(--es-muted-text)}
footer{padding:24px 0 32px;color:var(--es-muted-text);font-size:.85rem;text-align:center}footer a{color:inherit;display:inline-block;padding:12px 4px}
.lb{padding:0;border:0;margin:0;width:100%;height:100%;max-width:100%;max-height:100%;background:transparent;overflow:hidden}
.lb::backdrop{background:rgba(0,0,0,.88)}
.lb img{position:absolute;inset:0;margin:auto;max-width:100%;max-height:100%;object-fit:contain;transition:transform .15s}
.lb-close{position:absolute;top:8px;inset-inline-end:8px;z-index:1;width:48px;height:48px;border-radius:50%;border:0;background:#fff;color:#111;font-size:28px;line-height:1;cursor:pointer}
@media (min-width:600px){.items{grid-template-columns:repeat(2,1fr);column-gap:0}.item:nth-child(odd){border-inline-end:1px solid var(--es-border)}.item:nth-last-child(2):nth-child(odd){border-bottom:0}.hero .cover{height:240px}}
@media (min-width:1024px){.hero .cover{height:300px}
.page{display:grid;grid-template-columns:220px minmax(0,1fr);gap:32px;align-items:start}
.cats{top:0;margin:0;padding:16px 0;border:0;max-height:100vh;overflow-y:auto}
.cats ul{flex-direction:column;gap:4px;padding:0;overflow:visible}
.cats a{border-radius:8px;white-space:normal;width:100%;border-color:transparent;background:transparent;color:var(--es-text)}
.cats a[aria-current]{background:var(--es-primary);color:var(--es-on-primary)}
section{scroll-margin-top:16px}}`;

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

  const byCategory = new Map<string, SnapshotItem[]>();
  for (const i of s.items) {
    const list = byCategory.get(i.categoryId) ?? [];
    list.push(i);
    byCategory.set(i.categoryId, list);
  }
  // Categories without items are not shown.
  const categories = s.categories.filter((c) => (byCategory.get(c.id) ?? []).length > 0);
  const featured = s.items.filter((i) => i.featured);
  const filters = scripts ? filterBarHtml(categories.flatMap((c) => byCategory.get(c.id) ?? []), t) : "";

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
${scripts ? splashHtml(s, t) : ""}
<a class="skip" href="#menu">${esc(t.skip)}</a>
${options.draft ? `<div class="draft" role="note">${esc(t.previewBanner)}</div>` : ""}
<header class="hero${p.cover ? "" : " no-cover"}">
${p.cover ? imgTag(p.cover, { sizes: "100vw", cls: "cover", eager: true }) : ""}
<div class="hero-band"><div class="wrap hero-main">${p.logo ? imgTag(p.logo, { sizes: "64px", cls: "logo", alt: p.name, eager: true }) : ""}<h1>${esc(p.name)}</h1></div></div>
</header>
<div class="wrap page">
${nav}
<main id="menu">
${filters}
${featuredHtml}
${sections || `<p class="empty">${esc(t.empty)}</p>`}
</main>
</div>
<footer class="wrap">${options.branding === false ? "" : `${esc(t.poweredBy)} · `}<a href="/privacy">${esc(t.privacy)}</a> · <a href="/terms">${esc(t.terms)}</a></footer>
${scripts ? `<script>${BODY_SCRIPT}</script>` : ""}
${options.bodyExtra ?? ""}
</body>
</html>`;
}
