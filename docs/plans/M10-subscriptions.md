# M10 – Subscriptions and plan limits

Status: Done
Started: 2026-11-15
Completed: 2026-11-15

## Goal

Free and Pro plans with limits enforced on the server, upgrade requests, manual activation after offline payment, expiry reminders, a grace period and automatic downgrade that hides (never deletes) over-limit content.

## FRD coverage

FR-076 to FR-083, FR-100, FR-101, FR-106, BR-011, §5.5, AC-018, AC-025, AC-026, AC-030.

## Depends on

M04. M11's plan screen for admins (can be built in parallel).

## Inputs from other modules

- M04 (done 2026-11-14): `createCategory`, `createItem` and `restoreDeleted` already call the shared `getPlanLimits(read, planId)` in `functions/src/lib/plan-limits.ts` inside their transactions. It reads `plans/{planId}.limits.{maxItems, maxCategories}` (`null` or a negative number = unlimited) and falls back to the FRD values while the plan documents are missing. Seed `plans/free` and `plans/pro` and extend this helper (themes, analytics, QR logo) rather than adding another. `limit-reached` errors carry `{limit, max, planId}`; the owner app's prompt opens `Routes.plan` (`/settings/plan`, a placeholder `PlanPage` to replace with the plans and upgrade screen). FR-101 hiding uses `items.hiddenOverLimit` (written as `false` on create); hidden items still count toward the limit.
- M05 (done 2026-11-14): `themes/{id}.premium` (seeded non-premium: `saffron`, `minimal`; premium: `banana-leaf`, `midnight`, `cafe-cream`, `coastal`). Owners write `themeId` directly; the rules only check that the theme exists. To gate premium themes server-side (BR-011), add a check to the rules (`themes/{id}.premium == false || plan allows`) or move the choice to a callable, and lock premium cards in `ThemeGalleryPage` (they only show a badge now). On downgrade keep `themeSettings` and switch `themeId` to the plan default. M08 (done 2026-11-15): `qrLogo` flag. The logo switch is `QrKeys.logoSwitch` in `apps/owner_app/lib/features/qr/presentation/qr_share_page.dart`, with its state in `qrLogoChoiceProvider`. Disable it with an upgrade hint when the plan lacks `qrLogo`; the QR code is made on the device, so no server check is needed. M09 (done 2026-11-15): `analyticsDays`. Point `analyticsHistoryDaysProvider` (owner app, `features/analytics/data/analytics_repository.dart`) at the plan document instead of `defaultAnalyticsDays()`; the screen already locks longer ranges and shows the upgrade prompt. M07: `removeBranding`.
- M06 (done 2026-11-15): `publishMenu` checks the plan limits with the same `getPlanLimits()`, but **does not count `hiddenOverLimit` items** (a downgraded menu must stay publishable, FR-101); the problem is `limit-exceeded` with `details {limit, max, count, planId}`. `rollbackMenu` refuses a version with more items or categories than today's plan allows. If premium themes become plan-gated, add the check to `validateDraft()` in `functions/src/publishing/snapshot.ts` (a new problem code plus its `.arb` message) so a publish can't carry a premium theme on Free.

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

- [x] Seed plans; shared `getPlanLimits()` in functions; refactor M04 callables to use it.
- [x] Gate theme, QR logo, analytics range and branding by plan flags.
- [x] `requestUpgrade`, `recordPaymentAndActivate`, `changeSubscription`.
- [x] `subscriptionDaily` with reminders, grace and downgrade.
- [x] `applyPlanLimits` with auto-publish and owner notification.
- [x] Owner plan screen, usage bars, banners, over-limit manager.
- [x] Admin upgrade-request queue and record-payment form (lives in the admin app; coordinate with M11).

## Acceptance checks

- [x] AC-018: creating the 51st item on Free fails on the server.
- [x] AC-025: a Pro restaurant in grace keeps working; after grace it is Free with over-limit content hidden, not deleted, and the public menu still loads.
- [x] AC-026: upgrading restores hidden content to the draft.
- [x] AC-030: an admin records an offline payment, Pro activates, and the action is audit-logged.

## Tests

Functions: limit checks, each scheduled transition with fake clocks, `applyPlanLimits` ordering, payment recording. Widget tests for the plan screen at 3 widths.

## Completion notes

**What was built**

- **Plans** (`functions/src/subscriptions/seed-plans.ts`, seeded by `scripts/seed-platform.mjs`):
  - `plans/free` and `plans/pro` as in the table above, with `limits {maxItems, maxCategories (Pro 10000 = unlimited), maxBranches, premiumThemes, defaultThemeId: 'saffron', analyticsDays, qrLogo, removeBranding}`, `billing` (Pro: monthly, annual), `prices: {}` (open decision), `isFree`, `active` and `sort`.
  - The shared helper `functions/src/lib/plan-limits.ts` now also has `PlanFeatures`, `planFeaturesFrom`, `getPlanFeatures(read, planId)` and `restaurantPlanFeatures()`, with FRD fallbacks. `getPlanLimits` is unchanged, so M04's create callables, M06 publish and the counts keep using it. The publish draft loader now reads the full features.
- **`restaurants/{rid}.planFeatures`** `{maxItems, maxCategories, premiumThemes, analyticsDays, qrLogo, removeBranding}`:
  - written at registration (Free) and on every plan change;
  - read by the rules (premium themes) and the owner app (QR logo, analytics range, limits);
  - restaurants from before M10 (field missing) are treated as Free;
  - `scripts/backfill-plan-features.mjs` writes it for existing restaurants or after an admin plan edit (FR-077: edits reach subscribers only when applied).
- **State machine** (`subscriptions/model.ts`, pure):
  - `subscription {status: free|active|grace, planId, billing, startAt, expiresAt, graceEndsAt, remindersSent}`;
  - `dailyActionFor(sub, now, graceDays)`:
    - the nearest unsent reminder of 14 / 7 / 1 days (one email after missed runs);
    - grace at expiry for `config/platform.graceDays` (default 14, clamped 0–30; 0 downgrades at once);
    - downgrade when grace ends.
- **`subscriptionDaily`** (schedule `30 0 * * *` Asia/Kolkata, `daily.ts` `runSubscriptionDaily(db, now)`):
  - Each restaurant is handled in its own transaction (idempotent), with `subscriptionHistory`, audit (`subscription.grace`, `subscription.expire`; actor `system`) and emails.
  - A downgrade then runs `applyPlanLimits`.
- **`applyPlanLimits` / `clearHiddenOverLimit`** (`apply-limits.ts`, FR-101). `chooseHidden` (pure):
  - hides categories beyond the limit, last in display order first;
  - every item in a hidden category is hidden with it;
  - other items beyond the limit are hidden in display order;
  - content the owner already hid stays hidden; nothing is un-hidden.

  On a downgrade it also:
  - writes flags in batches of 400 without touching `updatedAt` (no "unpublished changes");
  - reverts a premium theme to the plan's default, keeping `themeSettings`;
  - **publishes a new version built from the live version's source with the hidden content removed** (never the unreviewed draft), `publishedBy: system`, audit `menu.publishPlanLimits`;
  - sets `planFeatures` and `planNotice {kind: 'limitsApplied', hiddenItems, hiddenCategories, themeReverted}`;
  - audits `subscription.applyLimits` and emails the owner.

  On upgrade, `clearHiddenOverLimit` clears every flag with a new `updatedAt`, bumps `draftUpdatedAt` (the publish bar shows) and sets `planNotice {kind: 'restored'}`.
- **Callables** (`callables.ts`):
  - `requestUpgrade({restaurantId, planId, billing})` (owner): one open request, held on the root as `pendingUpgradeRequestId`. Creates `upgradeRequests/{id}` with the restaurant's name, email, mobile and currency. Errors `request-pending` and `already-on-plan` (new codes).
  - `recordPaymentAndActivate({restaurantId, planId, billing, amountMinor, currency, method, reference, paidAt, startAt, endAt, requestId?, note?})` (admin), in one transaction:
    - `restaurants/{rid}/payments/{id}` with `provider: 'offline'` (FR-083);
    - plan, subscription and `planFeatures`;
    - the request marked activated;
    - `subscriptionHistory`;
    - audit `subscription.activate`;
    - an "activated" email.

    Then it restores hidden content.
  - `changeSubscription` (admin, reason required, FR-081):
    - `extend` (paid only, future date);
    - `modify` (plan and dates);
    - `downgrade`.

    Each writes `subscriptionHistory` and audit `subscription.{action}`. Tighter limits run `applyPlanLimits`; a better plan restores hidden content.
  - `closeUpgradeRequest({requestId, reason})` and `adminListUpgradeRequests({status})` (admin).
  - `setHiddenOverLimit` (owner):
    - swap which items and categories are hidden within the plan; a draft change;
    - or `downgrade: true` with the owner's choices, which must fit Free; the switch then publishes.
- **Emails** (`mail.ts`): queued as `mail/{id}` in the "Trigger Email from Firestore" extension format: reminder, grace, downgraded, limitsApplied, activated, restored. English text.
- **Publishing and rules:**
  - Hidden categories are left out of the snapshot (`publicCategories`), and `hiddenOverLimit` is in the category draft fields.
  - New problem code **`premium-theme`** (FR-066 list, owner message with a Fix link to `/settings/theme`).
  - Rules: a premium `themeId` needs `planFeatures.premiumThemes == true`; `plans` can be read by owners and TOTP admins; `payments`, `subscriptionHistory`, `upgradeRequests` and `mail` are closed. Owners cannot write `planId`, `planFeatures`, `subscription`, `planNotice` or `pendingUpgradeRequestId` (whitelist).
- **Core:** `PlanFeatures`, `Subscription`, `SubscriptionStatus` and `PlanNotice` (`src/restaurant/subscription.dart`). `Restaurant.planFeatures`, `subscription`, `planNotice`, `pendingUpgradeRequestId` and `overLimit`. `MenuCategory.hiddenOverLimit`. Error codes `requestPending` and `alreadyOnPlan`.
- **Owner app** (`lib/features/plan/`):
  - `PlanPage` (`/settings/plan`, replaces the M04 placeholder):
    - banners;
    - current plan ("never expires", "paid until", or grace text);
    - usage bars (red when over);
    - the open-request note;
    - "Choose hidden items" and "Switch to Free";
    - plan comparison: stacked cards on phones, side by side from 600 px, with the current plan and usage left of the comparison from 1024 px;
    - "Request Pro" with a monthly / annual choice; disabled while a request is open.
  - `HiddenContentPage` (`/settings/plan/hidden`, `?downgrade=1`): a switch per category and item on phones, and "Visible / Hidden" lists with move buttons on desktop. A live count and an over-limit message; Save is disabled while over. The downgrade mode confirms first.
  - `SubscriptionBanners` on the dashboard: grace (renew), expiry within 14 days, content hidden (manage), and content restored (publish).
  - **Gates:**
    - premium themes are locked on Free (dialog with "See plans"; the rules refuse the write too);
    - the QR logo switch is disabled on Free with "part of Pro";
    - the analytics range reads `planFeatures.analyticsDays`;
    - the public footer follows `plans/{planId}.limits.removeBranding` (M07 loader).
  - 62 strings.
- **Admin app** (`lib/features/subscriptions/`; new section **Upgrades**, `/upgrades`):
  - `UpgradeRequestsPage`: pending / activated / declined; a table from 600 px with "Record payment" and "Decline"; read-only cards and a notice below 600 px.
  - `RecordPaymentDialog`: amount (parsed to minor units for the currency), currency, method, reference, paid on, and start / end dates prefilled by billing (one month or one year).
  - Decline asks for a reason.
  - Shared for M11: `AdminApi` (`lib/data/admin_api.dart`, every admin read and write through callables) and `ReadOnlyNotice` / `adminReadOnly()` (`lib/widgets/read_only.dart`).

**Tests** (all passing at completion)

| Suite | Tests | M10 additions |
| --- | --- | --- |
| Functions unit | 306 | `subscriptions/subscriptions.test.ts` (12): seeded plans, fallbacks, every `dailyActionFor` transition with fixed dates (reminders once each, the nearest after a missed run, grace 14/30/0 days, grace end), `chooseHidden` ordering and owner choices, the `premium-theme` problem, emails |
| Functions emulator | 108 | `subscriptions/subscriptions.emu.test.ts` (7): AC-018 (the 51st item), request (one open) / admin list / record payment / audit / email / restore (AC-030, AC-026), payment validation and decline, the **full lifecycle on fixed dates** (14-day reminder, idempotent rerun, grace with the menu live, downgrade: 2 categories and their items hidden, 55 items kept, premium theme reverted with settings kept, new system-published version, public menu live, emails and audit, no new items while over, idempotent: AC-025), swap and limit, owner downgrade by choice with publish, admin extend / downgrade with reasons |
| Rules | 158 | `subscriptions.test.js` (5): plans readable by owners and MFA admins; premium themes only with `planFeatures.premiumThemes` (legacy restaurants = Free); owners can't change plan fields; payments, history, requests and mail closed |
| Owner app | 214 | `plan_test.dart` (9): Free plan at 360/768/1280 (usage, comparison, request, one open request), Pro expiry and the 14-day reminder, grace banner, hidden-content banner and swap with the over-limit check, desktop two lists, switch to Free, premium theme lock. QR and theme tests updated for the gates |
| Admin app | 24 | `upgrades_test.dart` (5): table at 768 and 1280, read-only at 360, record payment (validation, minor units, dates by billing), decline with reason |

**Decisions that differ from the plan**

1. **Plan flags are copied to the restaurant (`planFeatures`).** The rules can then check premium themes with the theme read they already make (the restaurant rules are near their evaluation budget, M03 note). It also gives FR-077's "applies to existing subscribers only when explicitly applied". Item and category limits are still read live from `plans/{planId}` by the callables and publish (M04/M06); `changeSubscription`, payments and downgrades refresh `planFeatures`.
2. **The auto-publish after a downgrade starts from the live version, not the draft,** so an owner's unpublished edits never go live unasked. Only the hidden content and a premium theme change.
3. **Items in a hidden category are flagged too,** so the over-limit manager shows them as hidden and visible counts match what customers see.
4. **Emails are `mail/` documents** for the Trigger Email extension. No mail provider is wired into the code (Open items).
5. **Swaps keep owner choices.** `applyPlanLimits` never un-hides, and swapping is a draft change the owner publishes. Downgrade-by-choice publishes at once (FR-101).
6. **`subscription` gains `planId`, `billing` and `remindersSent`** (architecture §4.2 updated). History entries go to `subscriptionHistory` with `action` = activate, extend, modify, downgrade, grace, expire or ownerDowngrade.
7. **The admin queue is a top-level "Upgrades" section.** M11 links it from the dashboard's pending count.

## Open items

- **Email delivery (needs your choice and the Blaze plan):** install the Firebase extension "Trigger Email from Firestore" on the `mail` collection with an SMTP provider (for example SendGrid, Amazon SES or Zoho), and set the sender to EazySuvai. Until then reminder, grace, downgrade and activation emails wait in `mail/`. The dashboard banners work without it.
- **Cloud Scheduler for `subscriptionDaily`** needs the Blaze plan on the real projects. The emulator doesn't run schedules; the job is tested by calling `runSubscriptionDaily` with fixed dates.
- **Prices** are empty (master plan open decision). Set `plans/pro.prices` as `{INR: {monthly, annual}, …}` in minor units (M11's plan editor). The owner app shows "Price on request" until then.
- **Owner payment history:** payments are recorded but owners don't see a list yet (not in the FRD MVP; admins see it in M11).
- **"Powered by EazySuvai" on Free** follows `plans/free.limits.removeBranding` (false = shown); this is still an open decision.
- **After deploying:** run `seed-platform.mjs` (plans) and then `backfill-plan-features.mjs` on each project.

## Change log

- 2026-11-14: Plan created.
- 2026-11-15: Done. Seeded Free/Pro plans and the shared plan features helper (`planFeatures` copied to restaurants); `requestUpgrade`, `recordPaymentAndActivate`, `changeSubscription`, `closeUpgradeRequest`, `adminListUpgradeRequests`, `setHiddenOverLimit`; `subscriptionDaily` (reminders 14/7/1, grace, downgrade) on a pure state machine; `applyPlanLimits` (hide last first, revert premium theme, publish from the live version, notify) and restore on upgrade; premium-theme rule and publish problem; owner plan page, banners, over-limit manager and gates; admin Upgrades queue with the record-payment form.
