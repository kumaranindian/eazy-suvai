# M07 – Public digital menu

Status: Not started
Started:
Completed:

## Goal

Customers scan the QR code and get a fast, readable, mobile-first menu with no app and no login. The page is server-rendered HTML, cached at the CDN, and correct for every account state.

## FRD coverage

FR-034 to FR-046, FR-048 (redirect), FR-070 (link preview), FR-093 (old-slug redirects), FR-099, BR-007, BR-010, BR-015, §7.1, §7.6, AC-006 (display), AC-007 (display), AC-008, AC-009, AC-012, AC-019, AC-023, AC-024, AC-029 (display).

## Depends on

M06.

## Inputs from other modules

- M00 (done 2026-11-14): the `menu` Hosting target in `firebase.json` serves the placeholder `hosting/menu/`. Replace it with a `**` rewrite to `renderMenu` (asia-south1). Apply the AA text-colour rule from architecture §6.
- M06: `versions/{n}` snapshot shape and `publishedVersion`.
- M04: `live/availability` overlay.
- M03: `slugs/{slug}` with `current` flag; `qrCodes/{code}`.
- M02 (done 2026-11-14): renditions are `…/w320.webp`, `w640`, `w1280` (WebP; never enlarged, so a small original gives smaller files). Each has a `firebaseStorageDownloadTokens` value and `Cache-Control: public, max-age=31536000, immutable`, so `renderMenu` can build public URLs with the Admin SDK's `getDownloadURL()` and use them in `srcset` (`320w, 640w, 1280w`). Storage rules do not allow anonymous reads; the token URLs are the public path. Choose the CDN approach (token URLs vs. a Hosting proxy) here.

## Scope

**In:** `renderMenu` HTTPS function, Hosting rewrites for the `menu` site, HTML/CSS templates, small vanilla JS (category nav, image lightbox, analytics beacon hook), all account-state pages, SEO tags, sitemap, robots.
**Out:** analytics collection endpoint (M09; this module adds the beacon call), QR image generation (M08).

## Page design

- **Header:** cover image (if set), logo, name, description, enabled contact details, opening hours with "Open now / Closed" in the restaurant's time zone, tap-to-call and map link if visible.
- **Category bar:** horizontal, sticky at the top, scrolls to the category and highlights the one in view (IntersectionObserver). On ≥ 1024 px it becomes a left sidebar.
- **Items:** layout from the theme (`list` or `grid`, card style). Each item: image (lazy, `srcset`), name, description (clamped to 3 lines with "more"), price formatted with `Intl.NumberFormat` server-side, dietary icon + text, tags, featured badge. Unavailable items stay listed, dimmed, labelled "Currently unavailable", with `aria-disabled`.
- **Featured section** at the top when any items are featured.
- **Lightbox:** tap an image to enlarge; close button, Escape key and swipe down.
- **Footer:** "Powered by EazySuvai" on the Free plan, hidden on Pro (`limits.removeBranding`). This is an open decision in the master plan; build it behind the plan flag so it can be turned off.
- **Responsive:** single column < 600 px; two-column grid 600–1023 px; sidebar + three-column grid ≥ 1024 px, content max 1200 px.
- **Accessibility:** semantic headings (`h1` restaurant, `h2` categories, `h3` items), skip link, focus styles, 4.5:1 contrast after the theme fix, `lang` attribute.

## Account states (FR-099)

| State | HTTP | Page | Indexing |
| --- | --- | --- | --- |
| Active, published | 200 | Menu | index |
| Active, never published | 404 | "Menu coming soon" with restaurant name | noindex |
| Suspended | 503 | "Menu temporarily unavailable" | noindex |
| Deactivated or deleted | 410 | "Menu no longer available" | noindex, not in sitemap |
| Unknown slug | 404 | Generic not-found page | noindex |

## SEO

Title "{Name} – Menu | EazySuvai", meta description from the restaurant description, canonical URL, Open Graph and Twitter tags with the cover or logo, JSON-LD `Restaurant` with `hasMenu` → `Menu` → `MenuSection` → `MenuItem` with `offers.price` and `priceCurrency`. `sitemap.xml` lists active published menus with `lastmod` = `publishedAt`.

## Tasks

- [ ] Hosting site `menu` with rewrites to `renderMenu`; `/q/**` and `/{slug}` routing.
- [ ] Data loader: slug → restaurant → version → availability overlay; old slug → 301.
- [ ] HTML templates with escaping, theme CSS variables, critical CSS inline, total JS ≤ 10 KB.
- [ ] Price and opening-hours formatting with the restaurant's locale, currency and time zone.
- [ ] All account-state pages.
- [ ] SEO tags, JSON-LD, sitemap, robots.
- [ ] Cache headers (`s-maxage=60`), ETag.
- [ ] Lightbox and category navigation scripts (progressive enhancement: page works without JS).
- [ ] Lighthouse CI budget: LCP ≤ 2.5 s on simulated 4G, initial payload ≤ 150 KB, accessibility score ≥ 95.

## Acceptance checks

- [ ] AC-008: opens without login.
- [ ] AC-009: correct on Android Chrome, iPhone Safari, a tablet and desktop browsers.
- [ ] AC-012: branding and theme visible.
- [ ] AC-019: title, description, Open Graph, JSON-LD and sitemap entry present.
- [ ] AC-023: an old slug answers 301 to the current one.
- [ ] AC-024: each FR-099 state returns the right page and HTTP code.
- [ ] Availability change visible within 60 s; KWD prices show 3 decimals.
- [ ] No draft or admin data appears in the HTML (FR-045).

## Tests

Jest snapshot tests of the templates for each state; data loader tests; HTML validation; Lighthouse CI on the emulator; manual check on 2 real phones.

## Completion notes

_Fill in when done._

## Open items

## Change log

- 2026-11-14: Plan created.
