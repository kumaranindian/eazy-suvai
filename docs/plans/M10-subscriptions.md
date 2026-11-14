# M10 – Subscriptions and plan limits

Status: Not started
Started:
Completed:

## Goal

Free and Pro plans with limits enforced on the server, upgrade requests, manual activation after offline payment, expiry reminders, a grace period and automatic downgrade that hides (never deletes) over-limit content.

## FRD coverage

FR-076 to FR-083, FR-100, FR-101, FR-106, BR-011, §5.5, AC-018, AC-025, AC-026, AC-030.

## Depends on

M04. M11's plan screen for admins (can be built in parallel).

## Inputs from other modules

- M04: `createCategory` / `createItem` limit checks (switch them to the shared `getPlanLimits()` here).
- M05: premium theme flag. M08: `qrLogo` flag. M09: `analyticsDays`. M07: `removeBranding`.

## Plans (FR-078)

| Limit | Free | Pro |
| --- | --- | --- |
| Menu items | 50 | 500 |
| Categories | 10 | Unlimited (store as a high number, for example 10000) |
| Branches | 1 | 1 |
| Themes | 2 (non-premium) | All |
| Analytics history | 7 days | 365 days |
| Logo in QR code | No | Yes |
| Duration | No expiry | Monthly or annual |
| Price | Free | To be set per currency |

## Data and backend

- `plans/{free}` and `plans/{pro}` seeded; editable by admins (M11).
- Restaurant `subscription {status: 'free'|'active'|'grace'|'expired', planId, startAt, expiresAt, graceEndsAt}`; history in `subscriptionHistory`.
- `requestUpgrade({planId, billing: 'monthly'|'annual'})` (owner): creates `upgradeRequests/{id}`; one open request at a time.
- `recordPaymentAndActivate({restaurantId, planId, amountMinor, currency, method, reference, paidAt, startAt, endAt})` (admin): writes `payments`, updates the subscription, clears `hiddenOverLimit` flags, closes the request, audit log, sends a confirmation email.
- `changeSubscription({restaurantId, action: 'extend'|'downgrade'|'modify', ..., reason})` (admin, FR-081): audit-logged.
- `subscriptionDaily` (schedule, 00:30 Asia/Kolkata):
  - Reminder emails 14, 7 and 1 days before `expiresAt` (Trigger Email extension or SMTP).
  - On `expiresAt`: status `grace`, `graceEndsAt` = +`config/platform.graceDays` (default 14).
  - On `graceEndsAt`: downgrade to Free and run `applyPlanLimits()`.
- `applyPlanLimits(rid)` (FR-101): mark items and categories beyond the limit as `hiddenOverLimit`, last in display order first; premium theme → plan default (keep custom settings); publish a new version without hidden content; notify the owner.
- Owner downgrade by choice: the owner picks which items to hide before confirming.
- On upgrade: clear `hiddenOverLimit` and prompt the owner to publish.

## Screens and responsive behaviour

| Screen | Compact | Expanded |
| --- | --- | --- |
| Plan and billing (owner) | Current plan card, usage bars (items x/50, categories x/10), plan comparison as stacked cards, "Request Pro" button, grace/expiry banner | Usage and current plan left, comparison table right |
| Over-limit manager (owner) | List of hidden items with swap action | Two lists: visible and hidden |
| Upgrade requests (admin, in admin app) | Table of requests → "Record payment" form | Same (admin app is web-first) |

## Tasks

- [ ] Seed plans; shared `getPlanLimits()` in functions; refactor M04 callables to use it.
- [ ] Gate theme, QR logo, analytics range and branding by plan flags.
- [ ] `requestUpgrade`, `recordPaymentAndActivate`, `changeSubscription`.
- [ ] `subscriptionDaily` with reminders, grace and downgrade.
- [ ] `applyPlanLimits` with auto-publish and owner notification.
- [ ] Owner plan screen, usage bars, banners, over-limit manager.
- [ ] Admin upgrade-request queue and record-payment form (lives in the admin app; coordinate with M11).

## Acceptance checks

- [ ] AC-018: creating the 51st item on Free fails on the server.
- [ ] AC-025: a Pro restaurant in grace keeps working; after grace it is Free with over-limit content hidden, not deleted, and the public menu still loads.
- [ ] AC-026: upgrading restores hidden content to the draft.
- [ ] AC-030: an admin records an offline payment, Pro activates, and the action is audit-logged.

## Tests

Functions: limit checks, each scheduled transition with fake clocks, `applyPlanLimits` ordering, payment recording. Widget tests for the plan screen at 3 widths.

## Completion notes

_Fill in when done._

## Open items

## Change log

- 2026-11-14: Plan created.
