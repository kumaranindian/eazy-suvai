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
- M03 (done 2026-11-14): `nameLower` is kept in sync with `name` by `onRestaurantUpdated` (use it for prefix search). Owner slug changes write `auditLogs` entries with `action: 'restaurant.changeSlug'`, `details {from, to, reclaimed}`. `Restaurant.fromMap` in core reads the whole tenant root, including `setupCompletedAt`.

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
