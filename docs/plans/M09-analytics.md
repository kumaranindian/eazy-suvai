# M09 – Analytics

Status: Done
Started: 2026-11-15
Completed: 2026-11-15

## Goal

Owners see how many people view their menu, how many came from the QR code, and which categories and items get attention, without cookies or personal data.

## FRD coverage

FR-071 to FR-075, BR-005 (tenant isolation), §7.7 (raw events 90 days), AC-015.

## Depends on

M07.

## Inputs from other modules

- M07 (done 2026-11-15): the inline script already has the hook.
  - Set `beacon: "/e"` in `serve.ts` (the `renderMenuPage` options for `live`). The script then sends `navigator.sendBeacon("/e", {type, slug, src, ...data})`.
  - Events: `view` on load, `cat` on a category tap (`{id}`), `item` on a photo or "more" (`{id}`).
  - `src` is `qr` when the URL had `?src=qr`; the script then removes it from the address bar.
  - Add the session id and the dedup inside `track()` in `functions/src/public/client-script.ts`. Keep the total under 10 KB; a test checks it.
  - Add a Hosting rewrite `{source: "/e", function: collectEvent}` **before** the `**` rewrite. `renderMenu` answers POST with 405; the CSP allows `connect-src 'self'`.
- M03 (done 2026-11-14): `timezone` (IANA) is owner-editable on `restaurants/{rid}`; the day key for `analyticsDaily` uses the zone at event time (`TimeService.dayKey` in core).
- M10 (later): `limits.analyticsDays` (Free 7, Pro 365).

## Scope

**In:** beacon script on the public page, `collectEvent` endpoint, bot filtering, daily aggregates, owner analytics screen with date ranges and charts.
**Out:** admin platform analytics totals (M11 reads `stats/platform`).

## Data and backend

- Beacon (inline JS, under 1 KB): on load sends `view` with `src` (`qr` or `direct`); category nav taps send `cat`; lightbox or "more" opens send `item`. Uses `navigator.sendBeacon` to `POST /e`. Session ID: random value in `sessionStorage`; a `view` is counted once per session per 30 minutes (FR-071).
- `collectEvent` (HTTPS): validates the payload, drops known bots (user-agent list such as `isbot`), resolves the restaurant from the slug, increments `restaurants/{rid}/analyticsDaily/{date}` (date in the restaurant's time zone) with `FieldValue.increment`, writes a raw event to `analyticsEvents` with `expireAt` = now + 90 days. Does not store IP address or user agent (FR-075).
- Rate limit per session and per IP in memory or via a short-lived counter to resist spam.
- Increments `stats/platform.menuViews` for the admin dashboard.

## Screens and responsive behaviour

| Screen | Compact | Expanded |
| --- | --- | --- |
| Analytics | Range chips (7 days, 30 days, custom); summary tiles stacked (views, QR visits, QR share); daily line chart; top categories and top items as lists | Tiles in a row; chart full width; top categories and top items side by side |

Charts with `fl_chart`. Ranges beyond the plan's history show an upgrade prompt.

## Tasks

- [x] Beacon script in the M07 template (no cookies, no third-party scripts).
- [x] `collectEvent` with validation, bot filter, rate limit, aggregates and raw events.
- [x] Firestore TTL policy on `analyticsEvents.expireAt`.
- [x] Analytics repository: read daily docs for a range, merge into totals and series.
- [x] Analytics screen with date range filter (FR-074) and empty states.
- [x] Rules: `analyticsDaily` readable only by the owner and admins; client writes denied.

## Acceptance checks

- [x] AC-015: views, QR visits and item interest shown with a date filter.
- [x] Reloading the page within 30 minutes does not double-count a view.
- [x] A request with a crawler user agent is not counted.
- [x] No IP addresses or user agents are stored.
- [x] Another owner cannot read this restaurant's analytics.

## Tests

Functions: `collectEvent` (valid, bot, malformed, time-zone day boundary). Widget tests of the screen with sample data at 3 widths.

## Completion notes

**What was built**

- **Beacon** (`BEACON_SCRIPT` in `functions/src/public/client-script.ts`, 0.4 KB, part of the page's single inline script; a test checks it stays under 1 KB):
  - `track(type, data)` sends `{type, slug, src, id?}` as `text/plain` JSON with `navigator.sendBeacon` to `<body data-beacon>`.
  - `serve.ts` now passes `beacon: "/e"` (`BEACON_PATH`) for live menus.
  - A `view` is sent at most once per 30 minutes per tab session. The last view time is kept in `sessionStorage` (`es_v_{slug}`).
  - No cookies, no identifiers sent, no third-party script.
- **`collectEvent`** (HTTPS, `functions/src/analytics/`; Hosting rewrites `POST /e` to it, above `**`). `handleCollect(db, req, deps)`:
  - **Checks, in order:**
    - only POST (405);
    - body ≤ 1 KB (413);
    - **bots** (`isbot` 5.2.2, plus empty or very short user agents) answer 204 and are not counted;
    - strict zod schema (400): `type` view / cat / item, `id` required for cat and item, no extra keys;
    - **rate limit** of 120 events per minute per address, in memory with salted hashes (429);
    - the slug must be the current slug of an active, published restaurant (404);
    - `cat` / `item` ids must be in the live version (ignored otherwise, so the daily document can't be filled with arbitrary keys).
  - **Slug lookup:** cached 60 s per instance (`LiveMenuCache`).
  - **Recording**, in one batch:
    - `restaurants/{rid}/analyticsDaily/{yyyy-MM-dd}` (the day in the restaurant's `timezone`, `dayKeyIn`) with increments of `views`, `qrVisits`, `categoryTaps.{cid}` and `itemOpens.{iid}`, plus `day` and `updatedAt`;
    - a raw `analyticsEvents` document `{restaurantId, type, src, id?, day, at, expireAt = at + 90 days}`;
    - for views, `stats/platform.menuViews` / `qrVisits`.
  - The IP and user agent are never written.
- **TTL:** `firestore.indexes.json` `fieldOverrides` has `analyticsEvents.expireAt` with `ttl: true` (deployed with `firebase deploy --only firestore:indexes`).
- **Rules:** `restaurants/{rid}/analyticsDaily/{day}` can be read by `isOwner(rid) || isAdmin()`; no client writes. `analyticsEvents` and `stats` stay closed.
- **Owner app** (`lib/features/analytics/`, new navigation section "Analytics", route `/analytics`):
  - `domain/analytics.dart`: `AnalyticsDay`, `AnalyticsRange` (on day keys, never device dates), `presetRange`, `rangeAllowed` / `earliestAllowed`, `summarize()` (totals, gap-free daily series, top 5 categories and items, monthly totals) and `defaultAnalyticsDays(planId)` (Free 7, Pro 365).
  - `data/analytics_repository.dart`: `AnalyticsRepository.watchRange` (a document-id range query), `analyticsTodayProvider` (today in the restaurant's zone via `TimeService.dayKey`), `analyticsHistoryDaysProvider`, `analyticsRangeChoiceProvider` and `analyticsSummaryProvider`.
  - `AnalyticsPage`:
    - range chips 7 days / 30 days / Custom. 30 days shows "(Pro)" and a lock on Free, and tapping it shows the upgrade card linking to `/settings/plan`. Custom opens a date-range picker limited to the plan's history.
    - tiles: menu views, QR visits, share from the QR code, item interest (2 per row on phones, 4 from 600 px);
    - an `fl_chart` line chart (views and QR visits) with a screen-reader summary;
    - top categories and items, side by side from 1024 px; deleted ones read "Removed from the menu";
    - monthly totals when the range spans two months;
    - the empty state with a "QR & share" button, a "publish first" note, and a privacy note.
  - 28 strings. Dependency `fl_chart` `>=1.0.0 <1.1.0`: 1.1+ calls `vector_math` 2.2 APIs that Flutter 3.32's pinned `vector_math` 2.1.4 lacks.

**Tests** (all passing at completion)

| Suite | Tests | M09 additions |
| --- | --- | --- |
| Functions unit | 294 | `analytics/analytics.test.ts` (27): payload shapes and rejections (including a session id), bot list, day keys across zones and the 18:30 UTC boundary in India, rate limiter, beacon size and the 30-minute dedup run against a fake `sessionStorage` |
| Functions emulator | 101 | `analytics/collect.emu.test.ts` (5): counts on the restaurant's day across midnight, raw events with a 90-day `expireAt` and no IP or UA, bots / malformed / unknown ids / non-live menus not counted, rate limit, `POST /e` through the Hosting emulator and `data-beacon` on the page |
| Rules | 153 | `analytics.test.js` (4): owner and MFA admin read and range query; other tenants, unverified, suspended, non-MFA admins and strangers cannot; no client writes to aggregates, raw events or stats |
| Owner app | 204 | `analytics_test.dart` (10): ranges, summary, defensive parsing, the screen at 360/768/1280 (values, layout), Free upgrade prompt, Pro 30 days with monthly totals, custom picker limits, empty state |

**Decisions that differ from the plan**

1. **No session id leaves the browser.** FR-075 says it is "kept only in the browser's session storage". The beacon keeps only the time of the last view there and does the 30-minute dedup itself. The server rejects payloads with extra keys, so a session id can't be sent by mistake. As a result the server-side rate limit is per address (in memory, hashed), not per session.
2. **"Session" means the tab's `sessionStorage` session.** A new tab counts a new view, as browsers scope `sessionStorage` per tab.
3. **Ids are checked against the live version** before they become map keys in `analyticsDaily`, to keep the document small and clean.
4. **Analytics is a navigation section** ("Analytics", between QR & share and Settings) rather than a dashboard-only page.
5. **The plan's history comes from `defaultAnalyticsDays(planId)`** until M10 reads `plans/{planId}.limits.analyticsDays`.

## Open items

- **TTL policy on a real project:** `fieldOverrides[].ttl` is in `firestore.indexes.json`. After deploying the indexes, check in the console (Firestore → TTL) that `analyticsEvents.expireAt` is listed and active. The emulator does not run TTL.
- **Check by hand once deployed:**
  - Open a menu on a phone and reload within 30 minutes: one view.
  - Scan the QR code: one QR visit.
  - Tap two categories and open a photo: they show on the Analytics screen the same day.
  - Share the link in WhatsApp: its preview fetch must not count (WhatsApp's user agent is a bot).
- **Rate limit per instance:** the limiter lives in each function instance's memory (max 10 instances), so the effective limit is up to 10× under a heavy attack. That's enough for the MVP. A shared counter (Firestore or Memorystore) would cost a write per event.

## Change log

- 2026-11-14: Plan created.
- 2026-11-15: Done. Cookieless beacon (0.4 KB; view once per 30 min via `sessionStorage`, no id sent), `collectEvent` behind `POST /e` (bots, schema, size, per-address rate limit, live-version ids; daily aggregates in the restaurant's zone, raw events with a 90-day TTL, `stats/platform`), rules and TTL override, owner Analytics section with 7/30/custom ranges limited by plan, tiles, `fl_chart` chart, top lists, monthly totals, empty and upgrade states at 3 widths.
