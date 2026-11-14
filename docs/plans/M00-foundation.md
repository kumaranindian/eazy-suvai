# M00 – Foundation and project setup

Status: Done
Started: 2026-11-14
Completed: 2026-11-14

## Goal

A working monorepo with both Flutter apps, the shared core package, Cloud Functions, security rules, emulators and CI, so every later module only adds features.

## FRD coverage

§6 (globalization groundwork), §7.2 (HTTPS, rules), §7.5 (consistent UI), §12 (module layout), AC-017 (isolation pattern), BR-019 (money type).

## Depends on

Nothing.

## Inputs from other modules

None.

## Scope

**In:** repo layout (`docs/architecture.md` §6), Firebase projects and config, emulators, base security rules (deny all), shared helpers, theme, responsive shell, localization, money and time utilities, CI.
**Out:** any feature screens.

## Tasks

- [x] Create the Dart pub workspace: `apps/owner_app` (web, android, ios), `apps/admin_app` (web), `packages/core`.
- [x] Add packages: flutter_riverpod + riverpod_generator, go_router, freezed + json_serializable, firebase_core, firebase_auth, cloud_firestore, firebase_storage, cloud_functions, intl, flutter_localizations.
- [ ] Create Firebase projects `eazysuvai-dev` and `eazysuvai-prod`; run FlutterFire configure for both; select with `--dart-define=ENV`. *(ENV selection done; projects and FlutterFire configure blocked, see Open items.)*
- [x] `firebase.json` with Firestore, Storage, Functions (`asia-south1`), Hosting sites `app`, `admin`, `menu`, and the Emulator Suite.
- [x] `firestore.rules` and `storage.rules` that deny everything by default; `firestore-tests/` project with one passing test.
- [x] `functions/` TypeScript project (Node 22, changed from Node 20, see Completion notes; ESLint, Jest, zod); shared lib: `writeAudit()`, `assertAdmin()`, `assertOwner()`, `HttpsError` code list.
- [x] `packages/core`: `Money` (int minor units + ISO code, formatting by currency decimals: INR 2, AED 2, SAR 2, QAR 2, USD 2, KWD 3, BHD 3, OMR 3), `TimeService` (UTC ↔ restaurant time zone), `Breakpoint` + `ResponsiveScaffold`, `AppTheme` (light and dark) from the brand colours, common widgets (buttons, text fields, empty/error/loading states, confirm dialog).
- [x] Localization: `l10n.yaml`, `app_en.arb`; direction-neutral widgets only.
- [x] go_router skeleton with placeholder routes and an auth-guard hook (filled in M01).
- [x] App icons and favicons from `docs/brand/` for owner and admin apps.
- [x] CI (GitHub Actions): `flutter analyze`, `flutter test`, functions lint and test, rules tests on emulators.
- [x] README: how to run each app and the emulators.

## Screens and responsive behaviour

Only the shell: a placeholder home page inside `ResponsiveScaffold` showing bottom bar (< 600), rail (600–1023) and side menu (≥ 1024).

## Acceptance checks

- [x] `flutter run -d chrome` starts both apps against the emulators. *(Verified with emulator-mode web builds of both apps in Chrome at 360, 768 and 1280 px: Firebase connected to the Auth/Firestore/Storage/Functions emulators, no console errors, deep links such as `/restaurants` open the right section.)*
- [x] The shell switches navigation style at 599/600 and 1023/1024 px. *(Widget tests at 360, 599, 600, 768, 1023, 1024, 1280.)*
- [x] `Money(129900, 'INR')` formats as ₹1,299.00 and `Money(1250, 'KWD')` as KWD 1.250.
- [ ] CI passes on a clean clone. *(`tool/check.sh`, which is exactly what CI runs, passes on a clean export of the tracked files. Not yet run on GitHub Actions because the repo has no remote. See Open items.)*
- [x] Rules tests prove an unauthenticated user can read nothing.

## Tests

Unit tests for `Money` and `TimeService`; widget tests of the shell at 360, 768 and 1280 px; one rules test; one functions test for `assertOwner`.

Delivered: 45 tests in `packages/core` (money, time, breakpoints/shell incl. RTL, theme contrast, widgets, env), 5 widget tests per app (shell at 3 widths, every route, not-found), 26 Jest tests in `functions` (assertOwner ×13, assertAdmin, audit, validation, error codes), 16 rules tests (Firestore and Storage, 4 caller types). A mutation check confirmed the rules tests fail when reads are opened.

## Completion notes

**What was built**

- **Workspace:** root `pubspec.yaml` (Dart pub workspace: `apps/owner_app`, `apps/admin_app`, `packages/core`), shared `analysis_options.yaml`, `.gitignore`, `.gitattributes` (LF).
- **`packages/core`** (`lib/core.dart` exports everything):
  - `money/`: `Money` (int `minor` + `Currency`; `format()`, `parse()` from user text without `double`, `toDecimalString()`, arithmetic, `toJson()` → `{amountMinor, currency}`), `Currencies` registry with the 8 FRD §6.2 currencies and `register()` for `config/platform.currencies`.
  - `time/`: `TimeService` (injectable clock, `toZone`, `fromZone`, `dayKey` → `yyyy-MM-dd` in the restaurant zone, `startOfDayUtc`, `isValidZone`).
  - `layout/`: `Breakpoint` (600/1024, 240 px side menu, 1200 px max content), `ResponsiveScaffold` + `AppDestination`.
  - `theme/`: `BrandColors`, `AppTheme.light` / `.dark` (Material 3, 48 px buttons).
  - `widgets/`: `AppPrimaryButton`, `AppSecondaryButton`, `AppIconButton` (required semantics label), `AppTextField`, `LoadingState`, `EmptyState`, `ErrorState`, `showConfirmDialog` / `ConfirmDialog`.
  - `errors/`: `AppErrorCode` (wire codes shared with functions) and `CoreLocalizations.messageFor(code)`.
  - `config/`: `AppEnv` (`ENV`, `USE_EMULATORS`, `EMULATOR_HOST` dart-defines), `initFirebase()`, `regionalFunctions` (asia-south1), `EmulatorPorts`.
  - `l10n/arb/core_en.arb` → `CoreLocalizations`.
- **Apps** (`apps/owner_app`, `apps/admin_app`), same shape:
  - `main.dart` (path URL strategy, env + Firebase bootstrap), `app.dart` (`MaterialApp.router`, light/dark theme, `AppLocalizations` + `CoreLocalizations`).
  - `router/app_router.dart`: `appRouterProvider` (riverpod_generator), `StatefulShellRoute` with one branch per section, `/sign-in` placeholder, not-found page.
  - `router/auth_guard.dart`: `authGuard(ref, state)` returns `null` (hook for M01/M11).
  - `features/shell/presentation/*_shell.dart`: `OwnerSection` / `AdminSection` enums.
  - `firebase_options_dev.dart` / `_prod.dart`: placeholders that throw until FlutterFire configure is run.
  - Owner routes: `/`, `/menu`, `/share`, `/settings`, `/sign-in`. Admin routes: `/`, `/restaurants`, `/plans`, `/settings`, `/sign-in`.
- **Firebase:** `firebase.json` (Firestore `(default)` in asia-south1, Storage, Functions nodejs22, Hosting targets `app` → `apps/owner_app/build/web`, `admin` → `apps/admin_app/build/web` with `noindex`, `menu` → `hosting/menu` placeholder; HSTS and security headers; emulator ports), `.firebaserc` (aliases `dev`, `prod`, plus Hosting target → site names), deny-all `firestore.rules` and `storage.rules`, empty `firestore.indexes.json`.
- **Functions** (`functions/src/lib/`): `assertSignedIn`, `assertAdmin`, `assertOwner(auth, restaurantId, {db, allowedStatuses})` (checks auth → email verified → `owner` role and `restaurantId` claim → restaurant exists, `ownerUid` matches, status allowed), `writeAudit(entry, {transaction | batch | db, now})` (zod-validated, server timestamp `at`, `expireAt` = +2 years), `appError(code, message)`, `appErrorCodeOf()`, `parseInput(schema, data)`. `src/index.ts` sets global region `asia-south1`. No deployed functions yet.
- **Rules tests** (`firestore-tests/`): `node --test` with `@firebase/rules-unit-testing`, run through `firebase emulators:exec --project demo-eazysuvai`.
- **CI:** `.github/workflows/ci.yml` (jobs `flutter`, `functions`, `rules`), all calling `tool/check.sh`. The Flutter job regenerates l10n and riverpod code, formats, and fails if anything differs from what is committed.
- **Brand:** web favicons, manifest and `apple-touch-icon` in both apps; Android/iOS launcher icons via `flutter_launcher_icons` (source `apps/owner_app/branding/app_icon.png`); logos (480 px wide, light and dark) in `assets/brand/`.
- **README.md:** setup, emulators, environments, connecting the real projects, checks, deploy.

**Decisions that differ from the plan**

1. **Cloud Functions on Node 22, not Node 20.** Node 20 reached end of life in April 2026, and firebase-admin 14 requires Node 22 or later. The user approved this. Updated in `AGENTS.md`.
2. **Accessible text colours.** The brand deep orange `#C8650A` is about 3.9:1 on white and leaf green `#4C9A2A` about 3.5:1. Both fail WCAG AA for normal text, which AGENTS.md requires. The theme therefore uses `#A8550A` and `#3B7A20` for normal-size text and filled buttons, and keeps the brand colours for large text and decoration. Documented in `docs/architecture.md` §6.
3. **Emulator demo project.** With `USE_EMULATORS=true` the apps and tests use project `demo-eazysuvai` with built-in demo options, so local development never needs real Firebase config or touches a real project. `ENV=prod` ignores `USE_EMULATORS`.
4. **Generated code is committed** (`lib/**/l10n/generated/`, `*.g.dart`). CI regenerates it and checks for differences.
5. **Functions tests use injected fakes**, not the emulator, for `assertOwner` and `writeAudit`. Rules tests run on the emulators. `writeAudit` takes a Firestore transaction or batch so the audit entry commits atomically with the change it records.
6. **`getPlanLimits()`** (architecture §7 "Shared") was not in this plan's task list. It is left to M10.
7. **Toolchain pins:** Flutter 3.32.8 / Dart 3.8.1 (user's choice) → Riverpod 3.1 + riverpod_annotation 4.0 + riverpod_generator 4.0, go_router 17, freezed 3.2, Firebase core 5 / auth 7 / firestore 7. Android needs `minSdk` 24, Kotlin Gradle plugin 2.3.0 (the Firebase Android SDK ships Kotlin 2.4 metadata) and NDK 27.0.12077973.
8. **Path URLs on web** (`usePathUrlStrategy`) so deep links like `/menu` work with the Hosting SPA rewrite.

## Open items

- **Firebase projects not created.** `firebase projects:create eazysuvai-dev` failed: "you have exceeded your allotted project quota". Free up quota or request more, then follow README → "Connecting the real projects" (create both projects in asia-south1, run `flutterfire configure` for each app and env, create the 6 Hosting sites, enable TTL on `auditLogs.expireAt` and `analyticsEvents.expireAt`). The apps run on the emulators until then. Running with `USE_EMULATORS=false` throws a clear error.
- **CI not yet run on GitHub Actions.** The folder had no git remote. `tool/check.sh` (what CI runs) passes on a clean export. Push to GitHub and confirm the three jobs are green.
- **iOS build not verified.** Windows can't build iOS. The Android debug APK builds.
- **Brand assets duplicated at the repo root** (`eazysuvai-brand-kit/`, `EazySuvai Taste Meets Technology Logo.png`). Left untracked for the owner to keep or delete. `docs/brand/` is the source.
- Android `applicationId` is `com.avail404.eazysuvai.owner_app` and the iOS bundle ID is `com.avail404.eazysuvai.ownerApp` (Flutter defaults). Confirm the final store IDs before the first store upload (M13).

## Change log

- 2026-11-14: Plan created.
- 2026-11-14: Module built. Status Done, with open items: real Firebase projects (quota) and the first GitHub Actions run. Functions moved to Node 22; accessible text colours added.
