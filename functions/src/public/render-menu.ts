/**
 * Renders a menu snapshot as one HTML page (architecture §3).
 *
 * M06 uses it for the owner's draft preview (`draft: true`: a "Preview"
 * banner and `noindex`). M07's `renderMenu` serves the published version
 * with the same function and adds SEO tags, JSON-LD, the category script,
 * the lightbox and the analytics beacon, so the preview and the public
 * page never drift apart.
 *
 * Everything is escaped. Colours come only from the contrast-fixed theme
 * (`snapshot.theme.resolved`, FR-060). Sold-out items are never dimmed
 * with opacity (it breaks AA); they get a badge (M05 note).
 */
import { cssVariables, type ResolvedTheme } from "../theme";
import type { MenuSnapshot, SnapshotImage, SnapshotItem, SnapshotLabel, Weekday } from "../publishing/snapshot";
import { WEEKDAYS } from "../publishing/snapshot";
import { formatDayHours, formatPrice } from "./format";
import { anchorId, esc, safeUrl } from "./html";

/** Customer-facing words. English in the MVP (FRD §6.3); M07 may localize. */
export const MENU_TEXT = {
  menu: "Menu",
  skip: "Skip to menu",
  categories: "Categories",
  featured: "Featured",
  soldOut: "Sold out",
  closed: "Closed",
  allDay: "Open 24 hours",
  hours: "Opening hours",
  call: "Call",
  email: "Email",
  website: "Website",
  map: "Map",
  poweredBy: "Powered by EazySuvai",
  previewBanner: "Preview – this is your unpublished draft. Customers can't see it yet.",
  empty: "This menu has no items yet.",
  days: { mon: "Monday", tue: "Tuesday", wed: "Wednesday", thu: "Thursday", fri: "Friday", sat: "Saturday", sun: "Sunday" } as Record<Weekday, string>,
  social: { instagram: "Instagram", facebook: "Facebook", x: "X", youtube: "YouTube", googleMaps: "Google Maps" } as Record<string, string>,
};

export interface RenderOptions {
  /** Draft preview: banner and `noindex` (FR-061, FR-062). */
  draft?: boolean;
  /** `live/availability.items`, laid over the snapshot (FR-095). */
  availability?: Record<string, boolean>;
  /** Show "Powered by EazySuvai" (Free plan; M07/M10 decide). */
  branding?: boolean;
  /** Extra tags for `<head>` (M07: canonical, Open Graph, JSON-LD). Must be safe HTML. */
  headExtra?: string;
  /** Extra HTML before `</body>` (M07: scripts). Must be safe HTML. */
  bodyExtra?: string;
}

function imgTag(image: SnapshotImage, sizes: string, cls: string, alt = ""): string {
  const urls = [image.w320, image.w640, image.w1280].map(safeUrl);
  if (urls.some((u) => u === null)) return "";
  const [a, b, c] = urls as string[];
  const dims = image.width > 0 && image.height > 0 ? ` width="${image.width}" height="${image.height}"` : "";
  return `<img class="${cls}" src="${esc(b)}" srcset="${esc(a)} 320w, ${esc(b)} 640w, ${esc(c)} 1280w" sizes="${esc(sizes)}"${dims} loading="lazy" decoding="async" alt="${esc(alt)}">`;
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

function itemHtml(item: SnapshotItem, s: MenuSnapshot, available: boolean): string {
  const price = formatPrice(item.priceMinor, s.currency, s.locale);
  const badges: string[] = [];
  if (item.dietaryLabel) {
    badges.push(`<span class="label">${labelIcon(item.dietaryLabel)}${esc(item.dietaryLabel.name)}</span>`);
  }
  for (const t of item.tags) badges.push(`<span class="tag">${esc(t.name)}</span>`);
  const image = item.image ? imgTag(item.image, "(min-width: 1024px) 320px, (min-width: 600px) 40vw, 88px", "item-img") : "";
  return `<li class="item${available ? "" : " sold-out"}${image ? " has-img" : ""}"${available ? "" : " aria-disabled=\"true\""}>
${image}<div class="item-body">
<h3 class="item-name">${esc(item.name)}${item.featured ? ` <span class="badge featured">${esc(MENU_TEXT.featured)}</span>` : ""}</h3>
${item.description ? `<p class="item-desc">${esc(item.description)}</p>` : ""}
<div class="item-meta"><span class="price">${esc(price)}</span>${available ? "" : ` <span class="badge sold">${esc(MENU_TEXT.soldOut)}</span>`}</div>
${badges.length > 0 ? `<div class="badges">${badges.join("")}</div>` : ""}
</div></li>`;
}

function contactHtml(s: MenuSnapshot): string {
  const c = s.profile.contact;
  const rows: string[] = [];
  if (c.phone) rows.push(`<li><a href="tel:${esc(c.phone.replace(/[^+0-9]/g, ""))}">${esc(MENU_TEXT.call)}: ${esc(c.phone)}</a></li>`);
  if (c.email) rows.push(`<li><a href="mailto:${esc(c.email)}">${esc(c.email)}</a></li>`);
  const address = [c.address, c.city, c.postalCode].filter(Boolean).join(", ");
  if (address) rows.push(`<li>${esc(address)}</li>`);
  const links: string[] = [];
  const web = safeUrl(c.website);
  if (web) links.push(`<a href="${esc(web)}" rel="noopener" target="_blank">${esc(MENU_TEXT.website)}</a>`);
  for (const [k, v] of Object.entries(c.social ?? {})) {
    const url = safeUrl(v);
    if (url) links.push(`<a href="${esc(url)}" rel="noopener" target="_blank">${esc(MENU_TEXT.social[k] ?? k)}</a>`);
  }
  if (links.length > 0) rows.push(`<li class="links">${links.join(" · ")}</li>`);
  return rows.length > 0 ? `<ul class="contact">${rows.join("")}</ul>` : "";
}

function hoursHtml(s: MenuSnapshot): string {
  const h = s.profile.openingHours;
  if (!h) return "";
  const rows = WEEKDAYS.map(
    (d) => `<tr><th scope="row">${esc(MENU_TEXT.days[d])}</th><td>${esc(formatDayHours(h[d] ?? "", MENU_TEXT))}</td></tr>`,
  ).join("");
  return `<details class="hours"><summary>${esc(MENU_TEXT.hours)}</summary><table>${rows}</table></details>`;
}

function fontLink(font: string): string {
  if (!/^[A-Za-z ]{1,40}$/.test(font)) return "";
  const family = encodeURIComponent(font).replace(/%20/g, "+");
  return `<link rel="preconnect" href="https://fonts.googleapis.com"><link rel="preconnect" href="https://fonts.gstatic.com" crossorigin><link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=${family}:wght@400;600;700&amp;display=swap">`;
}

const CSS = `*{box-sizing:border-box}html{-webkit-text-size-adjust:100%}
body{margin:0;background:var(--es-background);color:var(--es-text);font-family:var(--es-font),system-ui,-apple-system,"Segoe UI",Roboto,sans-serif;line-height:1.5}
a{color:var(--es-accent)}a:focus-visible,summary:focus-visible{outline:3px solid var(--es-accent);outline-offset:2px}
.skip{position:absolute;left:-999px}.skip:focus{left:8px;top:8px;background:var(--es-surface);color:var(--es-surface-text);padding:8px;z-index:10}
.draft{background:#1A1A1A;color:#fff;padding:10px 16px;font-size:14px;text-align:center}
.wrap{max-width:1200px;margin:0 auto;padding:0 16px}
.hero .cover{display:block;width:100%;height:180px;object-fit:cover}
.hero-main{display:flex;gap:16px;align-items:center;padding:16px 0}
.logo{width:72px;height:72px;border-radius:16px;object-fit:cover;background:var(--es-surface);flex:none}
h1{margin:0;font-size:1.6rem;line-height:1.2;color:var(--es-text)}
.desc{margin:4px 0 0;color:var(--es-muted-text)}
.contact{list-style:none;margin:0 0 8px;padding:0;font-size:.95rem}.contact li{padding:2px 0}
.hours{margin:0 0 12px}.hours summary{cursor:pointer;color:var(--es-accent);font-weight:600;min-height:44px;display:flex;align-items:center}
.hours table{border-collapse:collapse}.hours th{text-align:start;font-weight:400;padding:2px 16px 2px 0}.hours td{padding:2px 0}
.cats{position:sticky;top:0;z-index:5;background:var(--es-background);border-bottom:1px solid var(--es-border)}
.cats ul{display:flex;gap:8px;list-style:none;margin:0;padding:10px 0;overflow-x:auto}
.cats a{display:inline-flex;align-items:center;min-height:44px;padding:0 16px;border-radius:999px;border:1px solid var(--es-border);background:var(--es-surface);color:var(--es-surface-text);text-decoration:none;white-space:nowrap}
.cats li:first-child a{background:var(--es-primary);color:var(--es-on-primary);border-color:var(--es-primary)}
section{padding:16px 0 8px;scroll-margin-top:72px}
h2{margin:0 0 4px;font-size:1.3rem;color:var(--es-accent)}
.cat-desc{margin:0 0 8px;color:var(--es-muted-text)}
.items{list-style:none;margin:0;padding:0;display:grid;gap:12px;grid-template-columns:1fr}
.item{background:var(--es-surface);color:var(--es-surface-text);border:1px solid var(--es-border);border-radius:12px;overflow:hidden;display:flex;gap:12px;padding:12px}
.item-img{width:88px;height:88px;object-fit:cover;border-radius:8px;flex:none}
.item-body{min-width:0;flex:1}
h3{margin:0;font-size:1.05rem;color:var(--es-surface-text)}
.item-desc{margin:4px 0;color:var(--es-muted-text);font-size:.95rem;display:-webkit-box;-webkit-line-clamp:3;-webkit-box-orient:vertical;overflow:hidden}
.item-meta{display:flex;gap:8px;align-items:center;flex-wrap:wrap;margin-top:4px}
.price{font-weight:700;color:var(--es-accent)}
.badge{display:inline-block;font-size:.75rem;font-weight:600;padding:2px 8px;border-radius:999px;vertical-align:middle}
.featured{background:var(--es-secondary);color:var(--es-on-secondary)}
.sold{background:var(--es-surface-text);color:var(--es-surface)}
.badges{display:flex;gap:6px;flex-wrap:wrap;margin-top:6px;font-size:.85rem}
.label,.tag{display:inline-flex;align-items:center;gap:4px;border:1px solid var(--es-border);border-radius:999px;padding:1px 8px}
.mark{width:14px;height:14px;flex:none}
.card-compact .item-img{display:none}
.card-image-top .item{flex-direction:column}.card-image-top .item-img{width:100%;height:auto;aspect-ratio:4/3}
.empty{padding:32px 0;color:var(--es-muted-text)}
footer{padding:24px 0 32px;color:var(--es-muted-text);font-size:.85rem;text-align:center}
@media (min-width:600px){.layout-grid .items{grid-template-columns:repeat(2,1fr)}.layout-grid .item{flex-direction:column}.layout-grid .item-img{width:100%;height:auto;aspect-ratio:4/3}.hero .cover{height:240px}}
@media (min-width:1024px){.layout-grid .items{grid-template-columns:repeat(3,1fr)}.layout-list .items{grid-template-columns:repeat(2,1fr)}.hero .cover{height:300px}}`;

/**
 * Renders the menu page for a snapshot.
 *
 * @param s The snapshot (published version or draft).
 * @param options Draft mode, availability overlay, branding and extras.
 * @return A complete HTML document.
 */
export function renderMenuPage(s: MenuSnapshot, options: RenderOptions = {}): string {
  const theme = s.theme.resolved;
  const vars = cssVariables({ ...theme, issues: [] } as ResolvedTheme);
  const rootCss = Object.entries(vars)
    .map(([k, v]) => `${k}:${v}`)
    .concat(`--es-font:${JSON.stringify(theme.font.replace(/[^A-Za-z ]/g, ""))}`)
    .join(";");
  const availability = options.availability ?? {};
  const isAvailable = (i: SnapshotItem) => availability[i.id] ?? i.available;

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
    ? `<nav class="cats" aria-label="${esc(MENU_TEXT.categories)}"><div class="wrap"><ul>${categories
      .map((c) => `<li><a href="#${anchorId("c", c.id)}">${esc(c.name)}</a></li>`)
      .join("")}</ul></div></nav>`
    : "";

  const sections = categories
    .map((c) => {
      const items = byCategory.get(c.id) ?? [];
      const id = anchorId("c", c.id);
      return `<section id="${id}" aria-labelledby="${id}-h"><h2 id="${id}-h">${esc(c.name)}</h2>${
        c.description ? `<p class="cat-desc">${esc(c.description)}</p>` : ""
      }<ul class="items">${items.map((i) => itemHtml(i, s, isAvailable(i))).join("")}</ul></section>`;
    })
    .join("\n");

  const featuredHtml = featured.length > 0 && categories.length > 0
    ? `<section id="featured" aria-labelledby="featured-h"><h2 id="featured-h">${esc(MENU_TEXT.featured)}</h2><ul class="items">${featured
      .map((i) => itemHtml(i, s, isAvailable(i)))
      .join("")}</ul></section>`
    : "";

  const p = s.profile;
  const robots = options.draft ? "<meta name=\"robots\" content=\"noindex,nofollow\">" : "";
  const bodyClass = `layout-${theme.layout} card-${theme.cardLayout} mode-${theme.mode}`;

  return `<!doctype html>
<html lang="${esc(s.locale)}" dir="ltr">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>${esc(p.name)} – ${esc(MENU_TEXT.menu)}</title>
${robots}
<meta name="color-scheme" content="${theme.mode === "dark" ? "dark" : "light"}">
${fontLink(theme.font)}
<style>:root{${rootCss}}${CSS}</style>
${options.headExtra ?? ""}
</head>
<body class="${esc(bodyClass)}">
<a class="skip" href="#menu">${esc(MENU_TEXT.skip)}</a>
${options.draft ? `<div class="draft" role="note">${esc(MENU_TEXT.previewBanner)}</div>` : ""}
<header class="hero">
${p.cover ? imgTag(p.cover, "100vw", "cover") : ""}
<div class="wrap">
<div class="hero-main">${p.logo ? imgTag(p.logo, "72px", "logo", p.name) : ""}<div><h1>${esc(p.name)}</h1>${
    p.description ? `<p class="desc">${esc(p.description)}</p>` : ""
  }</div></div>
${contactHtml(s)}
${hoursHtml(s)}
</div>
</header>
${nav}
<main id="menu" class="wrap">
${featuredHtml}
${sections || `<p class="empty">${esc(MENU_TEXT.empty)}</p>`}
</main>
${options.branding === false ? "" : `<footer class="wrap">${esc(MENU_TEXT.poweredBy)}</footer>`}
${options.bodyExtra ?? ""}
</body>
</html>`;
}
