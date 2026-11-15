# M12 – Audit, account lifecycle and data retention

Status: Done
Started: 2026-11-15
Completed: 2026-11-15

## Goal

Every sensitive action is traceable; owners can export their menu and ask for deletion; data is purged on the FRD's schedule.

## FRD coverage

FR-090, FR-098 (30-day purge), FR-105, BR-013, BR-014, §7.7, §8 (data isolation), FR-093 (slug held 12 months).

## Depends on

M10, M11.

## Inputs from other modules

- M11 (done 2026-11-15):
  - Admin app sections and shared widgets: `AdminPageBody`, `askReason()`, `runAdminAction()` and `AdminApi` (`lib/widgets/`, `lib/data/`).
  - The restaurant detail page (`features/restaurants/restaurant_detail_page.dart`) has an activity card fed by `adminGetRestaurant` (audit entries by `restaurantId`).
  - `setRestaurantStatus` writes `deactivatedAt` and mirrors `users/{uid}.accountStatus`; deletion must set `status: 'deleted'` itself (never via `setRestaurantStatus`).
  - `stats/platform` counts `restaurantsByStatus.deleted` through the trigger.
  - Audit actions so far: master plan Cross-module notes (M01–M11).

- M00: `writeAudit()` helper (already used by earlier modules).
- M04 (done 2026-11-14): soft-deleted `categories/{cid}` and `items/{iid}` have `deletedAt` (Timestamp; `null` when live). Purge them 30 days after `deletedAt` (`restoreDeleted` already refuses older ones). Items deleted with their category carry `deletedWith: cid`. A hard delete of an item removes its key from `live/availability` (`onItemWrite`) and the triggers recount `counts`, so purging needs no extra bookkeeping.
- M02 (done 2026-11-14): images live under `restaurants/{rid}/images/{id}/` (original plus 3 renditions). Replaced or removed images are not deleted, because published versions may reference them. Purge folders that no draft field or kept version references, and delete the whole `restaurants/{rid}/` prefix when a tenant is purged.
- M11: admin app navigation for the audit viewer.
- M06 (done 2026-11-15): `publishMenu` / `rollbackMenu` already keep only the last 10 versions (and delete each one's `private/source`). An image is still referenced when any kept `versions/{n}.snapshot` (rendition URLs) or `versions/{n}/private/source` (image objects with `path` and `renditions`) uses it; check both before purging. `discardDraft` and draft-replacing rollbacks soft-delete content added since the publish (`deletedAt`, `deletedWith`), so the 30-day purge covers it. Menu export can use `buildSnapshot()` from `functions/src/publishing/snapshot.ts`.
- M03 (done 2026-11-14): a restaurant can own several `slugs` docs (one `current: true`, the others `current: false` with `replacedAt`). On deletion, set `releasedAt` on all of them and only free them after 12 months (FR-093). `onRestaurantUpdated` ignores updates to a restaurant that no longer exists.

## Scope

**In:** audit log viewer, account activity feed, menu export (JSON and CSV), owner deletion request, scheduled purges, TTL policies, slug hold after deletion.
**Out:** legal review of retention periods (business task, listed in Open items).

## Retention schedule (FRD §7.7)

| Data | Rule | Job |
| --- | --- | --- |
| Soft-deleted categories and items | Purge 30 days after `deletedAt` | `purgeDaily` |
| Published versions | Keep last 10 | M06 on publish |
| Deactivated account | Purge all tenant data and images 90 days after `deactivatedAt`; status → `deleted` | `purgeDaily` |
| Raw analytics events | 90 days | Firestore TTL |
| Audit logs | 2 years, personal data removed after account deletion | Firestore TTL + `purgeDaily` |
| Payment records | 8 years (India) | Kept in an archive collection after account deletion |
| Slugs of deleted accounts | Held 12 months, then released | `purgeDaily` |

## Data and backend

- Audit entry shape in `docs/architecture.md` §4.1. Check that every admin callable and publish, slug change, status change, plan change and deletion request writes one.
- `exportMenu()` (owner): returns a signed URL to a JSON file and a CSV file built from the current draft.
- `requestAccountDeletion({confirmText})` (owner): offers export first, sets status `deactivated` and `deactivatedAt`, signs the owner out, sends a confirmation email, audit-logs. Within 90 days an admin can reactivate (M11).
- `purgeDaily` (schedule): runs the rules above in batches with recursive delete; deletes Storage folders; anonymises audit entries (replace emails with hashed IDs).

## Screens and responsive behaviour

| Screen | Where | Layout |
| --- | --- | --- |
| Account settings → Export menu, Delete account | Owner app | Compact: stacked buttons with explanations; expanded: settings page with sections |
| Delete account flow | Owner app | Step 1 export offer, step 2 type restaurant name, step 3 confirmation |
| Audit log | Admin app | Filterable table (actor, action, restaurant, date range) with detail drawer |
| Activity | Admin app, restaurant detail | Timeline |

## Tasks

- [x] Audit coverage check across all callables; add missing calls.
- [x] Audit log viewer with filters and pagination.
- [x] `exportMenu` and download in the owner app (web download, mobile share).
- [x] Delete account flow and `requestAccountDeletion`.
- [x] `purgeDaily` with each retention rule, idempotent and batched.
- [x] TTL policies configured for `analyticsEvents` and `auditLogs`.
- [x] Slug release after 12 months.

## Acceptance checks

- [x] Every action listed in BR-014 appears in the audit log with actor, time and reason where required.
- [x] Export contains all categories and items with prices in minor units and currency.
- [x] A deleted account's public menu returns 410 and its slug cannot be claimed for 12 months.
- [x] Purge jobs remove exactly the data due, verified on the emulator with fake clocks.

## Tests

Functions: export, deletion request, each purge rule with fixed dates. Widget tests for the deletion flow.

## Completion notes

**What was built** (`functions/src/lifecycle/`)

- **`exportMenu({restaurantId})`** (owner, active or suspended):
  - JSON (`schema: 1`; restaurant, categories, items with `priceMinor` + `currency`, label and tag names, `available`, `featured`, `hiddenOverLimit`);
  - CSV (UTF-8 with BOM; `price_minor` plus the exact decimal `price`; RFC 4180 quoting; formula-like cells prefixed with `'`);
  - built from the draft (every live category and item, in display order);
  - returned in the callable result, not via a signed URL. Audit `menu.export`.
- **`requestAccountDeletion({restaurantId, confirmName})`** (owner):
  - the name must match, ignoring case and spacing;
  - sets `status: deactivated`, `deactivatedAt`, `deletionRequestedAt` and `statusReason`, and `users/{uid}.accountStatus`;
  - revokes the owner's tokens and queues a confirmation `mail`;
  - audit `account.requestDeletion`;
  - returns `purgeAfter` (+90 days). An admin can reactivate until then (M11).
- **`purgeDaily`** (schedule `30 2 * * *` Asia/Kolkata; `runPurgeDaily(db, now, deps)` in `purge.ts`). One function per rule, each idempotent and batched (400 writes):

  | Rule (FRD §7.7) | Function |
  | --- | --- |
  | Soft-deleted categories and items, 30 days after `deletedAt` | `purgeSoftDeleted` (collection-group queries; the M04 triggers recount) |
  | Deactivated accounts, 90 days after `deactivatedAt` | `purgeDeactivated` → `purgeTenant`, which: (1) copies payments to `paymentArchive/{rid}_{pid}` (business name, amounts, references; no owner contact; `retainUntil` = paidAt + 8 years); (2) holds every slug of the restaurant (`releasedAt`, `releaseAfter` = +12 months); (3) anonymises its audit entries; (4) runs `recursiveDelete` on `restaurants/{rid}` (categories, items, versions and sources, analytics, payments, history, live) and writes a tombstone `{status: 'deleted', slug, qrCode, deletedAt, purgedAt, counts: 0}`; (5) deletes upgrade requests and queued mail, `users/{uid}` and the Auth user; (6) deletes Storage `restaurants/{rid}/`; audit `account.purge` |
  | Audit logs: personal data removed after deletion | `anonymiseAudit`: owner `actorUid` → `anon:<sha256 prefix>`; `details` drops email, mobile, owner name, display name and phone; `anonymizedAt` |
  | Audit logs 2 years, raw analytics 90 days | Firestore TTL on `auditLogs.expireAt` (written by `writeAudit` since M00) and `analyticsEvents.expireAt` (`firestore.indexes.json`) |
  | Payment records 8 years | `purgeArchivedPayments` (`retainUntil`) |
  | Slugs of deleted accounts held 12 months | `releaseSlugs` deletes `slugs` documents past `releaseAfter`. Until then any `slugs` document blocks registration and `changeSlug` (M01/M03) |
  | Image folders nothing refers to (M02) | `purgeOrphanImages`: 50 restaurants per run, round-robin via `config/purge.imageCursor`. A folder is kept if the draft root, any category or item (including soft-deleted ones that can still be restored), any kept version or any version source refers to it, or if it is under 7 days old |
  | Published versions: last 10 | M06, unchanged |

  It writes a summary audit entry `platform.purge` when anything was removed. Storage helpers (`storagePurgeDeps`: list image folders, delete a prefix) are checked on the Storage emulator by `scripts/check-storage-urls.mjs`.
- **`adminListAuditLogs`** (admin): filters by `actorUid`, `action` (exact), `restaurantId` and a date range, newest first, 50 per page with cursors.
- **Indexes and TTL:** `auditLogs (actorUid, at desc)`, `(action, at desc)`, `restaurants (status, deactivatedAt)`; TTL on `auditLogs.expireAt`; collection-group `deletedAt` indexes on `items` and `categories`.
- **Owner app** (`features/account/`):
  - Settings → **Account** (`/settings/account`): "Download CSV" and "Download JSON" (browser download on web, share sheet on mobile, through M08's `QrShareActions.saveFile`).
  - "Delete my account…" opens **`DeleteAccountPage`** (`/settings/account/delete`), a three-step `Stepper`:
    1. keep a copy (both downloads);
    2. type the restaurant's name;
    3. the consequences, then "Delete my account".

    After the request it signs out; the next sign-in shows M11's deactivated notice.
  - 21 strings.
- **Admin app:** a new **Audit log** section (`/audit`, `?restaurant=` pre-filter):
  - filters for actor, action, restaurant and dates;
  - a table from 600 px and cards below, with pages;
  - a detail drawer (side panel on desktop, bottom sheet on smaller screens) with all fields, the JSON details and the "anonymised" mark.

  The restaurant detail's activity card links to it ("Full audit log"). 12 strings.

**Audit coverage (BR-014, FR-090).** Every sensitive action writes `auditLogs` with actor, role, time, target and, where required, a reason:

| Area | Actions |
| --- | --- |
| Accounts | `restaurant.register`, `account.purgeUnverified`, `account.requestDeletion` (M12), `account.purge` (M12) |
| Admin roles | `admin.grant`, `admin.revoke` (script and `setAdminRole`) |
| Restaurant status | `restaurant.suspend`, `.activate`, `.deactivate`, `.reactivate` (reason required) |
| Slugs | `restaurant.changeSlug` |
| Publishing | `menu.publish`, `menu.rollback`, `menu.discardDraft`, `menu.publishPlanLimits`, `menu.swapHidden`, `menu.export` (M12) |
| Subscriptions | `subscription.requestUpgrade`, `.activate`, `.extend`, `.modify`, `.downgrade` (reason required), `.closeRequest` (reason), `.grace`, `.expire`, `.applyLimits`, `.restoreHidden`, `.ownerDowngrade` |
| Platform data | `plan.create`, `plan.update`, `label.*`, `tag.*`, `theme.*` (create, update, retire), `platform.updateConfig`, `platform.announcement`, `platform.recomputeStats`, `platform.purge` (M12) |

Added in M12: `menu.export`, `account.requestDeletion`, `account.purge` and `platform.purge`.

Not audited, by design: an owner's own menu and profile edits (content, not administration; the draft and the version history keep the trail) and reads.

**Tests** (all passing at completion)

| Suite | Tests | M12 additions |
| --- | --- | --- |
| Functions unit | 324 | `lifecycle/lifecycle.test.ts` (5): export order, minor units and currency, CSV (BOM, decimals, quoting, formula injection), name confirmation, audit anonymisation, referenced image folders (paths and token URLs) |
| Functions emulator | 128 + Storage checks | `lifecycle/lifecycle.emu.test.ts` (9), all on **fixed dates** (`NOW` = 15 Nov 2026): export (owner only, audited); deletion (name check, deactivate, sign-out, mail, audit, 410 at once, no double request); soft-deleted content (31 days purged, 29 kept, idempotent); deactivated tenants (91 days purged, 89 days and active kept; tombstone without personal data; subcollections gone; user and Auth account deleted; Storage prefix; payment archived with `retainUntil` 8 years; slugs held to 15 Nov 2027; audit anonymised; requests and mail deleted; slug and QR answer 410; idempotent); slug release (due released, held still blocks); archived payments (8 years); orphan images (only the unreferenced folder older than 7 days); the combined run with its summary entry; the audit viewer (filters, order, pages, admin only). `check-storage-urls.mjs` also checks the Storage purge helpers |
| Rules | 160 | `admin.test.js`: `paymentArchive` and `config/purge` closed |
| Owner app | 226 | `account_test.dart` (6): export CSV/JSON at 360/768/1280, settings link, delete flow at 360 and 1280 (name check, confirm, sign-out) |
| Admin app | 38 | `audit_test.dart` (4): table, filters and detail drawer at 768 and 1280; read-only cards and paging at 360; restaurant activity link with the pre-filter |

**Decisions that differ from the plan**

1. **The export is returned in the callable result, not via a signed URL.** A 500-item menu is far below the callable limit; it avoids writing personal data to Storage and needs no service-account signing (which the emulator can't do).
2. **A purged restaurant leaves a tombstone** (`status: 'deleted'`, slug and QR code only). The slug and QR code keep answering 410 instead of 404 (FR-099), and `stats/platform` counts deleted accounts.
3. **Payment archive keeps the business name, not the owner's contact,** for tax records. Its own purge runs after 8 years.
4. **Audit anonymisation replaces the owner's uid with a stable pseudonym** (`anon:` + SHA-256 prefix), so entries of the same deleted owner still group together without identifying them.
5. **Orphan image cleanup is budgeted** (50 restaurants a day, round-robin), so the daily job stays well within its timeout as the platform grows.
6. **The CSV prefixes cells starting with `=`, `+`, `-` or `@`** with `'` (spreadsheet formula injection), so negative numbers are never written as text; prices are always positive integers.

## Open items

- **Legal review** of the retention periods against India's DPDP Act 2023 and the GCC launch markets (business task, unchanged).
- **On a real project:**
  - deploy `firestore.indexes.json` and confirm both TTL policies (`analyticsEvents.expireAt`, `auditLogs.expireAt`) show as active in the console;
  - `purgeDaily` needs Cloud Scheduler (Blaze);
  - run a deletion end to end on dev with a test account: request, check the 410, run the purge job by hand with a date 91 days later (or set `deactivatedAt` back), and check that the images are gone from the bucket.
- **Backups:** FRD §7.7 says purged data leaves backups within 35 days. Backups are set up in M13.
- **Owner self-reactivation** within 90 days isn't offered (the notice points to support, M11); FR-099 says "can be reactivated", which support does from the admin app.

## Change log

- 2026-11-14: Plan created.
- 2026-11-15: Done. `exportMenu` (JSON + CSV, audited), `requestAccountDeletion` (name confirmation, deactivate, sign out, email, audit), `purgeDaily` with one idempotent function per §7.7 rule (soft-deleted 30 days, tenant purge after 90 days with tombstone, payment archive 8 years, slug hold 12 months, audit anonymisation, orphan images), TTL on audit logs, `adminListAuditLogs`; owner Account page and 3-step delete flow; admin Audit log section with detail drawer; audit coverage list.
