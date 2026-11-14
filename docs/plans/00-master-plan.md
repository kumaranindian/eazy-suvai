# EazySuvai MVP – Master plan

The MVP is built in 14 modules, M00 to M13, in the order below. Each module has its own plan file in this folder and an implementation prompt in `docs/prompts/module-prompts.md`.

**Update rule:** when a module changes status, update its row here and its own plan file in the same commit (see `AGENTS.md`, "Updating the plan when a module is done").

Status values: `Not started` · `In progress` · `Blocked` · `Done`

## Module tracker

| # | Module | Plan file | Depends on | Status | Started | Completed | Note |
| --- | --- | --- | --- | --- | --- | --- | --- |
| M00 | Foundation and project setup | `M00-foundation.md` | – | Done | 2026-11-14 | 2026-11-14 | Workspace, core, shells, rules, functions lib, CI. Open: prod project; dev Android/iOS options, Hosting sites and TTL. (Dev `eazy-suvai-dev` web connected; CI green on GitHub.) |
| M01 | Authentication and accounts | `M01-authentication.md` | M00 | Done | 2026-11-14 | 2026-11-14 | Sign-up, verify, login, reset, claims, guards, cleanup, admin TOTP. Open: Identity Platform TOTP on a real project (approval), auth project settings, FR-091 24 h link expiry. |
| M02 | Media management | `M02-media.md` | M00 | Not started | | | |
| M03 | Restaurant onboarding and profile | `M03-restaurant-profile.md` | M01, M02 | Not started | | | |
| M04 | Menu management (categories and items) | `M04-menu-management.md` | M03 | Not started | | | |
| M05 | Menu customization (themes) | `M05-customization.md` | M03 | Not started | | | |
| M06 | Preview, publishing and versions | `M06-publishing.md` | M04, M05 | Not started | | | |
| M07 | Public digital menu | `M07-public-menu.md` | M06 | Not started | | | |
| M08 | QR codes and sharing | `M08-qr-sharing.md` | M07 | Not started | | | |
| M09 | Analytics | `M09-analytics.md` | M07 | Not started | | | |
| M10 | Subscriptions and plan limits | `M10-subscriptions.md` | M04, M11 (plans screen) | Not started | | | |
| M11 | Platform administration | `M11-platform-admin.md` | M01, M03 | Not started | | | |
| M12 | Audit, account lifecycle and data retention | `M12-lifecycle.md` | M10, M11 | Not started | | | |
| M13 | Hardening, acceptance and launch | `M13-launch.md` | All | Not started | | | |

M10 and M11 can be built in parallel once M04 is done; M10 needs M11's plan-editing screen only for its admin activation screen.

## Suggested order and milestones

| Milestone | Modules | What you can demo |
| --- | --- | --- |
| 1. Owner can sign up | M00, M01, M02, M03 | Register, verify email, log in, fill in the profile, upload a logo |
| 2. Owner can build a menu | M04, M05 | Categories, items, prices, availability, theme |
| 3. Customers can scan | M06, M07, M08 | Publish, open the public menu on a phone, download the QR code |
| 4. Business ready | M09, M10, M11, M12 | Analytics, Free/Pro plans, admin panel, audit and deletion |
| 5. Launch | M13 | All 30 acceptance criteria pass |

## FRD acceptance criteria coverage

| AC | Module | | AC | Module |
| --- | --- | --- | --- | --- |
| AC-001 | M01 | | AC-016 | M11 |
| AC-002 | M03 | | AC-017 | M00 (pattern), every module (tests) |
| AC-003 | M04 | | AC-018 | M10 |
| AC-004 | M04 | | AC-019 | M07 |
| AC-005 | M02 | | AC-020 | – (no ordering) |
| AC-006 | M04, M07 | | AC-021 | M01, M06 |
| AC-007 | M04, M07 | | AC-022 | M06 |
| AC-008 | M07 | | AC-023 | M03, M07 |
| AC-009 | M07, all UI modules | | AC-024 | M07, M11 |
| AC-010 | M08 | | AC-025 | M10 |
| AC-011 | M08 | | AC-026 | M10 |
| AC-012 | M05, M07 | | AC-027 | M04 |
| AC-013 | M06 | | AC-028 | M04 |
| AC-014 | M08 | | AC-029 | M04, M07 |
| AC-015 | M09 | | AC-030 | M10, M11 |

## Cross-module notes

Add a dated line whenever a module changes something another module depends on.

- 2026-11-14 (M00): Cloud Functions run on **Node 22** (not 20). AGENTS.md is updated.
- 2026-11-14 (M00): Shared function helpers are in `functions/src/lib/` (`assertOwner(auth, rid, {db, allowedStatuses})`, `assertAdmin(auth)`, `writeAudit(entry, {transaction|batch})`, `parseInput(schema, data)`, `appError(code, msg)`). Error wire codes in `functions/src/lib/errors.ts` must match `AppErrorCode` in `packages/core/lib/src/errors/app_error.dart`; add new codes to both, with an `.arb` message.
- 2026-11-14 (M00): Call Functions through `regionalFunctions` from `core` (asia-south1). `FirebaseFunctions.instance` defaults to us-central1.
- 2026-11-14 (M00): Each app has `router/auth_guard.dart` (`authGuard(ref, state)`, currently returns null) and `Routes` in `router/app_router.dart`. Add sections to the `OwnerSection` / `AdminSection` enums and branches in the `StatefulShellRoute`.
- 2026-11-14 (M00): Both rules files deny everything. Each module opens its own paths and adds tests in `firestore-tests/test/` (node --test). Replace the matching expectations in `baseline.test.js`.
- 2026-11-14 (M00): Normal-size text must use `BrandColors.orangeText` / `greenText` (AA). `#FF7A00` and `#C8650A` are for large text and decoration only. M05/M07 must check restaurant theme colours for contrast (architecture §6).
- 2026-11-14 (M00): Emulator runs use project `demo-eazysuvai` (`--dart-define=USE_EMULATORS=true`). Real dev project is `eazy-suvai-dev` (web options set in both apps); prod is not created yet. See M00 Open items.
- 2026-11-14 (M00): The `menu` Hosting target serves the static placeholder `hosting/menu/`. M07 replaces it with a rewrite of `**` to `renderMenu`.
- 2026-11-14 (M01): **Custom claims:** owners `{role: 'owner', restaurantId: '<rid>'}`; admins `{role: 'platformAdmin'}`. Set only by `completeRegistration` and `functions/scripts/set-admin.mjs` (M11's `setAdminRole` takes over). Apps read them through `AuthSession` (`authSessionProvider` in `core`: `isOwner`, `isAdmin`, `restaurantId`, `signedInWithTotp`).
- 2026-11-14 (M01): **`restaurants/{rid}` at creation:** `name`, `nameLower`, `ownerUid`, `ownerName`, `ownerEmail` (lower case), `ownerMobile` (E.164), `businessType` (`BusinessType.name`), `country` (ISO alpha-2), `currency`, `timezone` (from the country), `contact: {city?}`, `slug`, `qrCode`, `status: 'active'`, `planId: 'free'`, `subscription: {status: 'free', startAt, expiresAt: null, graceEndsAt: null}`, `counts: {categories: 0, items: 0}`, `publishedVersion: null`, `pricesNeedReview: false`, `themeId: null`, `draftUpdatedAt`, `createdAt`. `users/{uid}`: `email`, `displayName`, `mobile`, `role`, `restaurantId`, `createdAt`. `slugs/{slug}`: `{restaurantId, current: true, createdAt}`. `qrCodes/{code}`: `{restaurantId, kind: 'restaurant', createdAt}`; codes are 8 upper-case characters from `23456789ABCDEFGHJKMNPQRSTUVWXYZ` (M07/M08: upper-case `/q/{code}` before the lookup).
- 2026-11-14 (M01): **`plans/free` does not exist yet.** Restaurants point to `planId: 'free'` (`FREE_PLAN_ID` in `functions/src/auth/register.ts`). M10 must create that document with this id.
- 2026-11-14 (M01): **Slug helpers** `slugify`, `isValidSlug`, `slugCandidates` (`functions/src/auth/slug.ts`) and `reservedSlugs(db)` (`register.ts`; reads `config/platform.reservedSlugs`, falls back to `DEFAULT_RESERVED_SLUGS`). M03's `changeSlug` should reuse them. Any existing `slugs` doc (current or old) blocks a slug.
- 2026-11-14 (M01): **Admin MFA is enforced:** rules `isAdmin()` and `assertAdmin()` require `firebase.sign_in_second_factor == 'totp'` (new error code `mfa-required`). On the Functions emulator under a `demo-` project `assertAdmin()` skips the check, and the admin app skips enrolment when `USE_EMULATORS=true`. **The rules never skip it**, so admin screens on the emulators must read data through callables; rules tests use `mfaAdminClaims` from `firestore-tests/test/helpers.js`.
- 2026-11-14 (M01): **Rules opened:** `users/{uid}` (get: the verified user, admins; list: admins) and `restaurants/{rid}` (get: verified owner of an active restaurant via `isOwner(rid)`, admins; list: admins; no client writes yet, M03 adds the owner `update` whitelist). `baseline.test.js` lists opened paths in `OPENED`.
- 2026-11-14 (M01): **Routes:** owner `/sign-in`, `/sign-up`, `/verify-email`, `/forgot-password`, `/finishing-setup`, `/splash`; admin `/sign-in`, `/mfa-setup`, `/splash`. Guards are the pure functions `ownerRedirect` / `adminRedirect` (tested). Account screens use `NoTransitionPage`. Sign-out is an app-bar action in both shells.
- 2026-11-14 (M01): **Shared code in `core`:** `Validators` (email, password ≥ 8, mobile by country → E.164), `Countries` (keep in sync with `functions/src/auth/countries.ts`), `BusinessType`, `AuthLayout`, `AppPasswordField`, `FormMessage`, `CoreLocalizations.messageForError(e)` for any auth or callable error. Widget tests override `authRepositoryProvider` with `FakeAuthRepository` from `package:core/testing.dart`.
- 2026-11-14 (M01): **Error codes added:** `registration-incomplete`, `mfa-required` (functions `errors.ts`, Dart `AppErrorCode`, `core_en.arb`).
- 2026-11-14 (M01): **Tests:** functions emulator tests are `*.emu.test.ts` (`npm run test:emulators`, `tool/check.sh emulators`); the Flutter end-to-end test runs with `tool/integration.sh` (headless Chrome + emulators).

## Open decisions

- Final domains for app, admin and public menu (placeholders in `docs/architecture.md`).
- Pro plan prices per currency.
- Whether to enable Identity Platform now for admin MFA (required by FR-084). The M01 code is ready; it needs the real projects and your approval (paid product with a free tier).
- FR-091 asks for 24-hour verification links; Firebase sets its own expiry. Accept it, or send custom verification emails (needs a mail provider).
- Whether Free-plan menus show a "Powered by EazySuvai" footer (not yet in the FRD; M07 builds it behind a plan flag).
