# EazySuvai MVP – Master plan

The MVP is built in 14 modules, M00 to M13, in the order below. Each module has its own plan file in this folder and an implementation prompt in `docs/prompts/module-prompts.md`.

**Update rule:** when a module changes status, update its row here and its own plan file in the same commit (see `AGENTS.md`, "Updating the plan when a module is done").

Status values: `Not started` · `In progress` · `Blocked` · `Done`

## Module tracker

| # | Module | Plan file | Depends on | Status | Started | Completed | Note |
| --- | --- | --- | --- | --- | --- | --- | --- |
| M00 | Foundation and project setup | `M00-foundation.md` | – | Done | 2026-11-14 | 2026-11-14 | Workspace, core, shells, rules, functions lib, CI. Open: prod project; dev Android/iOS options, Hosting sites and TTL. (Dev `eazy-suvai-dev` web connected; CI green on GitHub.) |
| M01 | Authentication and accounts | `M01-authentication.md` | M00 | Done | 2026-11-14 | 2026-11-14 | Sign-up, verify, login, reset, claims, guards, cleanup, admin TOTP. Open: Identity Platform TOTP on a real project (approval), auth project settings, FR-091 24 h link expiry. |
| M02 | Media management | `M02-media.md` | M00 | Done | 2026-11-14 | 2026-11-14 | Storage rules, `processImage` (sharp: magic bytes, minimum sizes, EXIF strip, WebP 320/640/1280), `ImagePickerField`, `ResponsiveImage`, upload with progress and cancel; web verified end to end. Open: Android/iOS device run, real-bucket setup (CORS, cross-service rules, Blaze). |
| M03 | Restaurant onboarding and profile | `M03-restaurant-profile.md` | M01, M02 | Done | 2026-11-14 | 2026-11-14 | Setup wizard, dashboard checklist, profile with autosave and live preview, opening hours, currency/time zone (FR-103), `changeSlug`, `onRestaurantUpdated`, rules whitelist with value checks; Chrome end to end. Open: device runs, slug-change rate limit (decision). |
| M04 | Menu management (categories and items) | `M04-menu-management.md` | M03 | Done | 2026-11-14 | 2026-11-14 | Callables (create, delete, move, restore; plan limits in a transaction), triggers (counts, `draftUpdatedAt`, `live/availability`), rules whitelist, price field in minor units, labels/tags seed, menu manager at 1/2/3 panes, Recently deleted; Chrome end to end. Open: device runs, seed labels on real projects. |
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
- 2026-11-14 (M02): **Image object** (architecture §4.4), written **only** by `processImage`:
  - `processing`: `{path, status, uploadedAt}`
  - `ready`: `{path, status, contentType, width, height, renditions: {w320, w640, w1280}, uploadedAt}`
  - `rejected`: `{path, status, reason, uploadedAt}`

  `path` and `renditions.*` are Storage paths (`restaurants/{rid}/images/{id}/original.{jpg|png|webp}`, `…/w320.webp`), not URLs. `reason` is `unsupported-type | too-large | too-small | invalid-image | processing-failed`. Fields: `restaurants/{rid}.logo`, `.cover`, `…/categories/{cid}.image`, `…/items/{iid}.image`. **Clients may only set these fields to `null`** (M03/M04 rules whitelists). The target document must exist before the upload. A `ready` write bumps root `draftUpdatedAt` (and item `updatedAt`). Dart: `ImageObject.fromMap(doc['logo'])`.
- 2026-11-14 (M02): **Widgets** (`core`):
  - `ImagePickerField({required purpose, required restaurantId, required targetPath, required label, value, aspectRatio, onUploaded, onRemove, dense = false, enabled = true})`. `ImagePurpose.logo | cover | category | item` sets the minimum size, default aspect (cover 3:1, others 1:1) and field. The parent passes the live field as `value` and does not save uploads itself. Without `onRemove` there is no Remove button.
  - `ResponsiveImage({required image, fit = BoxFit.cover, semanticLabel, placeholderIcon})` picks the smallest rendition ≥ the physical width and shows placeholders for none, processing and rejected. Give it a bounded size.
  - Messages: `CoreLocalizations.imageRejectMessage(reason, purpose)`. Fakes for tests are in `package:core/testing.dart` (`FakeImageFilePicker`, `FakeImageUploader`, `FakeStorageImageResolver`). Override `imageFilePickerProvider`, `imageUploaderProvider` and `storageImageResolverProvider`.
- 2026-11-14 (M02): **Upload contract:** path `restaurants/{rid}/images/{20-char id}/original.{ext}` and custom metadata `{purpose, targetPath, field}`. `storage.rules` and `functions/src/media/policy.ts` both enforce the allow-list; keep them in sync with `ImagePurpose`. Uploads are create-only, and clients can't delete. Old image files are kept (published versions may reference them); M12 purges.
- 2026-11-14 (M02): **Public images (M07):** renditions carry `firebaseStorageDownloadTokens` and `Cache-Control: public, max-age=31536000, immutable`. Storage rules do not allow anonymous reads. Web apps need `storage.cors.json` applied to the bucket.
- 2026-11-14 (M02): **Tooling:** `npm run test:emulators` and `tool/integration.sh` also start the Storage emulator. Rules tests run one file at a time (`--test-concurrency=1`). `pumpOwnerApp(..., overrides: [...])` in the owner app's test helpers. Owner dev page `/dev/media` (non-prod only).
- 2026-11-14 (M03): **Owner writes to `restaurants/{rid}`** go through `validOwnerUpdate()` in `firestore.rules`:
  - the whitelist from architecture §5, plus `setupCompletedAt`;
  - every draft change sets `draftUpdatedAt` to the server time;
  - values are checked.

  The rules are close to their per-request evaluation limit. Add checks inline and sparingly (M05 theme), and keep the "heaviest update" test in `restaurant-profile.test.js` passing.
- 2026-11-14 (M03): **Profile formats** (architecture §4.2):
  - `openingHours` is one string per weekday (`"07:00-11:00,18:00-23:30"`; `""` = closed; absent or `null` = not set), **not** slot maps.
  - `contact` leaves out empty values. `phone` is E.164; `website` and `social.{instagram,facebook,x,youtube,googleMaps}` are https URLs.
  - `visibility.{phone,email,address,hours,social}`: `false` hides the group; a missing flag means shown.
  - New field `setupCompletedAt`.
  - Dart model: `Restaurant.fromMap` and related classes in `core` (`src/restaurant/`).
- 2026-11-14 (M03): **Slugs:**
  - `changeSlug({restaurantId, slug, dryRun?})`, with errors `slug-invalid`, `slug-reserved` and `slug-taken`.
  - Old slugs are kept as `{current: false, replacedAt}`. M07 answers them with a 301 to the current `restaurants/{rid}.slug`.
  - Audit action `restaurant.changeSlug`.
  - `onRestaurantUpdated` sets `pricesNeedReview` when the currency changes after a publish (M06 clears it) and keeps `nameLower` in sync (M11 search).
- 2026-11-14 (M03): **Owner app:**
  - Routes: `/setup`, `/settings/{profile,hours,regional,menu-link}`. `/` is the dashboard. `/dev/media` is removed.
  - Reuse `currentRestaurantProvider`, `RestaurantRepository`, `DraftAutosave` with `SaveStatusIndicator` / `SaveBar`, `FormSection`, and `menuUrl(slug)` (built on `AppEnv.menuBaseUrl`).
  - Detail routes inside the shell bring their own `AppBar` (`OwnerShell(showAppBar:)`).
  - Widget tests: `pumpOwnerApp(..., restaurant: FakeRestaurantRepository(restaurantData({...})))`. The default restaurant has finished setup.
- 2026-11-14 (M03): **Tooling:** `tool/integration.sh` also runs `profile_flow_test.dart`. The M01 end-to-end test skips the wizard after the first sign-in.

- 2026-11-14 (M04): **Menu documents** (architecture §4.2):
  - `categories/{cid}`: `{name, description, image, sequence, active, deletedAt, createdAt, updatedAt}`.
  - `items/{iid}`: `{categoryId, name, description, image, priceMinor, dietaryLabelId, tagIds, available, featured, sequence, hiddenOverLimit, deletedAt, deletedWith, createdAt, updatedAt}`.
  - `deletedAt` is `null` when live (query `deletedAt == null`). `deletedWith` is the category an item was deleted together with.
  - Order is `sequence` ascending, ties by id (`compareSequenced` in core); gaps of 1000.
  - Only non-deleted, active categories and non-deleted, non-`hiddenOverLimit` items go public (M06 snapshot).
- 2026-11-14 (M04): **Callables:**
  - `createCategory`, `createItem`, `deleteCategory({mode: 'move'|'deleteAll', targetCategoryId?, confirmName?})`, **`deleteItems`** (new, not in the original plan), `moveItems`, `restoreDeleted({kind, id, targetCategoryId?})`.
  - Each counts live documents inside its transaction and writes the root's `counts` and `draftUpdatedAt`; the triggers only recount.
  - Errors: `limit-reached` with details `{limit: 'items'|'categories', max, planId}`, and the new code `category-deleted`.
- 2026-11-14 (M04): **Plan limits:** `getPlanLimits(read, planId)` in `functions/src/lib/plan-limits.ts` reads `plans/{planId}.limits.{maxItems, maxCategories}` (`null` or negative = unlimited) and falls back to the FRD values (Free 50/10, Pro 500/unlimited). M10 seeds the plans and extends this helper rather than writing a second one.
- 2026-11-14 (M04): **`live/availability`** = `{items: {iid: bool}, updatedAt}`, written by `onItemWrite` on every availability change (and on create); the key is removed when an item document is deleted. M07 lays it over the published snapshot. M06 may reset it on publish but doesn't have to (it always holds the current value). An availability-only change does **not** bump `draftUpdatedAt` (BR-018).
- 2026-11-14 (M04): **Platform labels:** `dietaryLabels/{id}` and `itemTags/{id}` = `{name, icon, color, sort, retired}`, seeded by `functions/scripts/seed-platform.mjs` (ids `vegetarian`, `non-vegetarian`, `vegan`, `contains-egg`; `spicy`, `bestseller`, `chefs-special`, `new`). `icon` is a key drawn by `MenuLabelIcon` in core (`veg`, `nonVeg`, `vegan`, `egg`, `spicy`, `bestseller`, `chefsSpecial`, `new`). M11's `upsertLabel`/`upsertTag` keep this shape; retiring sets `retired: true` (never delete, FR-104). The rules check that an item's `dietaryLabelId` exists, not its tags; M06 drops unknown tag ids.
- 2026-11-14 (M04): **Owner app:**
  - Routes `/menu`, `/menu/category/:cid`, `/menu/item/new?category=`, `/menu/item/:iid` (root navigator), `/menu/deleted`, and `/settings/plan` (`PlanPage` placeholder, which M10 replaces; the plan-limit prompt's "Upgrade" goes there).
  - Core adds `MenuCategory`, `MenuItem`, `MenuLabel`, `MenuLimits`, `sequencesAfterMove`, `PriceField` / `parsePriceMinor` and `MenuLabelBadge` (reuse in the M06 preview and the M11 label admin).
  - Widget tests: `pumpOwnerApp(..., menu: FakeMenuRepository(...))` (`test/fake_menu.dart`, `sampleMenu()`).
- 2026-11-14 (M04): **Tooling:** `tool/integration.sh` also runs `menu_flow_test.dart`. Seed labels on the emulators with `FIRESTORE_EMULATOR_HOST=localhost:8080 node functions/scripts/seed-platform.mjs --project demo-eazysuvai` (after `npm run build`).

## Open decisions

- Slug-change rate limit: the FRD sets none; M03 suggests one (see M03 Open items).

- Final domains for app, admin and public menu (placeholders in `docs/architecture.md`).
- Pro plan prices per currency.
- Whether to enable Identity Platform now for admin MFA (required by FR-084). The M01 code is ready; it needs the real projects and your approval (paid product with a free tier).
- FR-091 asks for 24-hour verification links; Firebase sets its own expiry. Accept it, or send custom verification emails (needs a mail provider).
- Whether Free-plan menus show a "Powered by EazySuvai" footer (not yet in the FRD; M07 builds it behind a plan flag).
