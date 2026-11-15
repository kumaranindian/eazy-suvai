# M06 – Preview, publishing and versions

Status: Done
Started: 2026-11-15
Completed: 2026-11-15

## Goal

Owners preview the draft exactly as customers will see it, publish it as an immutable version in one step, roll back to an earlier version, or discard unpublished changes.

## FRD coverage

FR-012, FR-044, FR-061 to FR-066, FR-095, FR-096, BR-003, BR-007, BR-008, §7.4 (no partial updates), AC-013, AC-021 (publish part), AC-022.

## Depends on

M04, M05.

## Inputs from other modules

- M03 (done 2026-11-14): `pricesNeedReview` is set by `onRestaurantUpdated` when `currency` changes while `publishedVersion != null`; `publishMenu` must ask the owner to confirm prices and clear it (Functions only; owners cannot write it). Snapshot these draft profile fields from `restaurants/{rid}`: `name`, `businessType`, `description`, `logo`, `cover`, `contact {phone, email, address, city, postalCode, website, social{instagram, facebook, x, youtube, googleMaps}}` (empty values are absent), `openingHours` (`{mon: "07:00-11:00,18:00-23:30", …, sun: ""}`, see architecture §4.2), `visibility {phone, email, address, hours, social}` (missing = shown), `currency`, `timezone`. Validate opening hours server-side when snapshotting (the rules check the format, not order or overlaps). Profile edits stamp `draftUpdatedAt` (server time); use it for "unpublished changes". The dashboard's status card shows "Draft" / "Live · version n" from `publishedVersion`.
- M04 (done 2026-11-14): snapshot `categories` where `deletedAt == null && active`, and `items` where `deletedAt == null && !hiddenOverLimit` whose category is in the snapshot, ordered by `sequence` then id. Item fields: `categoryId, name, description, image (ready only), priceMinor, dietaryLabelId, tagIds, available, featured, sequence`. Resolve labels and tags from `dietaryLabels` / `itemTags`, and drop unknown or retired-and-deleted tag ids (the rules can't check tags). BR-003 "empty menu": no active category with a live item. Plan-limit check on publish: `getPlanLimits()` in `functions/src/lib/plan-limits.ts`. `draftUpdatedAt` is bumped by every content change except availability-only ones (those go live through `live/availability`, so they aren't unpublished changes). Restored content comes back to the draft only (FR-098).
- M05 (done 2026-11-14): snapshot `theme` as `{themeId, tokens, settings}`: the chosen `themes/{themeId}.tokens` copied at publish time (so later admin edits to a theme do not change a published menu) plus `restaurants/{rid}.themeSettings` (overrides; only the keys `primary, secondary, background, font, layout, cardLayout, mode`). `themeId` may be null (no theme chosen): snapshot `DEFAULT_TOKENS`. Use `parseThemeTokens` / `parseThemeSettings` from `functions/src/theme` when snapshotting. The draft preview renders the same way with the live draft fields.
- M07 (built next) renders snapshots; the preview in this module calls the same renderer with `draft=true`.
- M02 (done 2026-11-14): image objects (architecture §4.4) hold rendition **Storage paths**, not URLs. Snapshot only `status == 'ready'` images. Old image files are never deleted on replace or remove, so snapshots stay valid. Purging unreferenced images is for M12.

## Scope

**In:** publish validation, snapshot builder, change summary, publish confirmation, version history, rollback, discard draft, "unpublished changes" indicator, draft preview.
**Out:** the public page itself (M07).

## Data and backend

- `publishMenu` callable:
  1. Assert owner, active account, verified email.
  2. Validate: at least one active category with at least one non-deleted item (BR-003); required fields present; plan limits not exceeded; if `pricesNeedReview` is true, the call must include `pricesReviewed: true` (the publish dialog shows a checkbox for it), and a successful publish clears the flag. Return every problem as a list with codes and item/category IDs (FR-066).
  3. Build the snapshot: public profile fields (respecting visibility), theme tokens after contrast fix, active categories in sequence order, non-deleted and not `hiddenOverLimit` items in sequence order, image rendition URLs, currency and locale.
  4. In one transaction: write `versions/{n+1}`, set `publishedVersion = n+1`, reset `live/availability` from the snapshot.
  5. Delete versions older than the last 10. Write an audit entry.
- A dry-run mode (`dryRun: true`) returns validation results and the change summary without publishing (FR-065).
- Change summary: compare the draft with the current snapshot by ID: categories and items added, changed (any public field) and removed.
- `rollbackMenu({n})`: copies version n as a new version, then (after the user confirms) rewrites the draft collections from it.
- `discardDraft()`: rewrites the draft from the current version.
- Draft preview: an authenticated HTTPS endpoint `previewMenu` (or the M07 renderer with an owner ID token) renders the draft with `noindex`; the app shows it in an in-app web view (mobile) or a new tab / iframe (web).

## Screens and responsive behaviour

| Screen | Compact | Expanded |
| --- | --- | --- |
| Publish bar | A persistent bar above the bottom navigation: "Unpublished changes · Preview · Publish" | Same bar at the top of the content area |
| Publish dialog | Bottom sheet: change summary, problems list with "Fix" links | Dialog 560 px |
| Preview | Full-screen web view with a phone/desktop toggle hidden | Side-by-side phone (390 px) and desktop frames |
| Version history | List: version, date, who, summary; "Restore" action | Table |

## Tasks

- [x] Snapshot builder (shared, pure function, unit-tested) in functions.
- [x] Validation with stable error codes mapped to `.arb` messages.
- [x] `publishMenu` with dry run, transaction and version pruning.
- [x] `rollbackMenu`, `discardDraft`.
- [x] "Unpublished changes" detection (`draftUpdatedAt` > current `publishedAt`).
- [x] Publish bar, publish dialog, preview screen, version history screen.
- [x] Email-unverified and suspended states blocked in the UI and on the server.

## Acceptance checks

- [x] AC-013: preview, publish with change summary, roll back.
- [x] AC-021: an empty menu is blocked with clear reasons.
- [x] AC-022: during a publish, readers get either the old or the new version, never a mix (test by reading during the transaction).
- [x] Availability toggles after publishing do not need a republish.
- [x] Only the last 10 versions remain.

## Tests

Functions: snapshot builder (visibility, inactive categories, hidden items, sequence), validation cases, publish transaction, rollback, pruning. Widget tests for the publish dialog at 3 widths.

## Completion notes

**What was built**

- **Functions (`functions/src/publishing/`, exported from `src/index.ts`)**
  - `snapshot.ts` (pure, no Firestore):
    - `buildSnapshot(input)`: builds the public snapshot.
      - Profile fields respect `visibility`. Empty values are dropped. `website` and `social.*` belong to the "social" group; `address`, `city` and `postalCode` to "address".
      - Theme: the theme's tokens are copied at publish time, plus the overrides and the contrast-fixed `resolved` colours from M05's `resolveTheme`.
      - Content: active, non-deleted categories, and non-deleted items that are not `hiddenOverLimit` and sit in a public category. Ordered by category order, then `sequence`, then id.
      - Labels: unknown tag ids are dropped; retired labels and tags stay (FR-104).
      - Images: only `ready` ones whose three renditions resolved to URLs.
      - Also `currency`, `locale` (`en-{country}`) and `timezone`.
    - `diffSnapshots(before, after)`: the change summary by id (FR-065). Categories and items added, changed (any public field, position included; availability ignored) and removed, plus `profileChanged` and `themeChanged`.
    - `validateDraft(input, snapshot, ctx)`: every problem, in a stable order, with a stable code (see "Problem codes" below).
    - `validateHoursDay()`: a port of core's `OpeningHours.validateDay`. M03 left order and overlap checks to M06.
    - `buildDraftSource(input)`: the full draft (inactive categories and hidden items included, without `available`), used by discard and rollback.
  - `draft-reader.ts`:
    - `loadDraft(db, rid, tx?)` reads the root, every category and item, labels, tags, the theme, the plan limits and the current version, inside the transaction when given one.
    - `storageUrlResolver` builds token download URLs from each rendition's `firebaseStorageDownloadTokens` metadata, 16 at a time; `downloadUrl()` is the URL format.
    - `imageUrlsFor()` reuses the previous version's URL cache, so an unchanged image costs no Storage call.
  - `publish.ts`:
    - `publishMenu({restaurantId, dryRun?, pricesReviewed?})`:
      - Dry run: returns `{ok, problems, summary, currentVersion, pricesNeedReview}` and writes nothing.
      - Real run: re-reads and re-validates inside one transaction and fails with `publish-blocked` (`details.problems`) if anything blocks.
      - Image URLs are resolved before the transaction.
    - The transaction (`writeVersion`):
      - creates `versions/{n+1}` and `versions/{n+1}/private/source`;
      - sets on the root `publishedVersion`, `publishedAt`, `publishedDraftAt`, `publishedCurrency`, `pricesNeedReview: false` and `versionHistory`;
      - resets `live/availability` from the snapshot;
      - deletes versions `n ≤ new − 10` and their sources;
      - writes the audit entry `menu.publish`.
    - `rollbackMenu({restaurantId, version, replaceDraft = true})`:
      - Publishes version `version`'s snapshot again as a new version (`kind: 'rollback'`, `rollbackOf`), with today's availability for items that still exist.
      - Checks today's plan limits.
      - With `replaceDraft`, rewrites the draft from that version's source in the same transaction. Without it, sets `publishedDraftAt: null`, so the bar shows. Audit `menu.rollback`.
    - `discardDraft({restaurantId})`: rewrites the draft from the live version's source; no new version. Audit `menu.discardDraft`.
    - The draft rewrite only writes documents that differ. Content added since the publish is soft-deleted, so it appears in Recently deleted. Items deleted together with their category get `deletedWith`. `available` is kept.
    - `previewMenu({restaurantId})` returns `{html, problems}`: the draft rendered with `draft: true` (banner and `noindex`). The owner's problems come with it, so the preview can say what blocks publishing.
  - New error code `publish-blocked` (functions `errors.ts`, Dart `AppErrorCode`, `core_en.arb`).
- **Public renderer, first version (`functions/src/public/`)**
  - `render-menu.ts` `renderMenuPage(snapshot, {draft, availability, branding, headExtra, bodyExtra})`:
    - Content: a header (cover, logo, name, description, visible contact, hours in a `<details>`), sticky category pills, a Featured section, then categories with items.
    - Items: price via `formatPrice`, the veg / non-veg marks drawn inline, tags, a featured badge, and a "Sold out" badge (never opacity) with `aria-disabled`.
    - Styling: list or grid and the three card layouts from the theme, `--es-*` CSS variables from `cssVariables()`, and the Google Font with `display=swap`.
    - Accessibility: skip link and `lang`.
  - `format.ts`: `formatPrice(minor, currency, locale)` builds a decimal string and gives it to `Intl.NumberFormat` (no float; KWD gets 3 decimals) and `formatDayHours()`.
  - `html.ts`: `esc`, `safeUrl` (https only) and `anchorId`.
  - Checked by eye in headless Chrome at 360 px (light theme) and 1280 px (dark theme).
- **Changes to M03 and M04 functions**
  - `onItemWrite` / `onCategoryWrite` (M04) now stamp `draftUpdatedAt` with the changed document's own `updatedAt` instead of the server time. An edit committed before a publish whose trigger runs after it would otherwise show as unpublished. Discard and rollback write every document with the same server time as `draftUpdatedAt` and `publishedDraftAt`, so their own triggers change nothing.
  - `onRestaurantUpdated` (M03) no longer sets `pricesNeedReview` when the currency goes back to `publishedCurrency` (for example after a discard).
- **Rules:** `restaurants/{rid}/versions/{n}` can be read (get and list) by the owner of an active restaurant and by TOTP admins; nobody writes it. `versions/{n}/private/source` and `live/availability` stay closed (Functions and the Admin SDK only). The new root fields are outside the owner whitelist.
- **Core**
  - `Restaurant.publishedAt`, `publishedDraftAt`, `versionHistory` and `hasUnpublishedChanges`.
  - `MenuVersionEntry` (`src/publishing/menu_version.dart`).
  - `ResponsiveScaffold(banner:)`: the strip goes above the bottom navigation on compact windows and at the top of the content on wider ones.
- **Owner app (`lib/features/publishing/`)**
  - `domain/publish_models.dart`: `PublishProblemCode` (wire codes), `PublishProblem`, `ChangeSummary`, `PublishCheck`, `PublishOutcome` and `blockedProblemsOf()`.
  - `data/publishing_repository.dart`: `PublishingRepository`, with the callables through `regionalFunctions`, and `menuPreviewProvider`.
  - Presentation:
    - `PublishBar`: "Not published yet" or "Unpublished changes", with Preview and Publish. It sits in `OwnerShell`'s banner slot and is hidden when the draft matches the live menu or the account isn't active.
    - `showPublishDialog()`: a bottom sheet on compact, a 560 px dialog otherwise. It runs a dry run and shows the problems with Fix links, the change summary with up to 5 names per line, the prices checkbox when `pricesNeedReview`, and the next version number. A `publish-blocked` response replaces the summary with the new problems.
    - `PreviewPage`: on compact the page fills the screen; on medium one frame with a phone / desktop toggle; on expanded a 390 px phone frame beside a 1280×800 desktop frame scaled to fit. A notice shows the number of blocking problems, and Publish is in the app bar (bottom button on compact).
    - `MenuHtmlView`: an `<iframe srcdoc>` with a sandbox and no scripts on web (`package:web`); a `webview_flutter` view with JavaScript off on Android and iOS. Tests override `menuHtmlViewBuilderProvider`.
    - `VersionHistoryPage`: a list on compact, a table otherwise. Each entry shows the version, date in the restaurant's time zone, who published, and the changes ("Restored from version n", counts, profile and theme). It has Restore (confirmation with "Also replace my draft", ticked by default) and "Discard changes" when the draft differs.
    - `publish_problems.dart`: the problem messages and Fix routes, and `PublishKeys`.
  - Routes: `/preview` (full screen, above the shell) and `/settings/versions`. The dashboard's checklist step "Publish" opens the preview; the status card gains Preview and Version history buttons; Settings gains "Version history · Live · version n".
  - Dependencies: `webview_flutter` 4.13 and `web` 1.1. The Android main manifest now declares `INTERNET` (the web view loads fonts and images).
  - 71 strings in `app_en.arb` (plus `errorPublishBlocked` in core).

**Problem codes (FR-066)**

| Code | Fields | Fix link |
| --- | --- | --- |
| `email-not-verified` | – | `/verify-email` |
| `menu-empty` (BR-003) | – | `/menu` |
| `missing-field` / `invalid-field` | `target` (`restaurant` / `category` / `item`), `id`, `field`, `name`; hours: `field: 'openingHours.mon'`, `details.issue` | profile, regional, hours, category (selected in the menu manager on wide layouts) or the item editor |
| `limit-exceeded` (BR-011) | `details {limit: 'items'\|'categories', max, count, planId}` | `/menu` |
| `prices-need-review` (FR-103) | – | the checkbox in the dialog (`pricesReviewed: true`) |
| `snapshot-too-large` | `details {bytes, max}` (900 KB) | `/menu` |

**Firestore paths and fields**

- `restaurants/{rid}/versions/{n}` = `{n, kind: 'publish'|'rollback', rollbackOf, publishedAt, publishedBy, summary {added, changed, removed, profileChanged, themeChanged}, snapshot}`. The snapshot shape is in the master plan's Cross-module notes.
- `restaurants/{rid}/versions/{n}/private/source` = `{restaurant, categories[], items[], imageUrls}` (Functions only).
- New root fields, written by Functions only:
  - `publishedAt`;
  - `publishedDraftAt`, the draft time the live version matches (`null` after a rollback that kept the draft);
  - `publishedCurrency`;
  - `versionHistory`, newest first, at most 10: `[{n, kind, rollbackOf, publishedAt, publishedBy, summary}]`.

**Tests** (all passing at completion)

| Suite | Tests | M06 additions |
| --- | --- | --- |
| Core | 222 | `publishing/menu_version_test.dart` (5), banner tests in `responsive_scaffold_test.dart` (4) |
| Owner app | 163 | `publishing_test.dart` (29): bar, dialog, preview and history at 360/768/1280, Fix links, price review, `publish-blocked`, discard, entry points |
| Admin app | 19 | – |
| Functions unit | 224 | `publishing/snapshot.test.ts` (35): builder (visibility, inactive categories, hidden items, order, labels, images, theme), diff, validation, hours, size, source, price formatting, renderer escaping |
| Functions emulator | 84 + Storage check | `publishing/publish.emu.test.ts` (18): dry run, publish transaction, blocked publish, limits, price review, summary, pruning to 10, reads during a publish (AC-022), availability without a publish, draft stamps, rollback (with and without replacing the draft), discard, preview. `scripts/check-storage-urls.mjs` resolves a token URL on the Storage emulator and loads it without signing in (runs after Jest in `npm run test:emulators`) |
| Rules | 149 | `publishing.test.js` (5) and `baseline.test.js` updated |
| End to end (Chrome) | 6 of 6 | `integration_test/publish_flow_test.dart` (in `tool/integration.sh`): empty menu blocked with a Fix link, preview in iframes, publish, availability without a bar, edit, republish, restore version 1 as 3, discard |

**Decisions that differ from the plan**

1. **"Unpublished changes" compares `draftUpdatedAt` with a new `publishedDraftAt`, not with `publishedAt`.** After a discard, or a rollback that replaced the draft, the draft matches the live menu even though no publish happened at that moment. After a rollback that kept the draft, it never matches. The M04 triggers now stamp the edit's own time, so an edit made before a publish never shows up after it.
2. **The draft source is a separate, private document** (`versions/{n}/private/source`). The public snapshot leaves out inactive categories, hidden items and raw image objects, so it can't rebuild the draft. Keeping the source apart keeps the document M07 reads small and free of draft data (FR-045).
3. **`versionHistory` on the root** feeds the history screen, so it doesn't download 10 snapshots (each up to about 1 MB). `versions/{n}` remains the source of truth, and both are written in the same transaction.
4. **The preview is a callable (`previewMenu`) returning HTML**, not an HTTPS endpoint with an ID token. The callable handles auth and CORS, the HTML is never cached or reachable by URL, and the app shows it with `srcdoc` (web) or `loadHtmlString` (mobile).
5. **The renderer is in `functions/src/public/` already,** since the preview must use "the same renderer" and M07 isn't built yet. M07 extends it (SEO, JSON-LD, scripts, account states) instead of writing another.
6. **Plan limits at publish don't count `hiddenOverLimit` items** (the create callables do). After a downgrade FR-101 hides the excess and the menu must stay publishable.
7. **Rollback publishes immediately; replacing the draft is a checkbox in the same confirmation** (ticked by default), not a second dialog after the publish. FR-096's "the draft is replaced after confirmation" is that checkbox.
8. **Rollback uses today's availability** for items that still exist, because availability is live (FR-095).
9. **An unverified email is a problem in the dry run, not an error** (AC-021 "clear reasons"). Suspended and other inactive accounts still fail with `account-inactive`, and the bar is hidden for them.
10. **Publishing with no changes is allowed;** the dialog says "Nothing has changed since version n".
11. **Empty categories may be in the snapshot** (the plan lists active categories); the renderer skips categories without items.
12. **Download URLs are built from the rendition metadata token** rather than with `getDownloadURL()`. On the emulator, `getDownloadURL()` goes through the Firebase Storage endpoint, which applies storage.rules (no anonymous reads); it also cannot run under Jest. The URL format is the same one `getDownloadURL()` produces.

## Open items

- **The mobile preview (`webview_flutter`) was not run on Android or iOS.** The web iframe ran in Chrome (end to end), and widget tests replace the view. Check by hand on a phone: the preview loads, fonts and images show, links (call, map) open, and back returns to the app. Also check the publish bottom sheet with long problem lists at 360 px.
- **Deploy to `eazy-suvai-dev`:** `publishMenu`, `rollbackMenu`, `discardDraft` and `previewMenu` are new, and `onItemWrite`, `onCategoryWrite` and `onRestaurantUpdated` changed. Not deployed (deploys are yours to run): `firebase deploy --only functions,firestore:rules --project eazy-suvai-dev`.
- **Images with a real bucket:** publishing with images was checked against the Storage emulator, not a real bucket. After deploying, publish a menu with a logo and an item photo and open a rendition URL from `versions/{n}.snapshot` in a private window.
- **Very large discards and rollbacks:** the draft rewrite writes only documents that differ, all in one transaction. Firestore limits a transaction to 500 writes, so replacing a draft in which more than about 490 categories and items differ (possible only on Pro) would fail. If that matters, move it to batched writes with a marker field.
- **Customer-facing text in the renderer is English and lives in `MENU_TEXT`** (`render-menu.ts`). M07 decides how to localize it (FRD §6.3).
- **M07 still owns** SEO tags, JSON-LD, the sitemap, the category and lightbox scripts, account-state pages and the Lighthouse budget; the renderer has `headExtra` and `bodyExtra` hooks for them.

## Change log

- 2026-11-14: Plan created.
- 2026-11-15: Done. Pure snapshot builder, change summary and validation (stable problem codes); `publishMenu` (dry run; one transaction: version, pointer, availability reset, pruning to 10, audit), `rollbackMenu`, `discardDraft`, `previewMenu` with the first public renderer (`functions/src/public/`); rules for `versions`; publish bar, publish dialog, preview (iframe on web, web view on mobile) and version history at 3 widths; Chrome end to end. Unpublished changes use a new `publishedDraftAt`, the full draft is kept in `versions/{n}/private/source`, and the M04 triggers stamp the edit time.
