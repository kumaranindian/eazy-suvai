# EazySuvai – Architecture (MVP)

This document turns `docs/FRD-v1.1.md` into a buildable design on Flutter and Firebase. Module plans in `docs/plans/` refer to the section numbers here. If a module changes anything in this file, it updates this file in the same piece of work.

## 1. System overview

| Part | Built with | Who uses it | Host |
| --- | --- | --- | --- |
| Owner app | Flutter (web, Android, iOS) | Restaurant owners | `app.eazysuvai.com` + app stores |
| Admin app | Flutter (web) | AVAIL404 platform administrators | `admin.eazysuvai.com` |
| Public menu | Server-rendered HTML from a Cloud Function | Customers who scan the QR code | `menu.eazysuvai.com` |
| Backend | Firebase Auth, Firestore, Storage, Cloud Functions | All of the above | `asia-south1` |

Domain names are placeholders until confirmed (FRD Appendix A, item 1).

```
 Customer phone ──scan QR──> menu.eazysuvai.com/q/{code}
                               │ 302
                               ▼
                    menu.eazysuvai.com/{slug} ──Hosting CDN (60 s)──> Function: renderMenu
                                                                        │ reads
 Owner app (Flutter) ──Auth + Firestore + Storage + callable Functions──┤
 Admin app (Flutter) ──Auth (MFA) + callable Functions──────────────────┘
                                   Firestore · Storage · Scheduled Functions
```

## 2. Why the public menu is not Flutter

The FRD requires the customer menu to load in 2.5 s or less on 4G, with an initial payload of 150 KB or less, and to be indexed by search engines with Open Graph previews (FRD §7.1, §7.6). Flutter Web downloads well over 1 MB before showing anything and renders to a canvas that search engines read poorly. So the public menu is plain HTML and CSS with a few kilobytes of JavaScript, rendered by a Cloud Function and cached by the Firebase Hosting CDN. The owner and admin apps are Flutter.

## 3. Public menu rendering

- Firebase Hosting site `menu` rewrites every path to the HTTPS function `renderMenu`, except the static files in `hosting/menu/` (`favicon.ico`, `apple-touch-icon.png`, and `robots.txt`, which the Hosting predeploy step writes for the project; the Functions Framework answers `/robots.txt` itself, so the function can never serve it).
- Routes:

| Path | Result |
| --- | --- |
| `/{slug}` | The menu page. An old slug answers 301 to the current slug (FR-093); upper case or a trailing slash answers 301 to the canonical form. |
| `/q/{code}` | 302 to `/{slug}?src=qr`, and the visit counts as a QR visit (FR-048). |
| `/sitemap.xml` | Active, published restaurants only |
| `/robots.txt` | Static file: allows the menu pages; disallows `/q/`; points to the sitemap |
| `/e` (POST) | Analytics beacon (M09; needs its own rewrite above `**`) |

- The function reads `slugs/{slug}`, then `restaurants/{rid}` (status), the current version `restaurants/{rid}/versions/{n}`, and the live availability overlay `restaurants/{rid}/live/availability`.
- Response header: `Cache-Control: public, max-age=0, s-maxage=60`. Changes therefore show within 60 s (FR-044). 200 responses carry an ETag (304 on `If-None-Match`) and are gzipped by the function. HTML pages carry a CSP that allows only the two inline scripts (by hash). The canonical origin comes from `MENU_ORIGINS` (by project id) in `functions/src/public/serve.ts`, with a `MENU_BASE_URL` environment override.
- Account states follow FR-099: 200 live menu, 404 "coming soon", 503 "temporarily unavailable", 410 "no longer available". Pages that are not live carry `noindex`.
- Templates live in `functions/src/public/` as TypeScript template functions (`renderMenuPage()` in `render-menu.ts`, built in M06 for the draft preview and extended by M07), with HTML escaping on every value. Theme colours are passed as CSS custom properties.
- Images are served from the Storage rendition token URLs (not a Hosting proxy) with `srcset` (320/640/1280) and `loading="lazy"`; the cover is loaded eagerly with `fetchpriority="high"` (LCP).
- The Google Fonts stylesheet does not block the first paint. The inline JavaScript (under 10 KB) only enhances the page: category highlight, lightbox, "more", and the analytics hook. Without it the page works fully.
- Performance budget: `npm run test:lighthouse` (FRD §7.1).

## 4. Firestore data model

All timestamps are Firestore `Timestamp` in UTC. IDs are Firestore auto-IDs unless stated.

### 4.1 Global collections

| Path | Purpose | Written by |
| --- | --- | --- |
| `users/{uid}` | Profile: `email`, `displayName`, `mobile`, `role` (`owner` or `platformAdmin`), `restaurantId`, `createdAt` | Functions |
| `restaurants/{rid}` | Tenant root (4.2) | Owner (allowed fields only), Functions |
| `slugs/{slug}` | `{restaurantId, current: bool, createdAt, replacedAt?, reclaimedAt?, releasedAt?}`; one doc per current or old slug. `changeSlug` (M03) sets the old one to `current: false` with `replacedAt` and keeps it for 301s | Functions |
| `qrCodes/{code}` | `{restaurantId, kind: 'restaurant'}`; permanent, never reused | Functions |
| `plans/{planId}` | `name`, `limits {maxItems, maxCategories, maxBranches, premiumThemes, defaultThemeId, analyticsDays, qrLogo, removeBranding}`, `prices {CUR: {monthly, annual}}` (minor units), `billing[]`, `isFree`, `active`, `sort` (M10). Readable by owners and admins | Admin via Functions |
| `dietaryLabels/{id}`, `itemTags/{id}` | `name`, `icon` (a key the apps draw: `veg`, `nonVeg`, `vegan`, `egg`, `spicy`, `bestseller`, `chefsSpecial`, `new`), `color` (`#RRGGBB`), `sort`, `retired` (FR-104). Seeded by `functions/scripts/seed-platform.mjs` (M04) | Admin via Functions |
| `themes/{id}` | `name`, `premium`, `sort`, `retired`, `updatedAt`, `tokens {primary, secondary, background, surface, text, font, layout, cardLayout, mode}`: colours `#RRGGBB`, `layout` list or grid, `cardLayout` compact, image-top or image-left, `mode` light or dark. Seeded by `seed-platform.mjs` (M05: 6 themes, 2 non-premium). Readable by verified owners and admins | Admin via Functions |
| `config/platform` | `reservedSlugs[]`, `graceDays` (default 14), `fonts[]` (Google Fonts families, M05), `currencies{code: decimals}`. Readable by verified owners and admins (M05, for the font list), so it must never hold secrets | Admin via Functions |
| `upgradeRequests/{id}` | `restaurantId`, `restaurantName`, `ownerEmail`, `currentPlanId`, `requestedPlanId`, `billing`, `status` (`pending`, `activated`, `closed`), `createdAt`, `resolvedAt` | Functions (`requestUpgrade`, M10) |
| `mail/{id}` | `{to, message {subject, text}, kind, restaurantId}` for the Trigger Email extension (M10) | Functions only |
| `auditLogs/{id}` | `actorUid`, `actorRole`, `action`, `restaurantId?`, `target`, `reason?`, `details`, `at`, `expireAt` (TTL 2 years) | Functions only |
| `paymentArchive/{rid}_{pid}` | Payments of purged restaurants: business name, amount, currency, method, reference, period, `retainUntil` (8 years) (M12) | Functions only |
| `analyticsEvents/{id}` | Raw beacon events, `expireAt` (TTL 90 days) | Functions only |
| `stats/platform` | Counters for the admin dashboard (FR-085): restaurants and subscriptions by status, items, views, QR visits; M13 (FRD §13): `activated`, `publishedMenus`, `qrDownloads`, `conversions`, `renewals`, `medianMinutesToFirstPublish`, `monthly.{yyyy-MM}.{views,qrVisits}` | Functions only |

### 4.2 Tenant subtree `restaurants/{rid}`

Root document fields: `name`, `nameLower` (for admin search), `ownerName`, `ownerEmail`, `ownerMobile` (E.164), `pricesNeedReview`, `businessType`, `description`, `logo`, `cover` (image objects, 4.4), `contact {phone, email, address, city, postalCode, website, social{instagram, facebook, x, youtube, googleMaps}}`, `openingHours {mon: "07:00-11:00,18:00-23:30", …}`, `visibility {phone, email, address, hours, social}`, `country`, `currency`, `timezone`, `themeId`, `themeSettings {primary, secondary, background, font, layout, cardLayout, mode}`, `slug`, `qrCode`, `status` (`active`, `suspended`, `deactivated`, `deleted`), `ownerUid`, `planId`, `planFeatures {maxItems, maxCategories, premiumThemes, analyticsDays, qrLogo, removeBranding}` (M10, copied from the plan), `subscription {status: free|active|grace, planId, billing, startAt, expiresAt, graceEndsAt, remindersSent[]}`, `pendingUpgradeRequestId`, `planNotice`, `counts {categories, items}`, `publishedVersion` (int or null), `publishedAt`, `publishedDraftAt`, `publishedCurrency`, `versionHistory[]` (M06), `draftUpdatedAt`, `setupCompletedAt?`, `createdAt`, `deactivatedAt?`.

The root document's profile and theme fields are the **draft**. They go live only when published (FR-012).

Profile field formats (M03):

- `contact`: empty values are left out. `phone` is E.164 (checked against the restaurant's country in the app). `website` and every `social.*` link are `https://` URLs.
- `openingHours`: one string per weekday `mon`…`sun`, up to 3 slots `"HH:mm-HH:mm"` joined by `,`; `""` is closed. Times are wall-clock in `timezone`. A close earlier than the open runs past midnight (only the last slot of a day may), `"00:00"` as a close is midnight, and `"00:00-00:00"` is open all day. The field is absent or `null` until the owner adds hours. One string per day (instead of a list of `{open, close}` maps) lets the security rules check a whole week with one regex; the slot maps did not fit the rules' per-request evaluation budget.
- `visibility`: a flag set to `false` hides that group on the public menu (FR-013, FR-014); a missing flag means shown. The owner app writes all five.
- `setupCompletedAt`: set when the owner finishes or skips the first-run setup wizard.
- `nameLower` and `pricesNeedReview` are maintained by `onRestaurantUpdated` (M03); `slug` changes only through `changeSlug`.

Publishing fields (M06), written only by `publishMenu`, `rollbackMenu` and `discardDraft`:

- `publishedVersion`, `publishedAt`, `publishedCurrency` (the live version's currency; `onRestaurantUpdated` does not ask for a price review when the currency returns to it).
- `publishedDraftAt`: the `draftUpdatedAt` the live version matches. The owner app shows "Unpublished changes" while `draftUpdatedAt > publishedDraftAt`, or when it is `null` (a rollback that kept the draft). The menu triggers stamp `draftUpdatedAt` with the edited document's own `updatedAt`, so an edit committed before a publish never looks newer than it. Availability changes never touch it (BR-018).
- `versionHistory`: `[{n, kind, rollbackOf, publishedAt, publishedBy, summary}]`, newest first, at most 10, for the history screen.

Theme fields (M05):

- `themeId`: a `themes/{id}` document id, or `null` until the owner chooses (the setup checklist step).
- `themeSettings`: only the owner's overrides of that theme, any of `primary`, `secondary`, `background` (`#RRGGBB`, upper case), `font` (letters and spaces, ≤ 40), `layout`, `cardLayout`, `mode`. Choosing another theme resets it to `{}`.
- What the menu shows is `resolveTheme(tokens, settings)` (`functions/src/theme/resolve.ts`, mirrored by `resolveMenuTheme()` in core): overrides win; text, card text, muted text and the accent (primary used as text) are raised to WCAG AA 4.5:1 automatically (FR-060), and the owner app warns when that happens.

| Subcollection | Fields | Notes |
| --- | --- | --- |
| `categories/{cid}` | `name`, `description`, `image`, `sequence`, `active`, `deletedAt`, `createdAt`, `updatedAt` | Soft delete (FR-098). `deletedAt` is `null` while live |
| `items/{iid}` | `categoryId`, `name`, `description`, `image`, `priceMinor` (int), `dietaryLabelId`, `tagIds[]`, `available`, `featured`, `sequence`, `hiddenOverLimit`, `deletedAt`, `deletedWith`, `createdAt`, `updatedAt` | Draft content. `deletedWith`: the category it was deleted together with (restored with it) |
| `versions/{n}` | `n`, `kind` (`publish` or `rollback`), `rollbackOf`, `publishedAt`, `publishedBy`, `summary {added, changed, removed, profileChanged, themeChanged}`, `snapshot {schema, profile, theme, categories[], items[], currency, locale, timezone}` | Immutable. Keep the last 10 (FR-096). Shape: master plan, Cross-module notes (M06) |
| `versions/{n}/private/source` | `{restaurant, categories[], items[], imageUrls}`: the full draft at that version, for discard and rollback | Functions only (M06) |
| `live/availability` | `{items: {iid: bool}, updatedAt}` | Written by `onItemWrite` on every availability change (FR-095); Functions only |
| `analyticsDaily/{yyyy-MM-dd}` | `views`, `qrVisits`, `categoryTaps {cid: n}`, `itemOpens {iid: n}` | Day in the restaurant's time zone |
| `payments/{id}` | `amountMinor`, `currency`, `method`, `reference`, `paidAt`, `recordedBy` | Admin only (FR-106) |
| `subscriptionHistory/{id}` | Every plan change with reason | Functions only |

### 4.3 Counts and limits

`counts.items` and `counts.categories` count non-deleted documents. Creating, deleting and restoring a category or item goes through a callable function that counts the live documents inside a transaction, checks the plan limit, and writes the new count to the restaurant root in the same transaction. Writing the root makes two concurrent creates conflict, so the retry sees the other's document and two devices cannot both pass the limit. The triggers `onCategoryWrite` / `onItemWrite` recount when a document starts or stops counting, which catches changes made outside the callables (M04).

Plan limits come from `plans/{planId}.limits` through `getPlanLimits()` (`functions/src/lib/plan-limits.ts`), with the FRD §4.11 values as the fallback while a plan document is missing.

Menu order is `sequence` ascending (ties by id). New documents go last with gaps of 1000; a drag writes only the moved document, halfway between its neighbours, and renumbers the list only when there is no room left.

### 4.4 Image object

`{path, contentType, width, height, renditions: {w320, w640, w1280}, status: 'processing'|'ready'|'rejected'}`. Paths: `restaurants/{rid}/images/{uuid}/original.{ext}`, renditions next to it as WebP.

As built in M02, by status:

- `processing`: `{path, status, uploadedAt}`
- `ready`: `{path, status, contentType, width, height, renditions: {w320, w640, w1280}, uploadedAt}`. `renditions` holds Storage paths (`…/w320.webp`). Images narrower than a width are not enlarged. `width` and `height` are the upright original's.
- `rejected`: `{path, status, reason, uploadedAt}`. `reason` is `unsupported-type`, `too-large`, `too-small`, `invalid-image` or `processing-failed`.

Only `processImage` writes these objects. It finds the target from the upload's custom metadata `{purpose, targetPath, field}`, and the field must be one of `restaurants/{rid}.logo`, `restaurants/{rid}.cover`, `…/categories/{cid}.image` or `…/items/{iid}.image` of the same restaurant. Clients only set a field to `null` to remove an image. Uploaded files are never deleted when an image is replaced or removed, because published versions may still reference them.

## 5. Security model

- **Custom claims** set by Functions: `role` (`owner` or `platformAdmin`) and `restaurantId`.
- Owners must have `email_verified == true` to read or write anything (FR-091).
- Rules pattern for the tenant subtree:

```
match /restaurants/{rid} {
  function isOwner() { return request.auth != null
    && request.auth.token.email_verified == true
    && request.auth.token.role == 'owner'
    && request.auth.token.restaurantId == rid
    && get(/databases/$(database)/documents/restaurants/$(rid)).data.status == 'active'; }
  function isAdmin() { return request.auth != null && request.auth.token.email_verified == true
    && request.auth.token.role == 'platformAdmin'
    && request.auth.token.firebase.sign_in_second_factor == 'totp'; }   // FR-084 (M01)
  allow read: if isOwner() || isAdmin();
  allow update: if isOwner() && request.resource.data.diff(resource.data).affectedKeys()
                   .hasOnly(['name','businessType','description','logo','cover','contact','openingHours',
                             'visibility','currency','timezone','themeId','themeSettings','draftUpdatedAt',
                             'setupCompletedAt'])
                && /* draft changes stamp draftUpdatedAt == request.time; value checks (M03) */ true;
  match /categories/{cid} { allow read: if isOwner() || isAdmin(); allow update: if isOwner() && /* field whitelist */ true; }
  match /items/{iid}      { allow read: if isOwner() || isAdmin(); allow update: if isOwner() && /* field whitelist */ true; }
  match /versions/{n}     { allow read: if isOwner() || isAdmin(); allow write: if false; }   // M06; versions/{n}/private/** and live/** stay closed
  // create and delete of categories/items go through callable functions
}
```

- Owner updates of the tenant root (M03, `validOwnerUpdate()` in `firestore.rules`) also check every changed value: name 1–80 characters, known business type, description ≤ 500, `logo`/`cover` only to `null`, `contact`/`social` shapes and formats, `openingHours` format, `visibility` booleans, ISO currency code, IANA-style time zone. A draft change must set `draftUpdatedAt` to the server time, and `setupCompletedAt` must be the server time. Rules stop evaluating a request after a fixed amount of work, so these checks use one regex per group (see the comment in the rules); `restaurant-profile.test.js` has a test that writes every field at once.
- Menu content (M04): owners update only whitelisted fields of `categories` (`name, description, image, sequence, active`) and `items` (`name, description, image, priceMinor, dietaryLabelId, tagIds, featured, sequence, available`), plus `updatedAt == request.time`. Soft-deleted documents can't be edited. `image` can only become `null`, `priceMinor` must be an integer from 0 to 999,999,999, and `dietaryLabelId` must exist. Creating, deleting, moving and restoring go through callables. `dietaryLabels` and `itemTags` are readable by owners and admins.
- Theme (M05): owners set `themeId` to an existing `themes` document (or `null`) and `themeSettings` to `null` or a map checked with one regex (allowed keys, upper-case hex colours, a plain font name, known layout values). Plan gating of premium themes is M10. `themes` and `config/platform` are readable by verified owners and TOTP admins and written only by Functions.
- Storage rules: owners can write only under `restaurants/{theirRid}/images/**`, content type `image/jpeg|png|webp`, size ≤ 5 MB (FR-102).
- Admin app: Firebase Authentication with Identity Platform TOTP multi-factor, required for `platformAdmin` (FR-084). Rules and `assertAdmin()` check `firebase.sign_in_second_factor == 'totp'`; only the Functions emulator under a `demo-` project skips the `assertAdmin()` check, because the Auth emulator has no TOTP (M01).
- Every rule has a test in `firestore-tests/` using `@firebase/rules-unit-testing`.

## 6. Flutter app structure

```
/apps/owner_app        Flutter app (web, android, ios)
/apps/admin_app        Flutter app (web)
/packages/core         Shared Dart package: models (freezed), repositories, money, time, theme, widgets, l10n
/functions             Cloud Functions (TypeScript): callables, triggers, schedules, public menu renderer
/firestore-tests       Security rules tests
/firestore.rules  /storage.rules  /firestore.indexes.json  /firebase.json  /.firebaserc
/docs
```

The repo is a Dart pub workspace (root `pubspec.yaml` lists `apps/*` and `packages/*`).

- **State:** Riverpod (code generation). **Routing:** go_router with auth and role guards. **Models:** freezed + json_serializable.
- **Feature-first folders** inside each app: `lib/features/<feature>/{data,domain,presentation}`.
- **Environments:** two Firebase projects, `eazy-suvai-dev` and `eazysuvai-prod`, selected with `--dart-define=ENV=dev|prod` and generated `firebase_options_*.dart`.
- **Brand:** primary orange `#FF7A00` (decorative and large text), deep orange `#C8650A` (large text and icons on light backgrounds), charcoal `#2B2B2B`, leaf green `#4C9A2A`, background `#FFFFFF` / `#FFF8EE`. Logo files in `docs/brand/`.
- **Accessible text colours (M00):** `#C8650A` is only about 3.9:1 on white and `#4C9A2A` about 3.5:1, both below WCAG AA for normal text. Normal-size text, links and filled-button backgrounds therefore use `#A8550A` (orange, about 5.3:1 on white and 5.0:1 on cream) and `#3B7A20` (green, about 5.2:1). Dark mode uses `#FF7A00` as primary on a charcoal surface. Defined in `packages/core/lib/src/theme/brand_colors.dart`; `app_theme_test.dart` checks every pair. The public menu (M07) must apply the same rule to restaurant theme colours.

### Responsive breakpoints

| Class | Width | Navigation | Layout |
| --- | --- | --- | --- |
| Compact | < 600 px | Bottom navigation bar | Single column; forms full width; lists open detail as a new page |
| Medium | 600–1023 px | Navigation rail | Two columns where useful; dialogs instead of full pages |
| Expanded | ≥ 1024 px | Side menu (240 px) | List–detail panes (for example categories left, items right); content max width 1200 px |

A shared `ResponsiveScaffold` and `Breakpoint` helper in `packages/core` implement this. Every screen has widget tests at 360, 768 and 1280 px width.

## 7. Cloud Functions inventory

| Area | Function | Type | Module |
| --- | --- | --- | --- |
| Auth | `completeRegistration`, `cleanupUnverifiedUsers` (daily) | callable, schedule | M01 |
| Media | `processImage` | Storage trigger | M02 |
| Restaurant | `changeSlug`, `onRestaurantUpdated` | callable, trigger | M03 |
| Menu | `createCategory`, `createItem`, `deleteCategory`, `deleteItems`, `moveItems`, `restoreDeleted`, `onItemWrite`, `onCategoryWrite` | callable, triggers | M04 |
| Theme | No deployed functions. `functions/src/theme/` holds `contrastRatio`, `readableTextOn`, `resolveTheme`, `cssVariables` and the seed themes, used by M06/M07 | library | M05 |
| Publishing | `publishMenu` (with `dryRun`), `rollbackMenu`, `discardDraft`, `previewMenu` (draft HTML for the owner). Snapshot builder, change summary and validation in `functions/src/publishing/snapshot.ts`; the page renderer `renderMenuPage()` in `functions/src/public/` (M07 extends it) | callable | M06 |
| Public | `renderMenu`, `collectEvent` | HTTPS | M07, M09 |
| Analytics | `rollupAnalytics` (hourly, if needed) | schedule | M09 |
| Subscriptions | `requestUpgrade`, `recordPaymentAndActivate`, `changeSubscription`, `closeUpgradeRequest`, `adminListUpgradeRequests`, `setHiddenOverLimit`, `subscriptionDaily` | callable, schedule | M10 |
| Admin | `setRestaurantStatus`, `adminSearchRestaurants`, `adminGetRestaurant`, `adminDashboard`, `recomputePlatformStats`, `upsertPlan`, `upsertLabel` (labels and tags), `upsertTheme`, `updatePlatformConfig`, `setAnnouncement`, `adminListCatalog`, `setAdminRole`, `adminListAdmins`; trigger `onRestaurantStats` | callable, trigger | M11 |
| Lifecycle | `requestAccountDeletion`, `exportMenu`, `adminListAuditLogs`, `purgeDaily` (daily 02:30 IST; FRD §7.7 rules) | callable, schedule | M12 |
| Shared | `writeAudit()`, `assertAdmin()`, `assertOwner()`, `getPlanLimits()` (M04; M10 extends it) | library | M00 |

Every callable validates its input with a schema (zod) and returns typed errors with stable codes that the apps map to localized messages.

## 8. Testing

| Layer | Tool |
| --- | --- |
| Dart unit and widget tests | `flutter test` (widget tests at 3 widths) |
| Security rules | `@firebase/rules-unit-testing` on the emulator |
| Functions | Jest + Firebase emulators |
| End-to-end | `integration_test` on the emulators for the main flows |
| Public menu | Lighthouse CI against the emulator-hosted page (performance budget) |

## 9. Decisions to revisit

- Hosting multi-site domains are placeholders.
- Identity Platform (needed for admin MFA) must be enabled on the Firebase project; check pricing.
- Firestore TTL policies are set on `analyticsEvents.expireAt` and `auditLogs.expireAt`.
- If analytics volume grows past Firestore limits, move raw events to BigQuery.
