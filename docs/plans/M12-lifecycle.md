# M12 – Audit, account lifecycle and data retention

Status: Not started
Started:
Completed:

## Goal

Every sensitive action is traceable; owners can export their menu and ask for deletion; data is purged on the FRD's schedule.

## FRD coverage

FR-090, FR-098 (30-day purge), FR-105, BR-013, BR-014, §7.7, §8 (data isolation), FR-093 (slug held 12 months).

## Depends on

M10, M11.

## Inputs from other modules

- M00: `writeAudit()` helper (already used by earlier modules).
- M04 (done 2026-11-14): soft-deleted `categories/{cid}` and `items/{iid}` have `deletedAt` (Timestamp; `null` when live). Purge them 30 days after `deletedAt` (`restoreDeleted` already refuses older ones). Items deleted with their category carry `deletedWith: cid`. A hard delete of an item removes its key from `live/availability` (`onItemWrite`) and the triggers recount `counts`, so purging needs no extra bookkeeping.
- M02 (done 2026-11-14): images live under `restaurants/{rid}/images/{id}/` (original plus 3 renditions). Replaced or removed images are not deleted, because published versions may reference them. Purge folders that no draft field or kept version references, and delete the whole `restaurants/{rid}/` prefix when a tenant is purged.
- M11: admin app navigation for the audit viewer.
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

- [ ] Audit coverage check across all callables; add missing calls.
- [ ] Audit log viewer with filters and pagination.
- [ ] `exportMenu` and download in the owner app (web download, mobile share).
- [ ] Delete account flow and `requestAccountDeletion`.
- [ ] `purgeDaily` with each retention rule, idempotent and batched.
- [ ] TTL policies configured for `analyticsEvents` and `auditLogs`.
- [ ] Slug release after 12 months.

## Acceptance checks

- [ ] Every action listed in BR-014 appears in the audit log with actor, time and reason where required.
- [ ] Export contains all categories and items with prices in minor units and currency.
- [ ] A deleted account's public menu returns 410 and its slug cannot be claimed for 12 months.
- [ ] Purge jobs remove exactly the data due, verified on the emulator with fake clocks.

## Tests

Functions: export, deletion request, each purge rule with fixed dates. Widget tests for the deletion flow.

## Completion notes

_Fill in when done._

## Open items

- Legal review of retention periods against India's DPDP Act 2023 and GCC laws (business task).

## Change log

- 2026-11-14: Plan created.
