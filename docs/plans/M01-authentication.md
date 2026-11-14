# M01 – Authentication and accounts

Status: Done
Started: 2026-11-14
Completed: 2026-11-14

## Goal

Owners can register, verify their email, log in, log out and reset their password. Each owner gets a restaurant tenant, and roles are enforced on the server.

## FRD coverage

FR-001 to FR-007, FR-091, FR-004 (one email = one account = one restaurant), BR-001, BR-017, §7.2 (password and session rules), AC-001, AC-021 (login part).

## Depends on

M00.

## Inputs from other modules

- M00 (done 2026-11-14): fill `authGuard(ref, state)` in each app's `router/auth_guard.dart`; use `assertSignedIn`/`assertOwner`/`assertAdmin`, `writeAudit`, `parseInput`, `appError` from `functions/src/lib/`; map `details.code` with `AppErrorCode.fromWire` + `CoreLocalizations.messageFor`; call functions via `regionalFunctions`; widgets in `packages/core`. Emulator project `demo-eazysuvai`.
- M00: router guard hook, `writeAudit()`, error code list, core widgets.

## Scope

**In:** sign-up form, email verification flow, login, logout, password reset, custom claims, route guards, unverified-account cleanup, admin login with MFA (shell only; admin features come in M11).
**Out:** restaurant profile screens (M03), staff accounts (Phase 2), mobile OTP (Phase 2).

## Data and backend

- Sign-up: client calls `createUserWithEmailAndPassword`, then the callable `completeRegistration({restaurantName, ownerName, mobile, country, businessType})`.
- `completeRegistration` in one transaction: creates `users/{uid}` and `restaurants/{rid}` (status `active`, `planId` = Free plan, currency and time zone defaulted from the country), reserves a slug (`slugs/{slug}`, rules in FR-092) and a permanent QR code (`qrCodes/{code}`, 8 characters, no 0/O/1/I/L), sets claims `{role: 'owner', restaurantId}`, then sends the verification email.
- The client signs out right after registration and shows "Check your email".
- Login: if `emailVerified` is false, sign out and show "Verify your email" with a resend button (FR-091).
- `cleanupUnverifiedUsers` (daily): deletes accounts unverified for 7 days, their restaurant, slug and QR code.
- Password policy (Firebase Auth password policy): at least 8 characters. Turn on email enumeration protection. Brute-force lockout comes from Firebase Auth's built-in throttling plus App Check.
- Validate mobile numbers with the `phone_numbers_parser` package against the chosen country.

## Screens and responsive behaviour

| Screen | Compact | Expanded |
| --- | --- | --- |
| Sign up | Full-width single column, sections stacked | Two panes: brand panel left (logo, tagline), form right, form max 480 px |
| Check your email | Centred message, resend button | Same, centred card |
| Log in | Full width | Brand panel + form |
| Forgot password | Full width | Centred card |

## Tasks

- [x] Sign-up form with validation (FR-002, FR-003), country picker, business type list.
- [x] `completeRegistration` callable with slug and QR code generation; reserved slug list from `config/platform`.
- [x] Verification email sending and resend (rate-limited to once a minute in the UI).
- [x] Login, logout, password reset (link valid 60 min, Firebase default 1 h).
- [x] Riverpod `authStateProvider` that refreshes the ID token after verification so claims are present. *(Named `authSessionProvider` in `core`.)*
- [x] go_router guards: unauthenticated → login; unverified → verify page; owner without claims → "finishing setup" retry.
- [x] `cleanupUnverifiedUsers` scheduled function.
- [x] Admin app login page with TOTP MFA enrolment and challenge (Identity Platform). *(Built and tested with a fake TOTP backend. Not yet run against real Identity Platform: see Open items.)*
- [x] Rules: `users/{uid}` readable only by that user and admins; `restaurants/{rid}` read needs a verified email.
- [x] Error messages mapped from Firebase error codes to `.arb` strings.

## Acceptance checks

- [x] AC-001: register, verify, log in, log out, reset password. *(Verified on the emulators: `apps/owner_app/integration_test/sign_up_flow_test.dart` in headless Chrome (sign up → refused before verification → verify link → sign in → read own restaurant → sign out → reset email sent), and `functions/src/auth/e2e.emu.test.ts` (the reset link sets a new password, works once, and the old password stops working).)*
- [x] An unverified owner cannot log in and cannot read any Firestore data even with a token. *(App: signed out at once, widget and integration tests. Rules: `accounts.test.js` denies `users` and `restaurants` reads with valid owner claims but `email_verified: false`; a mutation check confirmed these tests fail when the rule only requires sign-in.)*
- [x] Registering a second time with the same email shows a clear error (FR-004). *(Auth refuses the email (`EMAIL_EXISTS`, emulator test); the form shows "An account with this email already exists…". A second `completeRegistration` call for the same user returns the existing restaurant and never creates another, including two concurrent calls.)*
- [x] The new restaurant has a unique slug, a QR code and the Free plan. *(Emulator tests: slug collisions, city and number suffixes, reserved words, old slugs; QR retry on collision; `planId: 'free'`.)*
- [x] Screens work at 360, 768 and 1280 px. *(Widget tests of every account screen in both apps at the three widths, and headless Chrome screenshots of the built web apps: no overflow, no horizontal scroll, no console errors.)*

## Tests

Functions: `completeRegistration` (happy path, duplicate, reserved slug collision, slug suffixing). Rules: unverified and cross-tenant reads denied. Widget: sign-up validation. Integration: full sign-up → verify (emulator link) → login.

Delivered:

- **Functions:** 68 Jest unit tests (`npm test`; 42 new: slug rules, QR alphabet, registration schema and mobile per country, `assertAdmin` MFA) and 15 emulator tests (`npm run test:emulators`): `registerOwner` ×11 (happy path, idempotent repeat, concurrent race, lost-claims resume, city then number suffix, released slug, reserved words from `config/platform` and the defaults, QR collision, country defaults, bad callers and input), `cleanupUnverifiedUsers` ×2, end to end over HTTP ×2 (Auth REST → callable → verify link → claims → reset link).
- **Rules:** 29 tests (13 new in `accounts.test.js`: own profile, unverified denied, cross-tenant denied, suspended restaurant, no client writes, admin with and without TOTP, slugs and QR codes closed). The baseline now skips only the paths listed in `OPENED`.
- **Flutter:** `core` 82 (37 new: validators, mobile by country, error mapping, `AuthSession`, `safeFromParam`, `AuthLayout` at 3 widths, password field). Owner app 29 (guard table, sign-up validation, sign-up happy path, duplicate email, retry after failure, sign-in incl. `from`, wrong password, throttling, unverified + resend + cooldown, reload, admin refused, finishing setup ×2, forgot password, every account screen at 3 widths, sign-out). Admin app 19 (guard table, enrol → sign in with code, wrong codes, owner refused, unverified admin, cancel, emulator mode, 3 widths, sign-out).
- **Integration:** `tool/integration.sh` runs `integration_test/sign_up_flow_test.dart` with `flutter drive` in headless Chrome against the Auth, Firestore and Functions emulators.

## Completion notes

**What was built**

- **Functions (`functions/src/auth/`)**
  - `completeRegistration` (callable, asia-south1) → `registerOwner()` in `register.ts`. Input `{restaurantName, ownerName, mobile, country, businessType, city?}` (zod, `.strict()`; mobile checked against the country with `libphonenumber-js` and stored as E.164). One transaction creates `users/{uid}`, `restaurants/{rid}` (Firestore auto-ID), `slugs/{slug}`, `qrCodes/{code}` and an `auditLogs` entry (`restaurant.register`). Then it sets the claims `{role: 'owner', restaurantId}`, keeping any other claims. It is idempotent: if `users/{uid}` exists it re-applies the claims and returns `{created: false}`. Called with `{}` and no restaurant, it fails with `registration-incomplete`. Admins and non-password sign-ins are refused.
  - `slug.ts`: FR-092 format and the reserved list. Candidate order: name → name-city → name-city-2, 3… (name-2… without a city). Names with no Latin letters fall back to `restaurant`. Any existing `slugs` doc blocks a slug, including old and released ones. Reserved words come from `config/platform.reservedSlugs`, or the FR-092 list when that field is missing.
  - `qr-code.ts`: 8 characters from `23456789ABCDEFGHJKMNPQRSTUVWXYZ` (upper case, `crypto.randomInt`); retried on collision.
  - `countries.ts`: IN, AE, KW, SA, QA, BH, OM, US → currency and IANA time zone; business types.
  - `cleanupUnverifiedUsers` (schedule `every day 03:30` UTC) → `cleanup.ts`. Pages through Auth users and deletes those unverified for ≥ 7 days (never `platformAdmin`), with their `users` doc, restaurant (and any subcollections), `slugs` and `qrCodes` docs, plus an `account.purgeUnverified` audit entry.
  - `lib/auth.ts`: `assertAdmin()` now requires `firebase.sign_in_second_factor == 'totp'` (new code `mfa-required`). It is skipped only when `FUNCTIONS_EMULATOR=true` and the project starts with `demo-` (`isDemoEmulator()`).
  - New error codes `registration-incomplete` and `mfa-required` in `lib/errors.ts`, `AppErrorCode` (Dart) and `core_en.arb`.
  - `scripts/set-admin.mjs`: bootstraps a platform admin (claims `{role: 'platformAdmin'}`, `users/{uid}`, audit `admin.grant`, revokes tokens). `--revoke` removes the role. On the emulators it creates the user with a verified email.
- **Rules (`firestore.rules`):** helpers `verified()`, `isAdmin()` (verified + `platformAdmin` + TOTP second factor) and `isOwner(rid)` (architecture §5). `users/{uid}`: `get` by that verified user or an admin, `list` by admins. `restaurants/{rid}`: `get` by the verified owner of an active restaurant or an admin, `list` by admins. No client writes. Everything else stays denied.
- **Core (`packages/core`)**
  - `auth/`: `AuthSession` (from ID-token claims: `uid`, `email`, `emailVerified`, `role`, `restaurantId`, `secondFactor`), `AuthRepository` and `FirebaseAuthRepository` (`signIn` forces a fresh token, `refreshSession`, `createAccount`, `sendEmailVerification`, `sendPasswordReset`, `signOut`), plus the providers `firebaseAuthProvider`, `authRepositoryProvider` and `authSessionProvider`. Also `AuthErrorCode` (Firebase code → message, `messageForError()` for auth and callable errors), `AuthFailure`, `AuthLayout` (brand panel ≥ 1024 px, card 600–1023, single column < 600; form ≤ 480 px), `authRefreshListenable()` and `safeFromParam()`.
  - `validation/validators.dart`: email, password (≥ 8), text, mobile per country (`phone_numbers_parser`, returns E.164). `geo/`: `Country`/`Countries`, `BusinessType`.
  - Widgets `AppPasswordField` and `FormMessage`; `AppTextField.prefixText`. `package:core/testing.dart` exports `FakeAuthRepository`.
- **Owner app:** routes `/sign-in`, `/sign-up`, `/verify-email?email&reason`, `/forgot-password?email`, `/finishing-setup` and `/splash` (account screens use `NoTransitionPage`). `features/auth/`: `RegistrationRepository` (callable), `OwnerAuthService` (register, sign-in with the FR-091 check, resend, resume, reset, sign-out; credentials for "Resend" kept in memory only), and the pages. The guard (`ownerRedirect`): loading → splash; signed out → `/sign-in?from=`; unverified → `/verify-email`; verified without claims → `/finishing-setup` (or `/sign-up` in "complete" mode if the restaurant was never created); owner on an account page → `from` or `/`. Admin accounts are refused. Sign-out button in the shell app bar.
- **Admin app:** routes `/sign-in` (email + password, then the 6-digit code), `/mfa-setup` (QR code via `qr_flutter`, key to copy, first code) and `/splash`. `AdminMfaRepository` (Firebase TOTP: `TotpMultiFactorGenerator`, `MultiFactorResolver`), `AdminAuthService`, and the guard (`adminRedirect`): non-admin or unverified → sign-in; admin without a TOTP sign-in → `/mfa-setup`; after enrolment the admin is signed out and signs in again with the code. `adminMfaRequiredProvider` is false only with `USE_EMULATORS=true`.
- **Tooling:** `tool/check.sh emulators` (functions emulator tests), `tool/integration.sh` (Flutter end-to-end in Chrome), CI jobs updated (the rules job also runs the functions emulator tests; new `integration` job). README: trying the flows and creating the first admin.

**Firestore fields created** — see the master plan's Cross-module notes.

**Decisions that differ from the plan**

1. **The verification email is sent by the client**, right after `completeRegistration` returns (`User.sendEmailVerification()`), not by the function. The Admin SDK can only generate a link; sending it would need a paid mail service. The callable does everything else.
2. **Optional "City" field at sign-up.** FR-002 does not list it, but FR-092 needs the city for the slug suffix. Stored as `contact.city` for M03. Without it the suffix is a number.
3. **Admin MFA is enforced on the server now**, not left to M11: in the rules (`isAdmin()`) and in `assertAdmin()`. Only the Functions emulator under `demo-` relaxes `assertAdmin()`, because the Auth emulator has no TOTP. The rules never relax it.
4. **`completeRegistration` is idempotent** and also used to re-apply lost claims (`{}` input). The plan's "duplicate" case therefore returns the existing restaurant instead of an error. Duplicate emails are refused by Firebase Auth at `createUserWithEmailAndPassword`.
5. **Cleanup deletes the QR code document** (as the plan says), even though FR-047 says codes are never reused. These accounts never reached the dashboard, so the code was never downloaded. A random 8-character code from 31 symbols colliding with it later is negligible.
6. **Provider name** `authSessionProvider` (in `core`) instead of `authStateProvider`: it holds the token claims, not the Firebase `User`.
7. Account screens switch without page transitions. The guard can move a user out of the shell and straight back (claims refresh), and an animated exit kept two shells alive (duplicate `GlobalKey`).

## Open items

- **Identity Platform and TOTP on a real project (needs your approval).** The Firebase projects do not exist yet (M00 quota). TOTP MFA needs the project upgraded to Firebase Authentication with Identity Platform (a paid product with a free tier; check the current pricing and billing requirement before enabling) and TOTP turned on, for example with the Admin SDK: `projectConfigManager().updateProjectConfig({multiFactorConfig: {providerConfigs: [{state: 'ENABLED', totpProviderConfig: {adjacentIntervals: 5}}]}})`. Until then the admin TOTP flow is only tested against a fake. Check by hand: enrol with Google Authenticator, sign in with a code, confirm a wrong code is refused and that `assertAdmin` and the rules see `sign_in_second_factor: 'totp'`.
- **Project auth settings to turn on when the projects exist:** email enumeration protection, password policy (minimum 8 characters), authorized domains for the app and admin sites, and the email templates (sender name, EazySuvai wording). Not possible without a project.
- **FR-091 "link expires after 24 hours":** Firebase sets the expiry of email-verification links and it cannot be changed to 24 hours in Firebase Auth. Meeting it exactly needs custom emails (`generateEmailVerificationLink` plus a mail provider). Decide whether to accept Firebase's expiry. Password reset links already match FR-006 (1 hour, single use).
- **FRD §7.2 hardening (M13):** App Check is not enabled on the callable (needs reCAPTCHA Enterprise / Play Integrity setup on a real project). Firebase ID tokens last 1 hour (FRD asks ≤ 15 min), and sign-out does not revoke refresh tokens on the server. Breached-password checks and the "5 attempts in 15 minutes" lockout rely on Firebase's built-in protection. Review in M13.
- **Scheduled function on the emulator:** `cleanupUnverifiedUsers` is not started by the emulator (no Pub/Sub emulator in the run). Its logic is tested by calling it directly. Deploying it needs Cloud Scheduler (Blaze plan).
- **CI integration job not yet run** (no GitHub remote, as in M00). It relies on the runner's Chrome and chromedriver.
- **iOS and Android sign-in not run** (only web). The code has no web-only parts except the path URL strategy.

## Change log

- 2026-11-14: Plan created.
- 2026-11-14: Module built. Status Done, with open items: Identity Platform TOTP and auth settings on a real project (needs approval and the projects), FR-091 24-hour link expiry, §7.2 hardening for M13. Admin MFA is now enforced in the rules and `assertAdmin`.
