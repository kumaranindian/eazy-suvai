# M03 – Restaurant onboarding and profile

Status: Done
Started: 2026-11-14
Completed: 2026-11-14

## Goal

After first login the owner completes a guided setup, then manages the restaurant profile, public visibility, currency, time zone and menu URL.

## FRD coverage

FR-008, FR-011 to FR-014, FR-092, FR-093, FR-103, §5.1 (onboarding steps 4–6), §6.2–6.4, BR-002, AC-002, AC-023 (slug part).

## Depends on

M01, M02.

## Inputs from other modules

- M01 (done 2026-11-14): `restaurants/{rid}` is created with slug, QR code, Free plan and defaults (exact fields in the master plan's Cross-module notes). `contact.city` is set when the owner gave a city at sign-up; `ownerName`, `ownerEmail` and `ownerMobile` (E.164) are on the root. Reuse `slugify` / `isValidSlug` / `reservedSlugs` from `functions/src/auth/` in `changeSlug`. `Validators.mobile` and `Countries` are in `core`. Rules: owners can only `get` their restaurant so far; add the `update` whitelist here.
- M02 (done 2026-11-14): `ImagePickerField(purpose: ImagePurpose.logo | cover, restaurantId, targetPath: 'restaurants/$rid', label, value: ImageObject.fromMap(doc['logo']), onRemove: …)` from `core`. **Do not save the uploaded image yourself:** `processImage` writes `logo` / `cover` (`processing`, then `ready` or `rejected`). Pass the live document field as `value`, and on remove set the field to `null`. In the rules `update` whitelist, owners may set `logo` and `cover` **only to `null`** (for example `request.resource.data.logo == resource.data.logo || request.resource.data.logo == null`), so a client cannot point them at arbitrary paths or mark them `ready`. Show images with `ResponsiveImage(image: …)`. The dev page `/dev/media` (owner app, `features/dev/`) can be deleted once the profile screen has these fields.

## Scope

**In:** first-run setup wizard, profile editor, visibility toggles, opening hours editor, currency and time zone settings, slug change, dashboard home with a setup checklist.
**Out:** themes (M05), publishing (M06; profile edits stay in the draft until then).

## Data and backend

- Profile fields are written directly to `restaurants/{rid}` under the field whitelist in the rules (`docs/architecture.md` §5).
- `changeSlug` callable: validates FR-092 format and reserved words, checks availability, marks the old `slugs/{old}` as `current: false` (kept for 301 redirects), creates `slugs/{new}`, writes an audit entry.
- Currency change after first publish: the app shows the FR-103 warning; the trigger `onRestaurantUpdated` sets `pricesNeedReview: true` when `currency` changes and `publishedVersion` is not null. M06 requires the owner to confirm prices were reviewed before publishing, then clears the flag.
- `onRestaurantUpdated` also keeps `nameLower` (for admin search) in sync.
- Country presets in `packages/core`: default currency, time zone, phone format, address field order.

## Screens and responsive behaviour

| Screen | Compact | Medium | Expanded |
| --- | --- | --- | --- |
| Setup wizard (profile → logo → first category hint) | One step per page with a progress bar | Same, wider card | Stepper on the left, step content on the right |
| Dashboard home | Stacked cards: setup checklist, menu status, QR shortcut | 2-column card grid | 3-column grid |
| Profile editor | Sections as expandable panels, sticky Save bar at the bottom | Two columns of fields | Form left (max 720 px), live mini-preview of the menu header right |
| Opening hours | One day per row, time pickers in a bottom sheet | Inline time fields | Same as medium |
| Menu URL (slug) | Field + availability check + copy button | Same | Same |

## Tasks

- [x] Profile repository and Riverpod providers (draft read and write, autosave with a 1 s debounce and a "Saved" indicator).
- [x] Profile form with every FR-011 field and validation (URL, email, phone by country).
- [x] Visibility toggles (FR-013).
- [x] Opening hours editor: per weekday, up to 3 time slots, or closed.
- [x] Currency and time zone pickers; FR-103 warning dialog.
- [x] Logo and cover upload with `ImagePickerField`.
- [x] Slug editor and `changeSlug` callable; old slug kept for redirect.
- [x] First-run setup wizard and dashboard setup checklist.
- [x] Rules tests for the field whitelist (owner cannot change `status`, `planId`, `slug`, `counts`, `qrCode`, `publishedVersion`).

## Acceptance checks

- [x] AC-002: owner creates and updates a full profile. (Widget tests, rules tests, and the Chrome end-to-end `profile_flow_test.dart` through the real rules on the emulators.)
- [x] Changing the slug keeps the old slug resolvable to the restaurant (redirect served in M07). (`slugs/{old}` stays with `current: false`; emulator tests.)
- [x] A reserved or taken slug is refused with a clear message. (Function emulator tests, widget tests, end to end.)
- [x] Hidden fields are flagged so M07 can omit them. (`visibility.*` booleans; rules and widget tests.)
- [x] All screens work at 360, 768 and 1280 px. (Widget tests at all three widths for every M03 screen, and Chrome end to end at 1584 px. Android and iOS were not run; see Open items.)

## Tests

Functions: `changeSlug` (valid, reserved, taken, format errors). Rules: whitelist. Widget: profile form validation; opening hours editor.

## Completion notes

**What was built**

- **Functions (`functions/src/restaurant/`, exported from `src/index.ts`)**
  - `changeSlug` (callable): input `{restaurantId, slug, dryRun?}` (zod, strict; the slug is trimmed and lower-cased).
    - Checks: `assertOwner`, then the FR-092 format (`slug-invalid`), then the live reserved list through M01's `reservedSlugs` (`slug-reserved`).
    - One transaction: refuses a slug held by any other restaurant, current or old (`slug-taken`). It sets `slugs/{old}` to `{current: false, replacedAt}`, creates `slugs/{new}` as `{restaurantId, current: true, createdAt}`, sets `restaurants/{rid}.slug`, and writes the audit entry `restaurant.changeSlug` with `{from, to, reclaimed}`.
    - `dryRun` only checks availability; the field uses it as you type. Changing to the current slug does nothing. An owner may take back one of their own old slugs.
  - `onRestaurantUpdated` (Firestore trigger on `restaurants/{rid}`, logic in the pure `restaurantUpdatePatch(before, after)`):
    - sets `pricesNeedReview: true` when `currency` changes and `publishedVersion != null`;
    - keeps `nameLower` equal to `name.toLowerCase()`;
    - writes only real differences, so it cannot loop, and ignores a deleted restaurant.
  - New error codes `slug-invalid`, `slug-reserved` and `slug-taken` in `lib/errors.ts`, Dart `AppErrorCode` and `core_en.arb`.
- **Rules (`firestore.rules`):** owner `update` of `restaurants/{rid}` through `validOwnerUpdate()`.
  - Allowed keys: the architecture §5 whitelist plus `setupCompletedAt`.
  - Any draft change must set `draftUpdatedAt == request.time`; `setupCompletedAt` must also be the server time.
  - Value checks:
    - name 1–80 characters and not blank; a known business type; description ≤ 500;
    - `logo` and `cover` only `null`;
    - `contact`: keys and formats (E.164 phone, email, postal code, https website and social links);
    - `openingHours`: the format, or `null`;
    - `visibility`: booleans;
    - currency `[A-Z]{3}`; IANA-style time zone;
    - placeholder theme checks for M05.
  - Create and delete stay denied.
- **Core (`packages/core`)**
  - `restaurant/restaurant.dart`: `Restaurant` (`fromMap`, `copyWith`), `ContactInfo`, `SocialNetwork`, `PublicVisibility` (missing = shown), `VisibleField`, `RestaurantFields` (names and limits), `SetupStep` and `SetupChecklist`, `CurrencyNames`.
  - `restaurant/opening_hours.dart`: `Weekday`, `TimeSlot`, `OpeningHours` (wire format, `validate()` returning `HoursIssue`s, `template()`).
  - `restaurant/slug.dart`: `SlugRules`.
  - `geo/address_format.dart` and the `Country` presets: `timezones` and `suggestedTimezones`; `address` with part order, postal label (PIN, ZIP or postal code), pattern and example. The UAE and Qatar have no postal code.
  - Validators: `optionalPhone` (by country, landlines included), `optionalEmail`, `optionalHttpsUrl` / `normalizeHttpsUrl`, `optionalSocialLink` / `normalizeSocialLink` (accepts `@handle` and checks the host), `optionalPostalCode`, `nationalNumber`.
  - Also: `messageForError` maps Firestore errors (permission denied, offline); `ResponsiveScaffold(showAppBar:)`; `AppEnv.menuBaseUrl`.
- **Owner app**
  - `features/restaurant/`:
    - data and state: `RestaurantRepository` (Firestore and the callable), `currentRestaurantProvider`, `DraftAutosave` (1 s debounce; statuses idle, pending, saving, saved, failed and invalid; saves on leaving the page);
    - form: `ProfileFormModel`, shared by the profile page and the wizard;
    - pages: `ProfilePage`; `OpeningHoursPage` with `OpeningHoursEditor`; `RegionalPage` (FR-103 dialog, time zone picker with search); `MenuLinkPage`; `SettingsPage`;
    - shared widgets: `MenuHeaderPreview`, `SaveStatusIndicator`, `SaveBar`, `FormSection`.
  - `features/setup/`: `SetupWizardPage`.
  - `features/home/`: `DashboardPage` (checklist, menu status, QR shortcut). It opens the wizard once per session while `setupCompletedAt` is null.
  - Routes:
    - `/setup` (full screen);
    - `/settings/profile`, `/settings/hours`, `/settings/regional` and `/settings/menu-link`, nested in the Settings branch (the shell hides its app bar there);
    - `/` is the dashboard;
    - the M02 dev page `/dev/media` and its test are removed.
- **Tests**
  - Functions: `restaurant.test.ts` (32 unit tests) and `restaurant.emu.test.ts` (19 on the emulators, including the trigger through the Functions emulator and two restaurants racing for one slug).
  - Rules: `restaurant-profile.test.js` covers forbidden fields, value checks, other tenants, suspended accounts, admins, and the heaviest update.
  - Core: `test/restaurant/restaurant_model_test.dart`, plus `showAppBar` tests.
  - Owner app widget tests: `profile_page_test.dart`, `opening_hours_test.dart`, `regional_test.dart`, `menu_link_test.dart`, `setup_wizard_test.dart`, `dashboard_test.dart`, and the updated `shell_test.dart`.
  - Chrome end to end on the emulators: `integration_test/profile_flow_test.dart`. `sign_up_flow_test.dart` now skips the wizard after the first sign-in.
  - Totals at completion, all passing:

    | Suite | Tests |
    | --- | --- |
    | Core | 151 |
    | Owner app | 86 |
    | Admin app | 19 |
    | Functions unit | 119 |
    | Functions emulator | 47 |
    | Rules | 108 |
    | End to end | 3 of 3 |

**Firestore fields added:** see architecture §4.1 and §4.2: `setupCompletedAt`, the `contact` and `openingHours` formats, the `visibility` rules, and `replacedAt` / `reclaimedAt` on `slugs` docs.

**Decisions that differ from the plan or the architecture**

1. **`openingHours` is one string per day** (`{mon: "07:00-11:00,18:00-23:30", sun: ""}`), not `{mon: [{open, close}]}`.
   - Why: security rules stop evaluating a request after a fixed amount of work. On the emulator, checking slot maps field by field failed after roughly 7–12 slots (depending on how the checks were written), well short of a full week of 21. One regex over the joined week fits even when every field is written at once.
   - The rules check the format; order and overlaps are checked in the app, and M06 should check them when publishing.
   - Architecture §4.2 is updated.
2. **Contact details and social links are each checked with one regex** over `|`-joined values, for the same reason. The headroom is small: about one more contact-sized check in the heaviest write. M05 must keep its theme checks lean (noted in the M05 plan).
3. **New field `setupCompletedAt`** (owner-writable, server time only), so the wizard appears once per account on any device.
4. **`changeSlug` also does the availability check** (`dryRun: true`). Opening `slugs` reads to clients would have exposed other tenants' restaurant ids.
5. **An owner may take back their own old slug.** Its doc flips back to `current: true` with `reclaimedAt`.
6. **The currency warning also appears before the first publish** when items exist, with a softer message. FR-103 only requires it after a publish. `pricesNeedReview` is still set only after a publish.
7. **The country is read-only** (FR-011 says "set at registration"), so it is not in the whitelist.
8. **Visibility:** the app writes all five flags. A missing flag means shown, which covers documents created before M03.
9. **The setup checklist has six steps:** profile, logo, categories, items, theme and publish.
   - "Profile complete" means name, business type, description, a phone or email, and an address or city.
   - The steps M04–M06 own open the nearest existing section for now.
10. **Menu URL base** `AppEnv.menuBaseUrl`: prod `https://menu.eazysuvai.com` (placeholder domain), dev `https://eazy-suvai-dev-menu.web.app`.

## Open items

- **Android and iOS were not run on a device.** Widget tests cover 360, 768 and 1280 px, and the Chrome end-to-end test ran on the emulators. Check by hand on a phone: the wizard, the opening-hours bottom sheet (Cupertino time wheels), the full-screen time zone picker, and copying the link.
- **Slug-change rate limit (your decision).** The FRD sets none. Every change keeps one more `slugs` doc for the life of the account, so an owner could reserve many names by changing repeatedly. A limit such as 5 changes per 30 days is a small change in `changeSlug`.
- **Opening hours order and overlaps** are checked only in the app; the rules check the format. M06 should validate them when snapshotting (noted in the M06 plan).
- **The final public menu domain** is still an open decision (`AppEnv.menuBaseUrl`).
- **The preview shows the contact phone in E.164** (`+914423456789`). M07 should format it for display.

## Change log

- 2026-11-14: Plan created.
- 2026-11-14: Done. Setup wizard, dashboard checklist, profile editor with autosave and live preview, opening hours, currency and time zone (FR-103), menu link with `changeSlug`, `onRestaurantUpdated`, rules whitelist with value checks. Tests: unit, emulator, rules, widget at 3 widths, Chrome end to end. Opening hours are stored as one string per day (rules evaluation limit); `setupCompletedAt` added; `/dev/media` removed.
