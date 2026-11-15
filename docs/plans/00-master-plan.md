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
| M05 | Menu customization (themes) | `M05-customization.md` | M03 | Done | 2026-11-14 | 2026-11-14 | Shared WCAG contrast + `resolveTheme` (Dart and TS, one test-case file), 6 seed themes (2 Free) and fonts, rules for `themes`/`config/platform`/theme draft, gallery and editor with live phone/desktop preview and autosave; Chrome end to end. Open: premium lock (M10), device runs, seed real projects. |
| M06 | Preview, publishing and versions | `M06-publishing.md` | M04, M05 | Done | 2026-11-15 | 2026-11-15 | Pure snapshot builder + diff + validation (stable problem codes), `publishMenu` (dry run; one transaction: version, pointer, availability reset, prune to 10, audit), `rollbackMenu`, `discardDraft`, `previewMenu` with the first public renderer; publish bar, dialog, preview (iframe / web view) and version history; Chrome end to end. Open: device runs of the web view, M07 owns SEO and account states. |
| M07 | Public digital menu | `M07-public-menu.md` | M06 | Done | 2026-11-15 | 2026-11-15 | `renderMenu` behind Hosting `menu`: slug / old-slug 301 / `/q/` 302 / sitemap, FR-099 states, SEO + JSON-LD, lightbox and category script (3.4 KB), ETag, CSP, gzip; Lighthouse LCP 1.4–1.6 s, 47 KB, a11y 100; layouts checked at 360/768/1280. Open: real phones (AC-009), deploy and CDN check. |
| M08 | QR codes and sharing | `M08-qr-sharing.md` | M07 | Done | 2026-11-15 | 2026-11-15 | QR & share screen (3 widths): ≥ 1024 px PNG of `/q/{code}`, logo (level H) only after a zxing2 decode check, else plain with the reason; A4 poster and A6 card PDFs with preview; web download / mobile share sheet; copy, WhatsApp, Web Share. Open: scans on real phones (AC-010), WhatsApp preview on the deployed site (AC-014). |
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

- 2026-11-14 (M05): **Theme data:**
  - `themes/{id}` = `{name, premium, sort, retired, tokens {primary, secondary, background, surface, text, font, layout, cardLayout, mode}, updatedAt}`.
  - Seeded ids: `saffron` and `minimal` (Free); `banana-leaf`, `midnight`, `cafe-cream` and `coastal` (premium).
  - `config/platform.fonts` is the curated Google Fonts list. `seed-platform.mjs` seeds both; run it on every project.
  - `restaurants/{rid}.themeId` is an existing theme id or `null`. `themeSettings` holds only the overrides (`primary`, `secondary`, `background` as upper-case `#RRGGBB`; `font`; `layout: list|grid`; `cardLayout: compact|image-top|image-left`; `mode: light|dark`). Choosing a theme resets it to `{}`.
  - `themes` and `config/platform` are readable by verified owners, so `config/platform` must never hold secrets.
- 2026-11-14 (M05): **Theme tokens M07 must use.** Render with `resolveTheme(tokens, settings)` and `cssVariables()` from `functions/src/theme`; never re-implement the contrast rules.
  - CSS custom properties: `--es-primary`, `--es-on-primary`, `--es-secondary`, `--es-on-secondary`, `--es-background`, `--es-surface`, `--es-text`, `--es-surface-text`, `--es-muted-text`, `--es-accent`, `--es-border`.
  - Use `text` on the background, `surfaceText` on cards, `mutedText` for descriptions, and `accent` for headings and prices. All of them reach WCAG AA after the automatic adjustment (FR-060).
  - `font` is a Google Fonts family (fall back to the system sans-serif). `layout`, `cardLayout` and `mode` as above.
  - The Dart twin is `resolveMenuTheme()` → `ResolvedMenuTheme` in core. Both are tested against `functions/src/theme/contrast-cases.json`; change them together.
- 2026-11-14 (M05): **Snapshot (M06):** `theme: {themeId, tokens (copied from the theme at publish), settings}`. **Plan gating (M10):** owners write `themeId` directly and the rules only check that it exists; add the premium check there or move the choice to a callable.
- 2026-11-14 (M05): **Owner app:**
  - Routes `/settings/theme` (gallery) and `/settings/theme/customize` (editor). The dashboard step "Choose a theme" opens the gallery.
  - `MenuThemePreview` (owner app) renders the menu from resolved tokens; reuse it in the M06 preview screen if useful.
  - Widget tests: `pumpOwnerApp(..., themes: FakeThemeRepository(...))` (`test/fake_theme.dart`); `menuFontResolverProvider` is overridden with `PlainMenuFontResolver` (no Google Fonts fetches in tests).
  - `tool/integration.sh` also runs `theme_flow_test.dart`.

- 2026-11-15 (M06): **Published version document** `restaurants/{rid}/versions/{n}` (immutable; the last 10 are kept). M07 renders `snapshot`. The exact shape (`?` = left out when empty or hidden):

  ```jsonc
  {
    "n": 3,
    "kind": "publish",                 // or "rollback"
    "rollbackOf": null,                // the version re-published by a rollback
    "publishedAt": "<Timestamp>",
    "publishedBy": "<uid>",
    "summary": { "added": 1, "changed": 2, "removed": 0, "profileChanged": false, "themeChanged": true },
    "snapshot": {
      "schema": 1,
      "profile": {
        "name": "Spice Garden",
        "businessType": "restaurant",
        "description?": "South Indian classics",
        "logo?": "<Image>",
        "cover?": "<Image>",
        "contact": {                    // only groups with visibility != false
          "phone?": "+914423456789",    // "phone"
          "email?": "hi@spice.in",      // "email"
          "address?": "12 Anna Salai", "city?": "Chennai", "postalCode?": "600002",   // "address"
          "website?": "https://…",      // "social"
          "social?": { "instagram?": "https://…", "facebook?": "…", "x?": "…", "youtube?": "…", "googleMaps?": "…" }   // "social"
        },
        "openingHours?": { "mon": "07:00-11:00,18:00-23:30", "tue": "", "…": "", "sun": "00:00-00:00" }   // "hours"; all 7 days
      },
      "theme": {
        "themeId": "saffron",          // or null (DEFAULT_TOKENS)
        "tokens": { "primary": "#…", "secondary": "#…", "background": "#…", "surface": "#…", "text": "#…", "font": "Poppins", "layout": "list", "cardLayout": "image-left", "mode": "light" },
        "settings": { "primary?": "#…", "secondary?": "#…", "background?": "#…", "font?": "…", "layout?": "grid", "cardLayout?": "compact", "mode?": "dark" },
        "resolved": { "primary": "#…", "onPrimary": "#…", "secondary": "#…", "onSecondary": "#…", "background": "#…", "surface": "#…", "text": "#…", "surfaceText": "#…", "mutedText": "#…", "accent": "#…", "border": "#…", "font": "Poppins", "layout": "list", "cardLayout": "image-left", "mode": "light" }
      },
      "categories": [                  // active, not deleted, display order
        { "id": "c1", "name": "Tiffin", "description?": "…", "image?": "<Image>", "sequence": 1000 }
      ],
      "items": [                       // not deleted, not hiddenOverLimit, in a public category; category order, then sequence, then id
        {
          "id": "i1", "categoryId": "c1", "name": "Idli", "description?": "…", "image?": "<Image>",
          "priceMinor": 6000,           // integer minor units of `currency`
          "dietaryLabel": { "id": "vegetarian", "name": "Vegetarian", "icon": "veg", "color": "#0F7B0F" },   // or null
          "tags": [ { "id": "spicy", "name": "Spicy", "icon": "spicy", "color": "#C62828" } ],             // unknown ids dropped
          "available": true,            // at publish time; live/availability.items[id] wins (FR-095)
          "featured": false,
          "sequence": 1000
        }
      ],
      "currency": "INR",
      "locale": "en-IN",               // en-{country}
      "timezone": "Asia/Kolkata"
    }
  }
  // <Image> = { "width": 1200, "height": 800, "w320": "<url>", "w640": "<url>", "w1280": "<url>" }
  //           token download URLs; only `ready` images whose three renditions resolved
  ```

  - Read order: `restaurants/{rid}.publishedVersion`, then `versions/{n}`, then `live/availability`. Publishing writes the version and moves the pointer in one transaction (AC-022).
  - Render with `renderMenuPage(snapshot, {availability, branding, headExtra, bodyExtra})` in `functions/src/public/render-menu.ts` (built for the M06 draft preview); `formatPrice()` / `formatDayHours()` are in `public/format.ts`. Changing the shape means bumping `SNAPSHOT_SCHEMA` and updating the builder (`functions/src/publishing/snapshot.ts`), the renderer and this note together.
  - `versions/{n}/private/source` holds the full draft for discard and rollback. It is Functions-only: never render it (FR-045).
- 2026-11-15 (M06): **New root fields on `restaurants/{rid}`** (Functions only):
  - `publishedAt`;
  - `publishedDraftAt`: the draft time the live version matches; `null` after a rollback that kept the draft;
  - `publishedCurrency`;
  - `versionHistory`: `[{n, kind, rollbackOf, publishedAt, publishedBy, summary}]`, newest first, at most 10.

  Core reads them as `Restaurant.publishedAt`, `publishedDraftAt`, `versionHistory` (`MenuVersionEntry`) and `hasUnpublishedChanges`.
- 2026-11-15 (M06): **Changes to earlier modules' functions:**
  - The M04 menu triggers stamp `draftUpdatedAt` with the edited document's own `updatedAt` (not the server time).
  - M03's `onRestaurantUpdated` skips `pricesNeedReview` when the currency returns to `publishedCurrency`.
  - Owner writes still must set `updatedAt` / `draftUpdatedAt` to `request.time` (rules unchanged).
- 2026-11-15 (M06): **Callables:**
  - `publishMenu({restaurantId, dryRun?, pricesReviewed?})`: the dry run returns `{ok, problems, summary, currentVersion, pricesNeedReview}`; a real run returns `{version, summary}` or fails with the new error code **`publish-blocked`** (`details.problems`).
  - `rollbackMenu({restaurantId, version, replaceDraft = true})` → `{version, summary}`.
  - `discardDraft({restaurantId})` → `{version}`.
  - `previewMenu({restaurantId})` → `{html, problems}`.

  Problem codes are `email-not-verified`, `menu-empty`, `missing-field`, `invalid-field`, `limit-exceeded`, `prices-need-review` and `snapshot-too-large` (`ProblemCode` in `snapshot.ts`, `PublishProblemCode` in the owner app; keep both in sync). Audit actions: `menu.publish`, `menu.rollback`, `menu.discardDraft`.
- 2026-11-15 (M06): **Rules:** owners of an active restaurant and TOTP admins can read `restaurants/{rid}/versions/{n}`. `versions/{n}/private/**` and `live/**` stay closed.
- 2026-11-15 (M06): **Owner app:**
  - `ResponsiveScaffold(banner:)` (core) holds the publish bar.
  - Routes `/preview` (root navigator, full screen) and `/settings/versions`.
  - `showPublishDialog(context)` can be opened from anywhere.
  - `PublishingRepository` / `publishingRepositoryProvider` and `menuHtmlViewBuilderProvider`. Widget tests get `FakePublishingRepository` and `fakeMenuHtmlView` by default through `pumpOwnerApp(..., publishing:)`.
  - New dependencies: `webview_flutter` and `web`.
- 2026-11-15 (M06): **Tooling:**
  - `npm run test:emulators` also runs `scripts/check-storage-urls.mjs`. It checks the download URLs on the Storage emulator, because Jest can't load the Storage client's dynamic import.
  - `tool/integration.sh` also runs `publish_flow_test.dart`.
  - This machine's Java is 17: run the emulators with Android Studio's JBR 21 (`JAVA_HOME="C:/Program Files/Android/Android Studio/jbr"`).

- 2026-11-15 (M07): **Public menu routes** (`functions/src/public/`, function `renderMenu`):
  - `/{slug}`; an old slug, upper case or a trailing slash answers 301.
  - `/q/{code}` answers 302 `/{slug}?src=qr` (any case; unknown 404; restaurant gone 410).
  - `/sitemap.xml`.
  - `robots.txt` is a **static** Hosting file written by `functions/scripts/write-robots.mjs` (Hosting predeploy). The Functions Framework answers `/robots.txt` and `/favicon.ico` before any function runs, so never route those to a function.
  - The canonical origin comes from `MENU_ORIGINS` (by project id) in `serve.ts`, mirrored in `write-robots.mjs` (a test compares them); `MENU_BASE_URL` overrides it. Keep it in step with `AppEnv.menuBaseUrl` (owner app) when the final domain is chosen.
- 2026-11-15 (M07): **For M08:** the QR target `{menuBaseUrl}/q/{qrCode}` works now and follows slug changes. Link previews come from `/{slug}`:
  - `og:title` "{Name} – Menu | EazySuvai";
  - `og:description`: the description, or "See the menu of {name} in {city}…";
  - `og:image`: the cover at 1280 px, else the logo at 640 px.

  Share the slug URL (canonical) in text and encode the `/q/` URL in the QR code.
- 2026-11-15 (M07): **Where M09's beacon hooks in:**
  - Set `beacon: "/e"` in the `renderMenuPage` options in `serve.ts` (`case "live"`). It writes `<body data-beacon="/e" data-slug="{slug}">`; without it the hook sends nothing.
  - The inline script (`client-script.ts`) already calls `track(type, data)`, also exposed as `window.esTrack`, which sends JSON with `navigator.sendBeacon` to the beacon URL. Events: `view` on load, `cat` on a category tap (`{id}` without the `c-` prefix), `item` on a photo or "more" (`{id}`). Payload: `{type, slug, src: "qr"|"direct", ...data}`.
  - `src` is read from `?src=qr` before the script removes it from the address bar.
  - M09 adds the session id and the 30-minute dedup inside `track`, and keeps the scripts under 10 KB (a test checks it).
  - `/e` needs its own Hosting rewrite to `collectEvent` **above** the `**` rewrite in `firebase.json`. `renderMenu` answers POST with 405. The CSP already allows `connect-src 'self'`.
- 2026-11-15 (M07): **Branding flag (M10):** `plans/{planId}.limits.removeBranding` (boolean) hides "Powered by EazySuvai". Without the field, Free shows it and Pro hides it (`removeBrandingFrom()` in `functions/src/lib/plan-limits.ts`). Seed it when M10 creates the plans. Setting it on `plans/free` turns the footer off for everyone (open decision below).
- 2026-11-15 (M07): **Renderer changes that show in the M06 preview:**
  - Unavailable items now read "Currently unavailable" (FR-043), with a grey photo and a dashed border.
  - Photos link to the 1280 px rendition.
  - The category bar becomes a sidebar from 1024 px.
  - Grid layouts have 1 / 2 / 3 columns.
  - Customer-facing strings are in `functions/src/public/text.ts`.
- 2026-11-15 (M07): **Tooling:**
  - `npm run test:emulators` also starts `hosting:menu` (port 5000).
  - New `npm run test:lighthouse`, `tool/check.sh lighthouse` and CI job `lighthouse`. They need Chrome; the report goes to `functions/lighthouse-report/`.

- 2026-11-15 (M08): **QR codes in the owner app** (`lib/features/qr/`, route `/share`):
  - The QR code always encodes `qrUrlFor(qrCode)` = `{AppEnv.menuBaseUrl}/q/{CODE}`. Shared links (copy, WhatsApp, share sheet) use `menuUrl(slug)`.
  - Reuse `renderQrPng`, `decodeQrImage` / `qrDecodesTo` and `buildQrArtifact` (`application/qr_image.dart`) for Phase 2 table codes (FR-094) rather than writing new ones.
- 2026-11-15 (M08): **For M10:** the logo in the QR code is open to every plan for now. Gate it with `limits.qrLogo`:
  - disable `QrKeys.logoSwitch` with an upgrade hint in `QrSharePage`;
  - keep `qrLogoChoiceProvider` false when the plan lacks it.

  Nothing server-side is needed: the QR code is generated on the device and only the URL matters.
- 2026-11-15 (M08): **Dependency change in core:** `image` is now `^4.5.0` (resolved 4.5.4, was ^4.13.0). `pdf` 3.11 needs `image` < 4.6, and newer `pdf` needs Dart 3.12 and a `vector_math` that Flutter 3.32 doesn't allow. Raise both together when the Flutter SDK moves.
- 2026-11-15 (M08): **Tests:**
  - `pumpOwnerApp(..., qrBuilder:)` renders QR codes in the test zone; the default builds directly, with no isolate.
  - The PDF viewer is replaced by a text stand-in.
  - Override `qrShareActionsProvider` / `qrLogoLoaderProvider` to fake sharing and the logo (`test/qr_share_test.dart` has `FakeQrShareActions` and `FakeLogoLoader`).
- 2026-11-15 (M08): **Assets:** `apps/owner_app/assets/fonts/` (Poppins Regular and SemiBold + `OFL.txt`) for the PDFs.

## Open decisions

- Slug-change rate limit: the FRD sets none; M03 suggests one (see M03 Open items).

- Final domains for app, admin and public menu (placeholders in `docs/architecture.md`).
- Pro plan prices per currency.
- Whether to enable Identity Platform now for admin MFA (required by FR-084). The M01 code is ready; it needs the real projects and your approval (paid product with a free tier).
- FR-091 asks for 24-hour verification links; Firebase sets its own expiry. Accept it, or send custom verification emails (needs a mail provider).
- Whether Free-plan menus show a "Powered by EazySuvai" footer (not yet in the FRD; M07 builds it behind a plan flag).
