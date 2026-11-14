# M06 – Preview, publishing and versions

Status: Not started
Started:
Completed:

## Goal

Owners preview the draft exactly as customers will see it, publish it as an immutable version in one step, roll back to an earlier version, or discard unpublished changes.

## FRD coverage

FR-012, FR-044, FR-061 to FR-066, FR-095, FR-096, BR-003, BR-007, BR-008, §7.4 (no partial updates), AC-013, AC-021 (publish part), AC-022.

## Depends on

M04, M05.

## Inputs from other modules

- M03 (done 2026-11-14): `pricesNeedReview` is set by `onRestaurantUpdated` when `currency` changes while `publishedVersion != null`; `publishMenu` must ask the owner to confirm prices and clear it (Functions only; owners cannot write it). Snapshot these draft profile fields from `restaurants/{rid}`: `name`, `businessType`, `description`, `logo`, `cover`, `contact {phone, email, address, city, postalCode, website, social{instagram, facebook, x, youtube, googleMaps}}` (empty values are absent), `openingHours` (`{mon: "07:00-11:00,18:00-23:30", …, sun: ""}`, see architecture §4.2), `visibility {phone, email, address, hours, social}` (missing = shown), `currency`, `timezone`. Validate opening hours server-side when snapshotting (the rules check the format, not order or overlaps). Profile edits stamp `draftUpdatedAt` (server time); use it for "unpublished changes". The dashboard's status card shows "Draft" / "Live · version n" from `publishedVersion`.
- M04 (done 2026-11-14): snapshot `categories` where `deletedAt == null && active`, and `items` where `deletedAt == null && !hiddenOverLimit` whose category is in the snapshot, ordered by `sequence` then id. Item fields: `categoryId, name, description, image (ready only), priceMinor, dietaryLabelId, tagIds, available, featured, sequence`. Resolve labels and tags from `dietaryLabels` / `itemTags`, and drop unknown or retired-and-deleted tag ids (the rules can't check tags). BR-003 "empty menu": no active category with a live item. Plan-limit check on publish: `getPlanLimits()` in `functions/src/lib/plan-limits.ts`. `draftUpdatedAt` is bumped by every content change except availability-only ones (those go live through `live/availability`, so they aren't unpublished changes). Restored content comes back to the draft only (FR-098).
- M05: theme tokens.
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

- [ ] Snapshot builder (shared, pure function, unit-tested) in functions.
- [ ] Validation with stable error codes mapped to `.arb` messages.
- [ ] `publishMenu` with dry run, transaction and version pruning.
- [ ] `rollbackMenu`, `discardDraft`.
- [ ] "Unpublished changes" detection (`draftUpdatedAt` > current `publishedAt`).
- [ ] Publish bar, publish dialog, preview screen, version history screen.
- [ ] Email-unverified and suspended states blocked in the UI and on the server.

## Acceptance checks

- [ ] AC-013: preview, publish with change summary, roll back.
- [ ] AC-021: an empty menu is blocked with clear reasons.
- [ ] AC-022: during a publish, readers get either the old or the new version, never a mix (test by reading during the transaction).
- [ ] Availability toggles after publishing do not need a republish.
- [ ] Only the last 10 versions remain.

## Tests

Functions: snapshot builder (visibility, inactive categories, hidden items, sequence), validation cases, publish transaction, rollback, pruning. Widget tests for the publish dialog at 3 widths.

## Completion notes

_Fill in when done._

## Open items

## Change log

- 2026-11-14: Plan created.
