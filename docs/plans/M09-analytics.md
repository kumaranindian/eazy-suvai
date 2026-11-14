# M09 – Analytics

Status: Not started
Started:
Completed:

## Goal

Owners see how many people view their menu, how many came from the QR code, and which categories and items get attention, without cookies or personal data.

## FRD coverage

FR-071 to FR-075, BR-005 (tenant isolation), §7.7 (raw events 90 days), AC-015.

## Depends on

M07.

## Inputs from other modules

- M07: public page and the `?src=qr` marker from the `/q/` redirect.
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

- [ ] Beacon script in the M07 template (no cookies, no third-party scripts).
- [ ] `collectEvent` with validation, bot filter, rate limit, aggregates and raw events.
- [ ] Firestore TTL policy on `analyticsEvents.expireAt`.
- [ ] Analytics repository: read daily docs for a range, merge into totals and series.
- [ ] Analytics screen with date range filter (FR-074) and empty states.
- [ ] Rules: `analyticsDaily` readable only by the owner and admins; client writes denied.

## Acceptance checks

- [ ] AC-015: views, QR visits and item interest shown with a date filter.
- [ ] Reloading the page within 30 minutes does not double-count a view.
- [ ] A request with a crawler user agent is not counted.
- [ ] No IP addresses or user agents are stored.
- [ ] Another owner cannot read this restaurant's analytics.

## Tests

Functions: `collectEvent` (valid, bot, malformed, time-zone day boundary). Widget tests of the screen with sample data at 3 widths.

## Completion notes

_Fill in when done._

## Open items

## Change log

- 2026-11-14: Plan created.
