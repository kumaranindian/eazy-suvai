# M01 – Authentication and accounts

Status: Not started
Started:
Completed:

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

- [ ] Sign-up form with validation (FR-002, FR-003), country picker, business type list.
- [ ] `completeRegistration` callable with slug and QR code generation; reserved slug list from `config/platform`.
- [ ] Verification email sending and resend (rate-limited to once a minute in the UI).
- [ ] Login, logout, password reset (link valid 60 min, Firebase default 1 h).
- [ ] Riverpod `authStateProvider` that refreshes the ID token after verification so claims are present.
- [ ] go_router guards: unauthenticated → login; unverified → verify page; owner without claims → "finishing setup" retry.
- [ ] `cleanupUnverifiedUsers` scheduled function.
- [ ] Admin app login page with TOTP MFA enrolment and challenge (Identity Platform).
- [ ] Rules: `users/{uid}` readable only by that user and admins; `restaurants/{rid}` read needs a verified email.
- [ ] Error messages mapped from Firebase error codes to `.arb` strings.

## Acceptance checks

- [ ] AC-001: register, verify, log in, log out, reset password.
- [ ] An unverified owner cannot log in and cannot read any Firestore data even with a token.
- [ ] Registering a second time with the same email shows a clear error (FR-004).
- [ ] The new restaurant has a unique slug, a QR code and the Free plan.
- [ ] Screens work at 360, 768 and 1280 px.

## Tests

Functions: `completeRegistration` (happy path, duplicate, reserved slug collision, slug suffixing). Rules: unverified and cross-tenant reads denied. Widget: sign-up validation. Integration: full sign-up → verify (emulator link) → login.

## Completion notes

_Fill in when done._

## Open items

## Change log

- 2026-11-14: Plan created.
