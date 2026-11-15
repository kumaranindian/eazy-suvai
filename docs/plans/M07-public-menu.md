# M07 – Public digital menu

Status: Done
Started: 2026-11-15
Completed: 2026-11-15

## Goal

Customers scan the QR code and get a fast, readable, mobile-first menu with no app and no login. The page is server-rendered HTML, cached at the CDN, and correct for every account state.

## FRD coverage

FR-034 to FR-046, FR-048 (redirect), FR-070 (link preview), FR-093 (old-slug redirects), FR-099, BR-007, BR-010, BR-015, §7.1, §7.6, AC-006 (display), AC-007 (display), AC-008, AC-009, AC-012, AC-019, AC-023, AC-024, AC-029 (display).

## Depends on

M06.

## Inputs from other modules

- M00 (done 2026-11-14): the `menu` Hosting target in `firebase.json` serves the placeholder `hosting/menu/`. Replace it with a `**` rewrite to `renderMenu` (asia-south1). Apply the AA text-colour rule from architecture §6.
- M06 (done 2026-11-15):
  - Read `restaurants/{rid}.publishedVersion`, then the immutable `versions/{n}` (field `snapshot`; exact shape in the master plan's Cross-module notes), then `live/availability`. Publishing switches the pointer in one transaction, and the last 10 versions are kept, so this read order never sees a mix (AC-022).
  - Render with the existing `renderMenuPage(snapshot, {availability, branding, headExtra, bodyExtra})` in `functions/src/public/render-menu.ts`; the owner preview calls it with `draft: true`. Extend it (canonical, Open Graph and JSON-LD through `headExtra`; the category script, lightbox and beacon through `bodyExtra`; account-state pages next to it) rather than writing a second template.
  - Theme: use `snapshot.theme.resolved` (already contrast-fixed; `cssVariables({...resolved, issues: []})`).
  - Images: `{width, height, w320, w640, w1280}` with public token URLs (`firebasestorage.googleapis.com/v0/b/…?alt=media&token=…`; the Storage emulator host in tests). The token-URL vs. Hosting-proxy choice is still yours; only `storageUrlResolver` in `functions/src/publishing/draft-reader.ts` builds them.
  - Prices: `formatPrice(minor, currency, locale)` in `functions/src/public/format.ts` (exact, KWD with 3 decimals). Hours: `formatDayHours()`.
  - Draft-only fields never reach the snapshot (FR-045). Never read `versions/{n}/private/source`: it holds the full draft.
  - Empty categories can be in the snapshot; the renderer skips them.
  - `publishedAt` is on the root and on each version (for `sitemap.xml` `lastmod`).
- M05 (done 2026-11-14): style the page with `resolveTheme(tokens, settings)` and `cssVariables()` from `functions/src/theme` (never re-implement the contrast rules: the Dart copy and the TS copy are tested against `functions/src/theme/contrast-cases.json`). CSS custom properties: `--es-primary`, `--es-on-primary`, `--es-secondary`, `--es-on-secondary`, `--es-background`, `--es-surface`, `--es-text` (body text on the background), `--es-surface-text` (text on cards), `--es-muted-text` (descriptions; AA on both), `--es-accent` (primary used as text: headings, prices; AA on both), `--es-border` (decorative). Other tokens: `font` (a Google Fonts family from `config/platform.fonts`; load it with `display=swap` and fall back to the system sans-serif for unknown names), `layout` (`list` | `grid`), `cardLayout` (`compact` | `image-top` | `image-left`), `mode` (`light` | `dark`; set `color-scheme`). Text colours must come from the resolved tokens (FR-060: auto-adjusted on the public menu). Never dim sold-out items with opacity (it breaks AA); use a badge. The owner app preview (`MenuThemePreview`) imitates this layout: category pills (first one in primary), image-left cards with an 88 px image, grid 2 columns on phones and 4 on desktops.
- M04 (done 2026-11-14): `restaurants/{rid}/live/availability` = `{items: {iid: bool}, updatedAt}`, written by `onItemWrite` within about a second of the owner's switch. A key can be missing (item never written since the overlay began); then use the snapshot's `available`. Show unavailable items as "Sold out", visibly different (FR-026, BR-009). Dietary labels: `dietaryLabels/{id}` `{name, icon, color, sort, retired}`; `icon` is `veg` / `nonVeg` (India square-and-dot and square-and-triangle marks, FR-023), `vegan` or `egg`. Always print the name next to the symbol. Tags: `itemTags/{id}`. Prices are integer minor units in the restaurant currency; format with CLDR like `Money.format` in core (KWD 1.250).
- M03 (done 2026-11-14): `slugs/{slug}` = `{restaurantId, current: true, createdAt}` for the live slug; a replaced slug becomes `{current: false, replacedAt}` and is kept for the life of the account (`changeSlug`). For a non-current slug, 301 to `/{restaurants/{rid}.slug}` (AC-023). An owner may take back an old slug (`current` flips back to true, `reclaimedAt`). `qrCodes/{code}` unchanged. Profile display rules (FR-014): `visibility.{phone,email,address,hours,social} == false` hides that group; a missing flag means shown. `openingHours` is one string per weekday (`"HH:mm-HH:mm"` slots joined by `,`; `""` closed; a close before the open runs past midnight; `"00:00-00:00"` is open all day) in the restaurant's `timezone` — map to schema.org `openingHoursSpecification`. `contact.phone` is E.164; `website` and social links are https URLs. Owner app shows menu URLs as `AppEnv.menuBaseUrl/{slug}` (prod placeholder `https://menu.eazysuvai.com`, dev `https://eazy-suvai-dev-menu.web.app`); keep these in sync with the final domain.
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

- [x] Hosting site `menu` with rewrites to `renderMenu`; `/q/**` and `/{slug}` routing.
- [x] Data loader: slug → restaurant → version → availability overlay; old slug → 301.
- [x] HTML templates with escaping, theme CSS variables, critical CSS inline, total JS ≤ 10 KB.
- [x] Price and opening-hours formatting with the restaurant's locale, currency and time zone.
- [x] All account-state pages.
- [x] SEO tags, JSON-LD, sitemap, robots.
- [x] Cache headers (`s-maxage=60`), ETag.
- [x] Lightbox and category navigation scripts (progressive enhancement: page works without JS).
- [x] Lighthouse CI budget: LCP ≤ 2.5 s on simulated 4G, initial payload ≤ 150 KB, accessibility score ≥ 95.

## Acceptance checks

- [x] AC-008: opens without login.
- [ ] AC-009: correct on Android Chrome, iPhone Safari, a tablet and desktop browsers.
- [x] AC-012: branding and theme visible.
- [x] AC-019: title, description, Open Graph, JSON-LD and sitemap entry present.
- [x] AC-023: an old slug answers 301 to the current one.
- [x] AC-024: each FR-099 state returns the right page and HTTP code.
- [x] Availability change visible within 60 s; KWD prices show 3 decimals.
- [x] No draft or admin data appears in the HTML (FR-045).

## Tests

Jest snapshot tests of the templates for each state; data loader tests; HTML validation; Lighthouse CI on the emulator; manual check on 2 real phones.

## Completion notes

**What was built** (all in `functions/src/public/`; exported as `renderMenu` from `src/index.ts`)

- **`index.ts`**: `renderMenu`, an HTTPS function (`invoker: public`, 256 MiB, concurrency 80). Bodies of 1 KB or more are gzipped when the client accepts it (`Vary: Accept-Encoding`).
- **`serve.ts`**: `handleMenuRequest(db, req, deps)` returns `{status, headers, body}`; the Functions wrapper is thin. It sets:
  - `Cache-Control: public, max-age=0, s-maxage=60` on everything that depends on data, including redirects. The error page uses `no-store`.
  - A weak ETag on 200 responses; a matching `If-None-Match` answers 304.
  - On HTML: a CSP whose `script-src` allows only the SHA-256 of the two inline scripts, plus `frame-ancestors 'none'` and `nosniff`. On state pages: `X-Robots-Tag: noindex`; `Retry-After: 3600` on 503.
  - The canonical origin from `menuBaseUrl()`: `MENU_ORIGINS` by project id (prod, `eazy-suvai-dev`, `demo-eazysuvai`; production by default), overridable with `MENU_BASE_URL`. Not in `functions/.env`: the repo ignores `.env*` files.
- **`routes.ts`** (`routeOf`): `/{slug}`; `/{Slug}` and `/{slug}/` 301 to the lower-case form without the slash (query kept); `/q/{code}` in any case, checked against the FR-047 alphabet; `/sitemap.xml`. Anything else is a 404.
- **`loader.ts`**:
  - `loadMenu(db, slug)` reads `slugs/{slug}`, then `restaurants/{rid}`, then one `getAll` of `versions/{n}`, `live/availability` and `plans/{planId}`. Results:
    - `live`;
    - `redirect` when the root's `slug` differs (old slug, AC-023);
    - `coming-soon` (active, `publishedVersion == null`);
    - `unavailable` (suspended or any unknown status);
    - `gone` (deactivated, deleted, or a held slug whose restaurant document is gone);
    - `not-found`.
  - `resolveQr(db, code)`: `qrCodes/{code}` → the root's current `slug`.
  - `sitemapEntries(db)`: `status == 'active'` with a numeric `publishedVersion`; `lastmod` is `publishedAt`.
- **`render-menu.ts`** (extended from M06; the draft preview still uses it):
  - Header: cover (`fetchpriority="high"`, never lazy, as the LCP element), logo, name, description, and "Open now" / "Closed now" in the restaurant's time zone. Contact: address, then action links: Call (`tel:`), Map (`social.googleMaps`, or a Google Maps search for the address), email, website and social links. Hours: a `<details>` with today in bold.
  - Category bar: sticky pills; from 1024 px a left sidebar (220 px). The first link starts with `aria-current`.
  - Content: Featured section, then categories (`h2`) and items (`h3`).
  - Items: lazy `srcset` images (320w/640w/1280w), each wrapped in `<a class="zoom" href="w1280">` so the photo opens without JS. Price through `formatPrice`, dietary icon plus name, tags, and a featured badge and border.
  - Unavailable items: grey photo, dashed border, muted price, a "Currently unavailable" badge and `aria-disabled`.
  - Columns: list 1 / 2 / 2, grid 1 / 2 / 3 (< 600, 600–1023, ≥ 1024 px); content at most 1200 px.
  - The footer reads "Powered by EazySuvai" unless the plan removes it.
  - New `RenderOptions`: `canonicalUrl` (adds the SEO head), `slug`, `beacon`, `scripts` and `now`.
- **`client-script.ts`**: `HEAD_SCRIPT` adds `js` to `<html>`; `BODY_SCRIPT` (3.4 KB together, under the 10 KB limit, checked by a test):
  - turns on the font stylesheet;
  - highlights the category in view (IntersectionObserver) and keeps its pill visible;
  - adds "more" / "less" to descriptions longer than three lines;
  - opens photos in a `<dialog>` lightbox (close button, Escape, backdrop tap, swipe down);
  - removes `?src=qr` from the address bar;
  - provides the analytics hook `esTrack`.
- **`seo.ts`**: `pageTitle`, `metaDescription` (the description, or a sentence with the name and city, at most 160 characters), canonical, Open Graph (cover at 1280 px, or logo at 640 px; size, alt, locale), Twitter card, and JSON-LD. The JSON-LD is:
  - the business type mapped to `Restaurant`, `CafeOrCoffeeShop`, `Bakery`, `BarOrPub` or `FoodEstablishment`, with address, `sameAs` and `openingHoursSpecification`;
  - `hasMenu` → `Menu` → `MenuSection` → `MenuItem`, with `offers {price as an exact decimal string, priceCurrency, availability}` and `suitableForDiet`.

  `jsonForScript()` escapes `<`, `>`, `&`, U+2028 and U+2029. `sitemapXml()`.
- **`hours.ts`**: `localTime` and `isOpenAt` (slots past midnight, `00:00-00:00` all day, closed days, unknown zone → UTC), and `openingHoursSpecification`.
- **`state-pages.ts`**: `renderStatePage(kind)` in brand colours with `noindex`: coming soon 404 (with the name), unavailable 503 (name only), gone 410, not found 404, and error 500 with "Try again".
- **`text.ts`**: every customer-facing string (`MENU_TEXT_EN`, `menuText(locale)` by language subtag). `format.ts` gains `majorAmount()`.
- **`sample-menu.ts`**: a realistic snapshot (6 categories, 36 items), used by the tests and the Lighthouse seed.
- **`lib/plan-limits.ts`**: `removeBrandingFrom(planId, data)` reads `plans/{planId}.limits.removeBranding`. Without the field, Free shows the footer and Pro hides it.
- **Hosting:** the `menu` target rewrites `**` to `renderMenu` (asia-south1). `hosting/menu/` now holds only `favicon.ico`, `apple-touch-icon.png` and the generated `robots.txt` (git-ignored). The predeploy step `node functions/scripts/write-robots.mjs` writes it for `$GCLOUD_PROJECT` from the same origin map.
- **Tooling:**
  - `npm run test:emulators` also starts `hosting:menu`.
  - New `npm run test:lighthouse` (`scripts/lighthouse-budget.mjs`), `tool/check.sh lighthouse`, and a CI job `lighthouse` that uploads the report.
  - New dev dependencies (pinned): `lighthouse` 13.6.0, `puppeteer-core` 25.16.0, `chrome-launcher` 1.2.2, `html-validate` 11.17.0.

**Routes and HTTP codes**

| Request | Answer |
| --- | --- |
| `/{slug}`, active and published | 200 menu, indexable |
| `/{slug}`, active, never published | 404 "Menu coming soon" with the name, `noindex` |
| `/{slug}`, suspended | 503 "Menu temporarily unavailable" with the name only, `noindex`, `Retry-After` |
| `/{slug}`, deactivated or deleted, or a held slug without a restaurant | 410 "Menu no longer available", `noindex`, not in the sitemap |
| `/{old-slug}` | 301 `/{current-slug}` (query kept) |
| `/{Slug}`, `/{slug}/` | 301 `/{slug}` |
| `/q/{code}` (any case) | 302 `/{slug}?src=qr`; unknown code 404; restaurant document gone 410 |
| `/sitemap.xml` | Active, published menus with `lastmod` |
| `/robots.txt` | Static: `Allow: /`, `Disallow: /q/`, `Sitemap:` |
| unknown path, `/` | 404 "Menu not found", `noindex` |
| Firestore error | 500 "Something went wrong", `no-store` |

**Measured** (`npm run test:lighthouse`, Lighthouse 13.6 mobile, simulated slow 4G, emulator with real WebP renditions)

| Page | LCP | Payload without images | Accessibility | SEO | Performance |
| --- | --- | --- | --- | --- | --- |
| list theme, 36 items | 1.39 s | 46.9 KB (HTML 9.9, fonts 29.4) | 100 | 100 | 92 |
| grid theme, 36 items | 1.60 s | 45.9 KB | 100 | 100 | 92 |

The same run checks the page at 360, 768 and 1280 px in headless Chrome: no horizontal scroll, the right number of columns, the sidebar only on desktop, and a sticky category bar. It also checks that the lightbox opens the 1280 px image and closes with Escape, that the category bar follows taps and scrolling, that "more" expands, that `?src=qr` is removed, and that without JavaScript the menu, category links and photo links all work. Screenshots are in `functions/lighthouse-report/`.

**Tests** (all passing at completion)

| Suite | Tests | M07 additions |
| --- | --- | --- |
| Functions unit | 267 | `public/public.test.ts` (43): routing, open-now and schema hours, prices (INR lakh grouping, KWD/BHD 3 decimals), SEO tags, JSON-LD shape, script-tag escaping, sitemap, template snapshots (live menu + 5 state pages), html-validate on every layout and state, page parts, escaping of every field, JS size and syntax, draft preview without scripts, handler without data (redirects, 405, 404, 500 `no-store`, ETag/304), CSP, base URL, branding flag |
| Functions emulator | 96 + Storage check | `public/render-menu.emu.test.ts` (12): live menu with the availability overlay and only the current version, grace period and Pro branding, the four FR-099 states, held slug 410 and unknown 404, old slug 301 (AC-023), QR 302 following slug changes, sitemap filtering, a real M06 publish (KWD, hidden category, owner fields, later draft edits never shown; availability through the M04 trigger), and the Hosting emulator rewrite |
| Lighthouse | 2 pages × budget + 6 layouts + behaviour | `scripts/lighthouse-budget.mjs` |

**Decisions that differ from the plan**

1. **`robots.txt` is a static Hosting file**, generated per project. The Functions Framework answers `/robots.txt` and `/favicon.ico` itself with an empty 404 before the function runs, on the emulator and on gen-2. The `Sitemap:` line needs the absolute origin, so `write-robots.mjs` writes it from the project's origin (Hosting predeploy and the test scripts).
2. **"Dimmed" without opacity.** FR-043 says dimmed; the M05 note forbids opacity because it breaks AA. The photo turns grey, the border is dashed, the price uses the muted colour, and the badge reads "Currently unavailable" (the M06 preview said "Sold out").
3. **Images use the Storage token URLs**, not a Hosting proxy. The renditions already carry `immutable` one-year cache headers and are served from Google's edge; a proxy would add a function call per image. `storageUrlResolver` stays the only place that builds them.
4. **The Google Fonts stylesheet does not block rendering** on the public page (`media="print"`, switched on by the script; `<noscript>` fallback). Blocking, it cost about 0.8 s of LCP on 4G. The draft preview keeps the plain stylesheet (it has no scripts).
5. **The function gzips its responses.** Hosting compresses as well; doing it in the function means the CDN stores the small copy and the emulator measures what customers receive.
6. **Grid columns are 1 / 2 / 3** as this plan's responsive rules say, while M05's owner preview shows 2 columns on phones; a one-column grid on a phone is a large image-top card.
7. **`/q/{code}` redirects for every known code**, whatever the account state. The slug page then shows the FR-099 state, so the QR visit (`src=qr`) and the state live in one place.
8. **Slugs are normalised:** upper case and a trailing slash answer 301 to the canonical form.
9. **Featured items appear twice:** in the Featured section and in their own category.
10. **"Open now" is computed when the page renders**, so it can be up to 60 s stale (CDN).
11. **`/` has no landing page:** it is the generic 404 (`noindex`).
12. **FR-046 states:** "loading" does not apply (the server sends a complete page). "Empty" is the renderer's "This menu has no items yet" (BR-003 prevents it on a live menu). "Error" is the 500 page.

## Open items

- **AC-009 on real devices.** Checked only in headless Chrome at 360, 768 and 1280 px. Check by hand on an Android phone (Chrome) and an iPhone (Safari) once deployed:
  - the sticky bar (Safari's toolbar resizing);
  - lightbox swipe-down and the close button;
  - tap-to-call;
  - the map link;
  - "more" on long descriptions;
  - Open Graph previews in WhatsApp (AC-014 is M08's);
  - a dark theme.

  Also check one tablet (portrait 768, landscape 1024 with the sidebar).
- **Deploy to `eazy-suvai-dev` (yours to run):** `firebase deploy --only functions:renderMenu,hosting:menu --project eazy-suvai-dev`. After that:
  - check `https://eazy-suvai-dev-menu.web.app/robots.txt`;
  - check the sitemap;
  - confirm that a publish shows within 60 s through the CDN (FR-044 needs the real CDN);
  - confirm the CDN serves the gzipped body.
- **Lighthouse on a real device / the real CDN:** the budget ran on the emulator with a warmed function. A cold start on a cache miss adds TTFB. If LCP on real phones exceeds 2.5 s at the 75th percentile, set `minInstances: 1` on `renderMenu` (it costs money, so it's your decision).
- **CI `lighthouse` job not yet run on GitHub.** It needs Chrome on the runner (Ubuntu images have it) and network access to Google Fonts.
- **Sitemap size:** one query over all active restaurants, with no paging. Past about 50,000 menus it needs a sitemap index (M13).
- **Localization:** all strings are in `text.ts` (English). Other languages add a bundle to `TEXTS` (FRD §6.3).

## Change log

- 2026-11-14: Plan created.
- 2026-11-15: Done. `renderMenu` behind the `menu` Hosting site: routing (slug, old slug 301, `/q/` 302, sitemap), loader with the availability overlay, the extended renderer (sidebar, lightbox, open now, unavailable styling), SEO and JSON-LD, FR-099 state pages, ETag, CSP, gzip, 3.4 KB of script; Lighthouse budget met (LCP 1.4–1.6 s, 47 KB, accessibility 100) with layout checks at 360/768/1280. `robots.txt` is static because the Functions Framework intercepts it; the font no longer blocks rendering.
