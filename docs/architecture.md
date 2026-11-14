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

- Firebase Hosting site `menu` rewrites every path to the HTTPS function `renderMenu`.
- Routes:

| Path | Result |
| --- | --- |
| `/{slug}` | The menu page. An old slug answers 301 to the current slug (FR-093). |
| `/q/{code}` | 302 to `/{slug}?src=qr`, and the visit counts as a QR visit (FR-048). |
| `/sitemap.xml` | Active, published restaurants only |
| `/robots.txt` | Allows the menu pages; disallows `/q/` |
| `/e` (POST) | Analytics beacon (M09) |

- The function reads `slugs/{slug}`, then `restaurants/{rid}` (status), the current version `restaurants/{rid}/versions/{n}`, and the live availability overlay `restaurants/{rid}/live/availability`.
- Response header: `Cache-Control: public, max-age=0, s-maxage=60`. Changes therefore show within 60 s (FR-044).
- Account states follow FR-099: 200 live menu, 404 "coming soon", 503 "temporarily unavailable", 410 "no longer available". Pages that are not live carry `noindex`.
- Templates live in `functions/src/public/templates/` as TypeScript template functions, with HTML escaping on every value. Theme colours are passed as CSS custom properties.
- Images are served from the Storage rendition URLs with `srcset` (320/640/1280) and `loading="lazy"`.

## 4. Firestore data model

All timestamps are Firestore `Timestamp` in UTC. IDs are Firestore auto-IDs unless stated.

### 4.1 Global collections

| Path | Purpose | Written by |
| --- | --- | --- |
| `users/{uid}` | Profile: `email`, `displayName`, `mobile`, `role` (`owner` or `platformAdmin`), `restaurantId`, `createdAt` | Functions |
| `restaurants/{rid}` | Tenant root (4.2) | Owner (allowed fields only), Functions |
| `slugs/{slug}` | `{restaurantId, current: bool, releasedAt?}`; one doc per current or old slug | Functions |
| `qrCodes/{code}` | `{restaurantId, kind: 'restaurant'}`; permanent, never reused | Functions |
| `plans/{planId}` | `name`, `limits {maxItems, maxCategories, maxBranches, themeIds[], analyticsDays, qrLogo, removeBranding}`, `prices {INR, AED, KWD}`, `isFree`, `active` | Admin via Functions |
| `dietaryLabels/{id}`, `itemTags/{id}` | `name`, `icon`, `color`, `sort`, `retired` (FR-104) | Admin via Functions |
| `themes/{id}` | Predefined theme tokens (M05) | Admin via Functions |
| `config/platform` | `reservedSlugs[]`, `graceDays` (default 14), `fonts[]`, `currencies{code: decimals}` | Admin via Functions |
| `upgradeRequests/{id}` | `restaurantId`, `requestedPlanId`, `status`, `createdAt` | Owner (create), Functions |
| `auditLogs/{id}` | `actorUid`, `actorRole`, `action`, `restaurantId?`, `target`, `reason?`, `details`, `at`, `expireAt` (TTL 2 years) | Functions only |
| `analyticsEvents/{id}` | Raw beacon events, `expireAt` (TTL 90 days) | Functions only |
| `stats/platform` | Counters for the admin dashboard (FR-085) | Functions only |

### 4.2 Tenant subtree `restaurants/{rid}`

Root document fields: `name`, `nameLower` (for admin search), `ownerName`, `ownerEmail`, `ownerMobile` (E.164), `pricesNeedReview`, `businessType`, `description`, `logo`, `cover` (image objects, 4.4), `contact {phone, email, address, city, postalCode, website, social{}}`, `openingHours {mon: [{open, close}], …}`, `visibility {phone, email, address, hours, social}`, `country`, `currency`, `timezone`, `themeId`, `themeSettings {primary, secondary, background, font, layout, cardLayout, mode}`, `slug`, `qrCode`, `status` (`active`, `suspended`, `deactivated`, `deleted`), `ownerUid`, `planId`, `subscription {status, startAt, expiresAt, graceEndsAt}`, `counts {categories, items}`, `publishedVersion` (int or null), `draftUpdatedAt`, `createdAt`, `deactivatedAt?`.

The root document's profile and theme fields are the **draft**. They go live only when published (FR-012).

| Subcollection | Fields | Notes |
| --- | --- | --- |
| `categories/{cid}` | `name`, `description`, `image?`, `sequence`, `active`, `deletedAt?` | Soft delete (FR-098) |
| `items/{iid}` | `categoryId`, `name`, `description`, `image?`, `priceMinor` (int), `dietaryLabelId`, `tagIds[]`, `available`, `featured`, `sequence`, `hiddenOverLimit`, `deletedAt?`, `updatedAt` | Draft content |
| `versions/{n}` | `n`, `publishedAt`, `publishedBy`, `summary {added, changed, removed}`, `snapshot {profile, theme, categories[], items[], currency, locale}` | Immutable. Keep the last 10 (FR-096) |
| `live/availability` | `{items: {iid: bool}}` | Updated on every availability change (FR-095) |
| `analyticsDaily/{yyyy-MM-dd}` | `views`, `qrVisits`, `categoryTaps {cid: n}`, `itemOpens {iid: n}` | Day in the restaurant's time zone |
| `payments/{id}` | `amountMinor`, `currency`, `method`, `reference`, `paidAt`, `recordedBy` | Admin only (FR-106) |
| `subscriptionHistory/{id}` | Every plan change with reason | Functions only |

### 4.3 Counts and limits

`counts.items` and `counts.categories` count non-deleted documents. They are kept by Firestore triggers. Creating a category or item goes through a callable function that checks the plan limit inside a transaction, so two devices cannot both pass the limit.

### 4.4 Image object

`{path, contentType, width, height, renditions: {w320, w640, w1280}, status: 'processing'|'ready'|'rejected'}`. Paths: `restaurants/{rid}/images/{uuid}/original.{ext}`, renditions next to it as WebP.

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
                             'visibility','currency','timezone','themeId','themeSettings','draftUpdatedAt']);
  match /categories/{cid} { allow read: if isOwner() || isAdmin(); allow update: if isOwner() && /* field whitelist */ true; }
  match /items/{iid}      { allow read: if isOwner() || isAdmin(); allow update: if isOwner() && /* field whitelist */ true; }
  match /versions/{n}     { allow read: if isOwner() || isAdmin(); allow write: if false; }
  // create and delete of categories/items go through callable functions
}
```

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
- **Environments:** two Firebase projects, `eazysuvai-dev` and `eazysuvai-prod`, selected with `--dart-define=ENV=dev|prod` and generated `firebase_options_*.dart`.
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
| Menu | `createCategory`, `createItem`, `deleteCategory`, `moveItems`, `restoreDeleted`, `onItemWrite`, `onCategoryWrite` | callable, triggers | M04 |
| Publishing | `publishMenu`, `rollbackMenu`, `discardDraft` | callable | M06 |
| Public | `renderMenu`, `collectEvent` | HTTPS | M07, M09 |
| Analytics | `rollupAnalytics` (hourly, if needed) | schedule | M09 |
| Subscriptions | `requestUpgrade`, `recordPaymentAndActivate`, `changeSubscription`, `subscriptionDaily` | callable, schedule | M10 |
| Admin | `setRestaurantStatus`, `upsertPlan`, `upsertLabel`, `upsertTag`, `upsertTheme`, `updatePlatformConfig`, `setAdminRole` | callable | M11 |
| Lifecycle | `requestAccountDeletion`, `exportMenu`, `purgeDaily` | callable, schedule | M12 |
| Shared | `writeAudit()`, `assertAdmin()`, `assertOwner()`, `getPlanLimits()` | library | M00 |

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
