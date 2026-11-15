# M11 – Platform administration

Status: Not started
Started:
Completed:

## Goal

A separate, MFA-protected admin web app where AVAIL404 staff monitor the platform, find restaurants, change account status, and manage plans, labels, tags, themes and platform settings, with every sensitive action audit-logged.

## FRD coverage

FR-009, FR-010, FR-059, FR-084 to FR-090, FR-099 (status changes), FR-104, §3.1, §3.5, BR-014, AC-016, AC-024 (status part), AC-030 (admin part).

## Depends on

M01 (admin login and MFA), M03 (restaurant data).

## Inputs from other modules

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

- [ ] Admin app shell, navigation, guards (role + MFA required).
- [ ] Bootstrap script and `setAdminRole`.
- [ ] `stats/platform` triggers and dashboard.
- [ ] Restaurant search, filters, pagination and indexes.
- [ ] Restaurant detail and `setRestaurantStatus` with reasons and token revocation.
- [ ] Plans, labels, tags, themes and settings editors with their callables.
- [ ] Announcements: banner in the owner app.
- [ ] Rules tests: owners cannot call or read admin data.

## Acceptance checks

- [ ] AC-016: admin activates, suspends, deactivates and reactivates accounts.
- [ ] A suspended owner is signed out and sees the suspension notice at login; the public menu shows the 503 page (M07).
- [ ] An account without MFA cannot open the admin app.
- [ ] Every action in this module creates an audit log entry.

## Tests

Functions: status transitions and invalid transitions, admin-only checks. Rules tests. Widget tests for the restaurant table at 768 and 1280 px.

## Completion notes

_Fill in when done._

## Open items

## Change log

- 2026-11-14: Plan created.
