# M11 – Platform administration

Status: Done
Started: 2026-11-15
Completed: 2026-11-15

## Goal

A separate, MFA-protected admin web app where AVAIL404 staff monitor the platform, find restaurants, change account status, and manage plans, labels, tags, themes and platform settings, with every sensitive action audit-logged.

## FRD coverage

FR-009, FR-010, FR-059, FR-084 to FR-090, FR-099 (status changes), FR-104, §3.1, §3.5, BR-014, AC-016, AC-024 (status part), AC-030 (admin part).

## Depends on

M01 (admin login and MFA), M03 (restaurant data).

## Inputs from other modules

- M10 (done 2026-11-15): the admin app has `AdminApi` (`lib/data/admin_api.dart`; every read and write through callables, tests use `FakeAdminApi`), `ReadOnlyNotice` / `adminReadOnly()` for below 600 px, and the **Upgrades** section (`UpgradeRequestsPage`, `RecordPaymentDialog`). Restaurant detail: use `changeSubscription({restaurantId, action: extend|modify|downgrade, reason, …})` and `recordPaymentAndActivate`. Plans editor: after `upsertPlan`, offer "apply to subscribers" with `syncPlanFeatures(db, rid)` (`functions/src/subscriptions/daily.ts`). `stats/platform` already has `menuViews` and `qrVisits` (M09).

- M00 (done 2026-11-14): admin shell sections are `AdminSection` (dashboard, restaurants, plans, settings) in `apps/admin_app/lib/features/shell/`. `assertAdmin()` should also check the second factor once Identity Platform MFA is on (see the comment in `functions/src/lib/auth.ts`).
- M01 (done 2026-11-14): admin `/sign-in` with the TOTP challenge and `/mfa-setup` enrolment; guard `adminRedirect`. `assertAdmin()` and the rules' `isAdmin()` already require `sign_in_second_factor == 'totp'` (relaxed in `assertAdmin` only on the demo emulator). First admin: `functions/scripts/set-admin.mjs` (claims `{role: 'platformAdmin'}`, `users/{uid}`, audit `admin.grant`, refresh tokens revoked); `setAdminRole` should keep the same claim shape. Real TOTP needs Identity Platform on the project (M01 Open items).
- M10: upgrade-request queue and record-payment form are placed in this app's navigation.
- M12: audit log viewer is placed in this app's navigation.
- M04 (done 2026-11-14): `dietaryLabels/{id}` and `itemTags/{id}` = `{name, icon, color ('#RRGGBB'), sort, retired}`, seeded by `functions/scripts/seed-platform.mjs`. `upsertLabel` / `upsertTag` keep this shape; retire with `retired: true` instead of deleting (items keep the id, FR-104). `icon` must be a key `MenuLabelIcon` knows (`veg`, `nonVeg`, `vegan`, `egg`, `spicy`, `bestseller`, `chefsSpecial`, `new`); anything else shows a generic tag icon. TOTP admins can read both collections through the rules, and `MenuLabelBadge` in core previews an entry.
- M05 (done 2026-11-14): `themes/{id}` = `{name, premium, sort, retired, tokens {primary, secondary, background, surface, text (#RRGGBB upper case), font, layout: list|grid, cardLayout: compact|image-top|image-left, mode: light|dark}, updatedAt}`, seeded by `seed-platform.mjs`. `upsertTheme` keeps this shape, validates with `parseThemeTokens`, and should refuse (or warn about) a theme whose `resolveTheme(tokens).issues` is not empty. Retire with `retired: true`; restaurants already using it keep it. `config/platform.fonts` is the curated font list (Google Fonts family names; `updatePlatformConfig`); the owner app falls back to `MenuFonts.defaults` while it is missing. `config/platform` is now readable by verified owners: never store secrets there. `ThemeCard` and `MenuThemePreview` (owner app) can be moved to core for an admin theme preview.
- M03 (done 2026-11-14): `nameLower` is kept in sync with `name` by `onRestaurantUpdated` (use it for prefix search). Owner slug changes write `auditLogs` entries with `action: 'restaurant.changeSlug'`, `details {from, to, reclaimed}`. `Restaurant.fromMap` in core reads the whole tenant root, including `setupCompletedAt`.
- M06 (done 2026-11-15): TOTP admins can read `restaurants/{rid}/versions/{n}` through the rules (not `versions/{n}/private/source`). `Restaurant.versionHistory` (`MenuVersionEntry`: n, date, who, counts, rollbackOf) and `publishedVersion` / `publishedAt` give the restaurant detail screen its publishing history without reading snapshots. Owner publishing actions are audited as `menu.publish`, `menu.rollback` and `menu.discardDraft` (`details {version, added, changed, removed, …}`).

## Scope

**In:** admin app shell and navigation, dashboard, restaurant list and detail, status changes, plans editor, dietary label and tag editor, theme editor, platform config (reserved slugs, grace days, fonts, currencies), admin user management, announcements (simple banner text shown in the owner app).
**Out:** editing restaurant menu content (admins do not edit menus, §3.5).

## Data and backend

- Bootstrap: a one-off script `functions/scripts/makeAdmin.ts` sets `role: 'platformAdmin'` for the first admin. After that, `setAdminRole` (admin only, audit-logged).
- `setRestaurantStatus({restaurantId, status, reason})`: valid transitions active ↔ suspended, active/suspended → deactivated, deactivated → active (within 90 days). Revokes the owner's refresh tokens on suspend/deactivate. Audit-logged.
- `stats/platform`: counters kept by triggers (restaurants by status, subscriptions by status, total items, menu views).
- `upsertPlan`, `upsertLabel`, `upsertTag`, `upsertTheme`, `updatePlatformConfig`, `setAnnouncement`: admin only, validated, audit-logged.
- Restaurant search: Firestore queries on `nameLower` prefix, `slug`, `ownerEmail`, `mobile`; filters on status, plan, country, created date (composite indexes in `firestore.indexes.json`).

## Screens and responsive behaviour

The admin app is web-first but must not break on a tablet (768 px). Below 600 px it shows read-only views with a notice to use a larger screen for edits.

| Screen | Content |
| --- | --- |
| Dashboard | Tiles for FR-085 counts, pending upgrade requests, recent sign-ups |
| Restaurants | Searchable, filterable, paginated table; row → detail |
| Restaurant detail | Profile summary, public menu link, subscription and payments, activity (logins, publishes, plan changes), status actions with required reason |
| Plans | List and editor for limits and prices |
| Labels and tags | List with add, edit, retire, reorder |
| Themes | List and token editor with preview |
| Settings | Reserved slugs, grace days, fonts, currencies, announcement |
| Admins | List, add, remove (audit-logged) |

## Tasks

- [x] Admin app shell, navigation, guards (role + MFA required).
- [x] Bootstrap script and `setAdminRole`.
- [x] `stats/platform` triggers and dashboard.
- [x] Restaurant search, filters, pagination and indexes.
- [x] Restaurant detail and `setRestaurantStatus` with reasons and token revocation.
- [x] Plans, labels, tags, themes and settings editors with their callables.
- [x] Announcements: banner in the owner app.
- [x] Rules tests: owners cannot call or read admin data.

## Acceptance checks

- [x] AC-016: admin activates, suspends, deactivates and reactivates accounts.
- [x] A suspended owner is signed out and sees the suspension notice at login; the public menu shows the 503 page (M07).
- [x] An account without MFA cannot open the admin app.
- [x] Every action in this module creates an audit log entry.

## Tests

Functions: status transitions and invalid transitions, admin-only checks. Rules tests. Widget tests for the restaurant table at 768 and 1280 px.

## Completion notes

**What was built**

- **Functions** (`functions/src/admin/`; every callable starts with `assertAdmin`, which requires the admin role and a TOTP sign-in):
  - `restaurants.ts`:
    - `setRestaurantStatus({restaurantId, status, reason})`:
      - transitions (pure `canTransition`): active ↔ suspended, active / suspended → deactivated, and deactivated → active only within 90 days of `deactivatedAt`;
      - a reason of at least 3 characters;
      - writes `status`, `statusReason`, `statusChangedAt`, `statusChangedBy` and `deactivatedAt`, and mirrors the status to `users/{ownerUid}.accountStatus`;
      - revokes the owner's refresh tokens on suspend and deactivate;
      - audit `restaurant.suspend`, `.activate`, `.deactivate` or `.reactivate`, with the reason.
    - `adminSearchRestaurants`:
      - text: email (exact, lower case), mobile (exact E.164), or name prefix on `nameLower` plus an exact slug lookup;
      - filters: status, plan, country and registration dates (`createdAt`), newest first;
      - cursor paging of 25 by default.
    - `adminGetRestaurant`: profile summary, subscription, payments (FR-087), `subscriptionHistory`, activity, and sign-ins. Activity is publishes, rollbacks, plan changes and status changes from `auditLogs` (FR-089). Sign-ins are the creation, last sign-in and last activity times from Firebase Auth metadata.
  - `catalog.ts`:
    - `upsertPlan`: the Free plan stays free; the default theme must exist and be standard. `applyToSubscribers` copies the flags to the plan's restaurants (FR-077).
    - `upsertLabel` (`kind: label|tag`): the icon must be one of the keys `MenuLabelIcon` draws; ids are lower-case. Retire, never delete (FR-104).
    - `upsertTheme`: tokens are validated, and themes whose text fails AA are refused unless `acceptContrastFixes` is set (FR-060).
    - `updatePlatformConfig`: reserved slugs (deduplicated and sorted), grace days 0–30, fonts, currencies, and `supportEmail` (new; shown to blocked owners).
    - `setAnnouncement({text, level: info|warning, active, until?})`, stored in `config/platform.announcement`.
    - `adminListCatalog({kind})` for the editors.

    Audit actions: `plan.create` / `plan.update`, `label.*` / `tag.*` / `theme.*` (create, update, retire), `platform.updateConfig` and `platform.announcement`.
  - `admins.ts`:
    - `setAdminRole({email, grant, reason})`: the account must already exist. Owners can't become admins, and an admin can't remove their own role. Keeps the claim shape of `set-admin.mjs` and `users/{uid}.role`, revokes tokens, and audits `admin.grant` / `admin.revoke`.
    - `adminListAdmins`.
    - `adminDashboard`: stats, the pending upgrade count, and the last 10 sign-ups.
  - `stats.ts`:
    - **`onRestaurantStats`** (trigger on `restaurants/{rid}`) applies the difference of each write (pure `statsDelta`) to `stats/platform`: `restaurants`, `restaurantsByStatus.{active, suspended, deactivated, deleted}`, `subscriptionsByStatus.{free, active, grace}`, `totalItems`, and `subscriptionsExpired` (grace → free, cumulative).
    - `recomputePlatformStats` rebuilds the counters from aggregation queries (audit `platform.recomputeStats`).
  - The bootstrap is the existing `functions/scripts/set-admin.mjs` (M01), not a new `makeAdmin.ts`.
  - Composite indexes (`firestore.indexes.json`): restaurants `(status, createdAt desc)`, `(planId, createdAt desc)`, `(country, createdAt desc)` (Firestore merges them for combined filters) and `(subscription.status, status)`; auditLogs `(restaurantId, at desc)`.
- **Rules:** unchanged except tests. Owners read their own `users/{uid}` (with `accountStatus`) and `config/platform` (with the announcement and support email). Everything admin-only stays closed to clients: `auditLogs`, `stats`, `upgradeRequests`, payments, and status writes. `firestore-tests/test/admin.test.js`.
- **Admin app** (web-first; usable at 768 px; **read-only below 600 px**, with `ReadOnlyNotice` and actions hidden):
  - Sections: Dashboard, Restaurants, Upgrades (M10), Plans, Catalog (tabs: dietary labels, tags, themes) and Settings (platform settings, announcement, administrators).
  - Every read and write goes through `AdminApi` callables. The guards (admin role + TOTP) are unchanged from M01.
  - `DashboardPage`: 12 tiles for FR-085 (restaurants total / active / suspended / deactivated, Free / paid / in grace / expired, upgrade requests linking to the queue, menu items, menu views, QR visits), the recent sign-ups linking to the detail page, and "Recalculate".
  - `RestaurantsPage`: search plus status, plan, country and date-range filters; a `DataTable` from 600 px and cards below; previous / next pages; a row opens `/restaurants/:rid`.
  - `RestaurantDetailPage`:
    - cards for status (with actions), profile (with the public menu link to copy), subscription (record payment, extend, downgrade, each with a reason), payments, plan history and activity;
    - two columns from 1024 px;
    - **no menu editing** (§3.5).
  - `PlansPage` + `PlanEditor`: limits, flags, prices (one line per currency in minor units) and "apply to current subscribers".
  - `CatalogPage`:
    - labels and tags with add, edit and retire (id, name, icon, colour, order);
    - themes with token fields, a live preview using core's `resolveMenuTheme`, contrast warnings, and "save with the automatic fix".
  - `SettingsPage`: reserved slugs, grace days, fonts, currencies, support email; the announcement (text, level, show); administrators (list, add by email, remove; reason required).
  - Shared widgets (`lib/widgets/admin_widgets.dart`): `AdminPageBody`, `AdminSectionCard`, `askReason()` (every sensitive action), `runAdminAction()` and `StatusChip`. 171 strings.
- **Owner app:**
  - `AnnouncementBanner` at the top of the dashboard (`platformNoticeProvider` reads `config/platform`; info or warning; hidden after `until`).
  - `AccountBlockedPage`: when `users/{uid}.accountStatus` is `suspended` or `deactivated`, the shell shows only the notice with the support email and Sign out (FR-099).
  - 5 strings.

**Tests** (all passing at completion)

| Suite | Tests | M11 additions |
| --- | --- | --- |
| Functions unit | 319 | `admin/admin.test.ts` (13): every status transition and the 90-day window, audit action names, search text kinds, stats deltas (new, moves, expiry, unrelated writes, delete) |
| Functions emulator | 119 | `admin/admin.emu.test.ts` (11): every admin callable refuses owners and anonymous callers; suspend / activate / deactivate / reactivate with reasons, `accountStatus`, revocation, audit and the 90-day limit (AC-016); search by name prefix, slug, email and mobile, and filters; paging; the detail (payments, history, activity filter, sign-ins); labels (create / retire / invalid), themes (contrast refusal / accept), plans (apply to subscribers, guards, audit), config and announcement; admin grant / revoke (not self, not owners, unknown email); the stats trigger and the exact recompute; the dashboard |
| Rules | 160 | `admin.test.js` (2): owners read their account status and the announcement, never audit, stats or requests; nobody writes account status, config, audit, stats or restaurant status from a client |
| Admin app | 34 | `admin_pages_test.dart` (10): dashboard tiles and the link, restaurant table at 768 and 1280 (search, filter, paging, open), read-only cards at 360, detail at 768 and 1280 (suspend with reason, downgrade with reason), detail read-only at 360, plan editor, label retire and theme list, settings (config, announcement, add admin). The shell test checks the read-only notice at 360 |
| Owner app | 220 | `account_notices_test.dart` (6): the announcement at 360/768/1280, expiry, suspended and deactivated notices with support contact and sign-out |

**Decisions that differ from the plan**

1. **Logins in the activity view come from Firebase Auth metadata** (account created, last sign-in, last activity), not a per-login log. Recording every sign-in needs a blocking function (Identity Platform) or a client call. It can be added with Identity Platform (M01 Open items).
2. **Suspension reaches the owner app through `users/{uid}.accountStatus`.** The restaurant document itself is unreadable for a non-active restaurant (`isOwner()` requires `active`), and the guard needs to know why. Tokens are revoked as well.
3. **"Expired subscriptions" (FR-085) is cumulative:** paid plans that ran out to date. The model has no lasting "expired" state; an expired plan becomes Free (M10).
4. **Sections:** Upgrades (M10) and Catalog (labels, tags, themes in tabs) are top-level; the admins list is a card in Settings rather than its own section, to keep six destinations on the navigation bar. The M12 audit log viewer adds its own section.
5. **`supportEmail` was added to `config/platform`** for the blocked-account notice ("support contact", FR-099).
6. **Search is exact for email, mobile and slug and prefix for names.** Firestore has no substring search. Combining the name search with the date filter is done in memory on the result page.

## Open items

- **TOTP on a real project** (M01 Open items): the admin app's MFA works against the fake and on the emulator, where `assertAdmin` skips the factor. Identity Platform must be enabled before admins can sign in on dev or prod.
- **Indexes:** deploy `firestore.indexes.json` (`firebase deploy --only firestore:indexes`) before using the restaurant filters on a real project; the emulator does not enforce indexes.
- **Stats on an existing project:** run "Recalculate" on the dashboard once after deploying (restaurants created before the trigger aren't counted until then).
- **Check by hand** in a browser at 768 and 1280 px: filters with real data, a suspension (the owner is signed out within the hour; their next sign-in shows the notice), and an announcement appearing on an owner dashboard.

## Change log

- 2026-11-14: Plan created.
- 2026-11-15: Done. Admin callables (status with transitions, reasons, token revocation and `accountStatus`; search with filters and cursors; detail with payments, history and activity; plans, labels, tags, themes, config, announcement, admin roles, dashboard), `stats/platform` trigger with recompute, indexes; admin app dashboard, restaurants, detail, plans, catalog and settings (read-only below 600 px); owner announcement banner and blocked-account notice.
- 2026-11-15: **Change plan** on the restaurant detail's subscription card (`ChangePlanDialog`, `lib/features/subscriptions/presentation/change_plan_dialog.dart`): an admin moves a restaurant to any other active plan without a payment (trials, complimentary upgrades, corrections) through `changeSubscription` `action: modify`, with a reason. Paid plans take start and end dates (default today to one month); free plans take none and warn that over-limit content is hidden. Hidden at 360 px like every admin write. Tests in `test/admin_pages_test.dart` (promote at 768 and 1280, Pro to Free, refused change, read-only at 360).
- 2026-11-15: **Portal layout.** The restaurant detail page stays inside the shell (no longer on the root navigator), so the side menu or rail, the header and the new footer stay in place and only the content changes. The header shows a back button on detail routes (`AdminShell.backTo`, `AdminShell.backKey`); the page heads its content with the restaurant name (`DetailKeys.heading`). `AdminFooter`: copyright and a Development badge on non-production builds, pinned under the content from 600 px. Tests: footer per width (`shell_test.dart`), detail inside the portal and back to the list (`admin_pages_test.dart`).
- 2026-11-16: **Portal header on desktop.** From 1024 px the header spans the full width: a brand segment with the logo above the side menu, then the page title, back button and sign-out above the content. Shared with the owner app through `ResponsiveScaffold`. Tests: `responsive_scaffold_test.dart` (brand segment lines up with the side menu).
