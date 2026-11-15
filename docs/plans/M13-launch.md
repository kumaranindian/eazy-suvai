# M13 – Hardening, acceptance and launch

Status: Done (pre-launch; see Open items)
Started: 2026-11-15
Completed: 2026-11-15

## Goal

Prove the MVP meets the FRD: all 30 acceptance criteria pass, performance and security targets are met, monitoring and backups are on, and the apps are live.

## FRD coverage

§7 (all non-functional requirements), §10 (AC-001 to AC-030), §13 (success metrics).

## Depends on

All other modules marked Done.

## Inputs from other modules

Every module's Completion notes and Open items.

## Tasks

### Quality

- [x] Run every acceptance criterion AC-001 to AC-030 and record the result and evidence in the table below.
- [x] Integration test suite covering: sign-up → profile → menu → publish → scan → analytics; downgrade and upgrade; suspension.
- [x] Responsive pass: every owner screen at 360, 768 and 1280 px on web, plus one Android phone, one iPhone and one tablet. (Widths automated; the three devices are in the runbook, step 6.)
- [x] Accessibility pass: screen reader labels, contrast, keyboard use on web, text scaling to 200%.
- [x] Localization readiness: no hard-coded strings; a pseudo-locale and an RTL test locale render without layout breaks.

### Security

- [x] Rules tests for every collection, including cross-tenant attempts (AC-017).
- [x] App Check enabled for Firestore, Storage and Functions (Play Integrity, App Attest, reCAPTCHA Enterprise on web). (Code and callable enforcement done; console registration and Firestore/Storage enforcement are runbook step 2.)
- [x] Review callable input validation and error messages for information leaks.
- [x] Dependency audit (`flutter pub outdated`, `npm audit`).

### Performance and reliability

- [x] Lighthouse on 3 real restaurant menus: LCP ≤ 2.5 s (4G), payload ≤ 150 KB, accessibility ≥ 95.
- [x] Load test the public menu (for example k6) at 200 requests/s mostly served from the CDN. (Local: handler at 200/s on one core and the emulator chain; the k6 run through the real CDN is runbook step 7.)
- [ ] Firestore point-in-time recovery and daily exports to a Cloud Storage bucket; one test restore. (Scripts ready: `ops/backups.sh`, `ops/restore-test.sh`; the restore check is tested on the emulator. Not run: needs the real project.)
- [ ] Cloud Monitoring alerts: function error rate, `renderMenu` 5xx rate and latency, uptime check on a sample menu. (Ready: `ops/monitoring.sh` + `ops/monitoring/*.json`. Not applied.)
- [x] Crashlytics in the owner app.

### Launch

- [ ] Production Firebase project configured: domains, Hosting sites, email templates (verification, reset) with the brand, Identity Platform MFA. (Templates and `ops/auth-config.sh` ready; domains are an open decision.)
- [ ] Seed production plans, labels, tags, themes and config. (`seed-platform.mjs` now needs `--confirm-prod`; not run.)
- [x] Privacy policy and terms pages linked from sign-up and the public footer. (Draft text pending legal review.)
- [ ] Play Store and App Store listings (owner app), with screenshots at phone and tablet sizes. (Checklist: `docs/launch/store-listing.md`. Not submitted.)
- [x] Success-metric counters (FRD §13) visible on the admin dashboard.

## Acceptance results

| AC | Result | Evidence / notes |
| --- | --- | --- |
| AC-001 | Pass | `e2e/journey.emu.test.ts` (sign-up → verify → sign in through Auth REST and the callable), `auth/e2e.emu.test.ts`, `auth/register.emu.test.ts`; owner `integration_test/sign_up_flow_test.dart` (sign-up, verification, sign-out, reset) in Chrome on the emulators |
| AC-002 | Pass | `profile_page_test.dart`, `integration_test/profile_flow_test.dart`; rules `restaurant-profile.test.js` (show/hide public fields, field validation) |
| AC-003 | Pass | `menu/menu.emu.test.ts` (create, rename, reorder, delete), `menu_page_test.dart`, `integration_test/menu_flow_test.dart` |
| AC-004 | Pass | `menu/menu.emu.test.ts`, `item_editor_test.dart`, `menu_page_test.dart`, `integration_test/menu_flow_test.dart` |
| AC-005 | Pass | `media/process-image.emu.test.ts` (JPEG/PNG/WebP up to 5 MB re-encoded, other content refused by magic bytes), rules `storage.test.js`, core `media/*_test.dart`, `integration_test/media_flow_test.dart` |
| AC-006 | Pass | core `menu/menu_test.dart` (icon + text for the 4 classifications), `item_editor_test.dart`, `menu_page_test.dart`; public menu snapshot `public.test.ts` |
| AC-007 | Pass | `menu/menu.emu.test.ts` (availability reaches `live/availability` without a publish), `render-menu.emu.test.ts` ("availability without a publish"); CDN `s-maxage=60` keeps it within 60 s |
| AC-008 | Pass | `e2e/journey.emu.test.ts` and `render-menu.emu.test.ts` fetch the menu with no credentials; Hosting serves it from a separate site that sets no auth cookies |
| AC-009 | Pass (emulated); devices open | `lighthouse-budget.mjs`: 3 menus at 360/768/1280 px, no horizontal scroll, columns, sidebar, lightbox, JavaScript off; mobile Lighthouse profile. Real Android, iPhone and tablet browsers: runbook step 6 |
| AC-010 | Pass (decoded); camera scan open | `qr_share_test.dart` downloads the PNG (≥ 1024 px) and both PDF templates and decodes each back to `/q/{code}`; a physical scan with phone cameras is runbook step 6 |
| AC-011 | Pass | `e2e/journey.emu.test.ts` (`/q/{code}` → 302 to the current slug after content updates), `restaurant/restaurant.emu.test.ts` (QR keeps working after a slug change), `render-menu.emu.test.ts` |
| AC-012 | Pass | `integration_test/theme_flow_test.dart`, `theme_page_test.dart`; public menu snapshots (theme tokens, logo, cover); Lighthouse screenshots |
| AC-013 | Pass | `publishing/publish.emu.test.ts` (preview, publish with summary, rollback), `e2e/journey.emu.test.ts`, `integration_test/publish_flow_test.dart` |
| AC-014 | Pass (fakes); real apps open | `qr_share_test.dart`: WhatsApp with a prefilled message, the copy fallback, the native share sheet or copy without Web Share. Real WhatsApp and share sheet: runbook step 6 |
| AC-015 | Pass | `analytics/collect.emu.test.ts`, `e2e/journey.emu.test.ts` (view, QR visit, item open through `/e`), `analytics_test.dart` (date filter at 3 widths), rules `analytics.test.js` |
| AC-016 | Pass | `admin/admin.emu.test.ts` (activate, suspend, deactivate, reactivate with reasons and audit), `e2e/journey.emu.test.ts` (suspend → 503 and publish refused → reactivate), `admin_pages_test.dart` |
| AC-017 | Pass | Rules suites for every collection (163 tests, cross-tenant reads and writes refused); `e2e/inputs.emu.test.ts`: all 34 callables called by tenant A against tenant B — none succeeds, B unchanged; `lib/auth.test.ts` |
| AC-018 | Pass | `menu/menu.emu.test.ts`, `subscriptions/subscriptions.emu.test.ts`, `e2e/journey.emu.test.ts` (item 51 refused on Free with `limit-reached`; publish blocked over limits) |
| AC-019 | Pass | `public.test.ts` (title, description, Open Graph, JSON-LD), `render-menu.emu.test.ts` (sitemap), `e2e/journey.emu.test.ts`; Lighthouse SEO 100 on 3 menus |
| AC-020 | Pass (by design) | No ordering in the MVP (FRD §11); nothing to test |
| AC-021 | Pass | `auth/register.emu.test.ts` (unverified owner refused), `publishing/publish.emu.test.ts` and `snapshot.test.ts` (empty menu and over-limit problems), `integration_test/publish_flow_test.dart` |
| AC-022 | Pass | `publishing/publish.emu.test.ts`: the live pointer moves in one transaction after the immutable version is written; readers during a publish see the old or the new version, never a mix |
| AC-023 | Pass | `render-menu.emu.test.ts`: an old slug answers 301 to the current one, query string kept |
| AC-024 | Pass | `render-menu.emu.test.ts` (suspended 503, deactivated and deleted 410, unpublished coming-soon), `e2e/journey.emu.test.ts`, `lifecycle/lifecycle.emu.test.ts` (purged tenant 410) |
| AC-025 | Pass | `subscriptions/subscriptions.emu.test.ts` (grace keeps working, then Free with hidden content), `e2e/journey.emu.test.ts` (52 items kept, 2 hidden, menu live without them) |
| AC-026 | Pass | `subscriptions/subscriptions.emu.test.ts`, `e2e/journey.emu.test.ts` (upgrade → nothing hidden) |
| AC-027 | Pass | `menu/menu.emu.test.ts` (move or confirm), `menu_page_test.dart` (the dialog) |
| AC-028 | Pass | `menu/menu.emu.test.ts` (restore within 30 days), `lifecycle/lifecycle.emu.test.ts` (purged after 30), `menu_page_test.dart`, `integration_test/menu_flow_test.dart` |
| AC-029 | Pass | `menu/menu.emu.test.ts`, core `menu_test.dart`, `item_editor_test.dart`, `public.test.ts`; Lighthouse `lh-large` (200 items in KWD, 3 decimals) |
| AC-030 | Pass | `subscriptions/subscriptions.emu.test.ts`, `e2e/journey.emu.test.ts` (request → record payment → active; audit entries), `upgrades_test.dart` |

## Completion notes

**Summary.** All 30 acceptance criteria pass in automated tests on the emulators. AC-009, AC-010 and AC-014 also need a check on real devices and apps, listed in the runbook. Everything that needs a real project is prepared as reviewed scripts and documented in `docs/launch/runbook.md`, but **not run**: backups, monitoring, Auth settings, App Check registration, seeding, deploy, and the stores. Nothing was deployed or submitted.

**Quality**

- **End-to-end journey** (`functions/src/e2e/journey.emu.test.ts`). It goes through the real entry points: Auth REST, callable HTTP endpoints and the Hosting emulator.
  1. Sign-up → verify → sign in.
  2. Profile → 2 categories and 50 items; item 51 is refused.
  3. Publish (`firstPublishedAt`) → `/q/{code}` 302 → menu HTML with JSON-LD and beacon.
  4. View, QR visit and item open through `/e`; daily and monthly counters.
  5. Upgrade request → admin records the payment → 52 items → publish.
  6. Downgrade: 2 hidden, not deleted, gone from the public page.
  7. Upgrade: restored. Renewal.
  8. Suspend → 503 and publish refused → reactivate → 200.
  9. Success counters after the recount; legal pages served; audit entries present.

  The 6 owner `integration_test` flows pass in Chrome (`tool/integration.sh`). `theme_flow_test.dart` was stale: since M10, `midnight` is premium and is refused on Free (BR-011). It now expects that refusal and checks that a free theme is accepted.
- **Responsive, accessibility, RTL, 200 % text.**
  - Owner app (`apps/owner_app/test/route_sweep_test.dart`): all 21 owner routes at 360, 768 and 1280 px; at 200 % text; right to left; and Flutter's `labeledTapTargetGuideline`, `androidTapTargetGuideline` and `textContrastGuideline` on every route at 360 and 1280 px.
  - Admin app (`apps/admin_app/test/route_sweep_test.dart`): all 8 routes at 360 (read-only), 768 and 1280 px; at 200 % text; right to left; and the labels and contrast guidelines.

  Any overflow fails the test. The sweep found and fixed:
  - the publish bar: its buttons drop under the label at large text;
  - the item tile: the thumbnail gives way to the name;
  - "Add item": becomes a filled icon button with a tooltip;
  - the save status: capped at 240 px in the app bar;
  - the plan card header: wraps;
  - the theme miniature: a fixed picture that doesn't scale its text;
  - the analytics side-by-side lists: no `IntrinsicHeight`;
  - core `MenuLabelBadge`: wraps;
  - admin section card headers: wrap;
  - the admin announcement switch: merged with its label for screen readers;
  - the admin dashboard tiles: the label is on the tappable node.
- **Localization.** A scan of every `lib/` for literal `Text('…')` finds none. The RTL sweep plays the role of the RTL test locale, through `textDirectionOverrideProvider` in `OwnerApp`. In place of a pseudo-locale, the 200 % text sweep stresses expansion harder than pseudo-localization (+30–40 %). Public menu strings are in `functions/src/public/text.ts`.

**Security**

- **Rules:** 163 tests cover every collection, cross-tenant attempts included. New in M13: the `qrDownloads` counter (+1 only, alone, own tenant).
- **Callable sweep** (`functions/src/e2e/inputs.emu.test.ts`). It discovers all 34 callables from the built entry point and checks three things:
  - **anonymous callers:** every callable answers `UNAUTHENTICATED`. 15 callables parsed input before checking sign-in (anonymous callers got `INVALID_ARGUMENT`); fixed with `assertSignedIn` first;
  - **malformed input:** 7 kinds per callable (null, strings, numbers, arrays, operator objects, 20 KB strings, wrong types). Never `INTERNAL`, never a stack trace or path in a message;
  - **tenant A against tenant B:** no callable succeeds, and B's documents are unchanged.
- **App Check:**
  - Core `activateAppCheck(env)`, called from `initFirebase` (`AppCheckPlan`, unit tested):
    - **emulators:** off;
    - **dev:** debug providers;
    - **prod:** Play Integrity, App Attest with a DeviceCheck fallback, and reCAPTCHA Enterprise (`RECAPTCHA_ENTERPRISE_KEY`).
  - Functions: `enforceAppCheck` as a global option, from `ENFORCE_APP_CHECK` in `functions/.env.<projectId>` (prod `true`, dev `false`; both committed, no secrets). HTTP functions stay public.
- **Dependencies:**
  - `npm audit --omit=dev`: **0** vulnerabilities in functions and firestore-tests.
  - Dev only: 25 moderate in functions, all from jest and typescript-eslint pulling old `glob`, `minimatch` and `deepmerge`. Not deployed.
  - `flutter pub outdated`: direct packages lag only because Flutter 3.32.8 / Dart 3.8 pins `vector_math` 2.1.4. No pub security advisories.

**Performance and reliability**

- **Lighthouse** (`npm run test:lighthouse`; mobile, simulated slow 4G):

  | Menu | LCP | Payload | Accessibility | Performance |
  | --- | --- | --- | --- | --- |
  | `lh-list` | 1.42 s | 47 KB | 100 | 0.92+ |
  | `lh-grid` | 1.20 s | 46 KB | 100 | 0.92+ |
  | `lh-large` (new: 200 items in KWD, cafe-cream theme) | 1.35 s | 61 KB | 100 | 1.00 |

  Best practices and SEO are 100. KWD prices show 3 decimals.
- **Load** (`npm run test:load`):
  - **render mode:** renderMenu's per-request work (render + gzip) at 200 requests/s on one core, open loop, 6,000 requests: 199.9 req/s achieved, p95 3 ms, 0 errors. A 200-item menu renders at about 240 requests/s per core.
  - **hosting mode:** the full Hosting → Functions emulator chain at 15/s with beacons: 15 req/s, p95 58 ms, 0 errors. On one machine the emulator queues requests from about 20/s, so this checks correctness under concurrency.
  - **Bug found and fixed:** price formatting built three `Intl.NumberFormat` objects per price, about 85 % of render time. They are now cached per currency and per (locale, currency); `dayKeyIn` (beacons) likewise. Menu render is 5–10× faster (36 items 2.9 → 0.55 ms, 200 items 13.7 → 1.3 ms) and the snapshots are unchanged.
  - **For a real project:** `functions/scripts/load/menu.k6.js` (200/s for 5 minutes through the CDN).
- **Backups and restore:**
  - `ops/backups.sh`: point-in-time recovery (7 days), a daily managed backup kept 5 weeks, and a weekly export to a regional bucket with a 35-day lifecycle.
  - `ops/restore-test.sh`: restores into a new database, compares counts with `ops/compare-counts.mjs` and deletes the copy. The comparison is verified on the emulator: a match passes, an empty copy fails.
- **Monitoring:** `ops/monitoring.sh` sets up:
  - an email channel;
  - a log-based `function_errors` metric;
  - policies for function errors, renderMenu 5xx rate and p95 latency;
  - an uptime check on a sample menu from 3 regions, with its own alert.
- **Crashlytics:** `firebase_crashlytics` in the owner app, with the Gradle plugin. It records Flutter and platform errors on Android and iOS; off on web and the emulators, collection off in debug. The Android debug APK builds.

**Launch**

- **Legal:**
  - `hosting/menu/privacy.html` and `terms.html` are static pages on the menu site (`cleanUrls`; the slugs were already reserved), written from what the system actually does (cookieless analytics, FRD §7.7 retention, export and deletion). Both have a visible **Draft** notice until legal review.
  - Links: on sign-up ("By creating an account, you agree to…"), the Account page, and the public menu footer, which keeps them even without branding.
- **Email templates:** `ops/auth/verify-email.html` and `reset-password.html` (brand colours, `%LINK%`), applied by `ops/auth-config.sh` together with TOTP MFA, the password policy, email enumeration protection and authorized domains.
- **Seeding:** `seed-platform.mjs` refuses `eazysuvai-prod` without `--confirm-prod`.
- **Stores:** `docs/launch/store-listing.md` (both stores: listing, screenshot sizes, data-safety and privacy answers, reviewer account, export compliance).
- **FRD §13 metrics** on the admin dashboard ("Success metrics" card):

  | Metric | Source |
  | --- | --- |
  | Activated restaurants and % | `activated`: published at least once; tombstones keep it |
  | Live published menus | `publishedMenus` |
  | QR codes downloaded | `qrDownloads`, counted by the owner app |
  | Median time from sign-up to first publish | `firstPublishedAt`; median recounted nightly |
  | This month's views and QR visits | `monthly.{yyyy-MM}` from the beacon |
  | Free-to-paid conversions and % | `conversions` |
  | Renewals and renewal rate | `renewals` against expiries |
  | Churn | Deactivated + deleted |
  | Average items per restaurant | Derived |
  | Support requests | "tracked in the support inbox": there is no in-app support channel |

  `purgeDaily` now ends with `recomputeStats`. New index: `restaurants (status, publishedVersion)`.

**Tests at completion** (all passing)

| Suite | Tests |
| --- | --- |
| Functions unit | 327 |
| Functions emulator | 133 + Storage checks |
| Rules | 163 |
| Core | 225 |
| Owner app | 240 |
| Admin app | 49 |
| Owner integration (Chrome) | 6 flows |
| Lighthouse (3 menus) | pass |
| Load (render 200/s, hosting) | pass |

Lint and analyze are clean.

## Open items

Exact steps are in `docs/launch/runbook.md`.

1. **Decisions:** final domains (menu, app, admin) before any QR code is printed; the support and privacy mailboxes.
2. **Legal review** of the privacy policy, the terms and the retention periods (DPDP Act 2023, GCC). Then remove the Draft notices.
3. **Production project:**
   - Blaze plan, Identity Platform, Hosting sites and custom domains;
   - `flutterfire configure` for Android and iOS (dev and prod);
   - application id and release signing (`android/app/build.gradle.kts` still has the template TODO).
4. **App Check:**
   - register the apps (SHA-256 for Play Integrity, Apple Team ID for App Attest) and the reCAPTCHA Enterprise keys;
   - after a week above 99 % verified, enforce for Firestore and Storage.
5. **Apply the ops scripts** on dev, then prod: `auth-config.sh`, `backups.sh`, `monitoring.sh`.
6. **Deploy and seed.** Only after agreeing to it. Then check indexes and TTL.
7. **Smoke test on real devices** (runbook step 6). This closes AC-009 (Android, iPhone, tablet browsers), AC-010 (camera scan of the printed PDF) and AC-014 (real WhatsApp and share sheet), and covers the FRD §7.5 20-minute onboarding target and a Crashlytics test crash.
8. **After launch:** the first restore test (then every quarter), the k6 load test through the CDN on dev, and App Check enforcement.
9. **Stores:** screenshots, listings, data safety and privacy labels, `ITSAppUsesNonExemptEncryption`, TestFlight and internal testing. Submit only after agreeing to it.
10. **Later:**
    - upgrade Flutter, which unpins `vector_math`, `fl_chart`, `pdf` and the rest;
    - upgrade jest and typescript-eslint, for the dev-only advisories;
    - add an in-app support channel to measure support requests per restaurant.

## Change log

- 2026-11-14: Plan created.
- 2026-11-15: Done (pre-launch).
  - AC-001..030 pass (3 also need a device check).
  - End-to-end journey and callable security sweep (15 callables now check sign-in before input).
  - Route sweeps for the owner and admin apps: 3 widths, 200 % text, RTL, accessibility guidelines; 11 layout fixes.
  - App Check (client and callables) and Crashlytics.
  - Lighthouse on 3 menus; load test; price formatter caching (render 5–10× faster).
  - Backup, restore-test, monitoring and auth scripts.
  - Privacy and terms pages and links; branded email templates; FRD §13 metrics on the dashboard.
  - Runbook and store checklist. Nothing deployed or submitted.
