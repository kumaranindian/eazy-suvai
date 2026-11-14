# M04 – Menu management (categories and items)

Status: Not started
Started:
Completed:

## Goal

Owners build and maintain their menu: categories and items with prices, images, dietary labels, tags, availability, featured flags and ordering, fast enough to use on a phone during service.

## FRD coverage

FR-015 to FR-033, FR-095 (live availability), FR-097, FR-098, FR-104 (reading labels), BR-004, BR-008, BR-009, BR-016, BR-018, BR-019, §5.3, §5.4, AC-003, AC-004, AC-006, AC-007, AC-027, AC-028, AC-029.

## Depends on

M03.

## Inputs from other modules

- M02 (done 2026-11-14): `ImagePickerField(purpose: ImagePurpose.item | category, targetPath: 'restaurants/$rid/items/$iid', …)` (use `dense: true` in lists, 96 px) and `ResponsiveImage` for thumbnails. The target document **must exist before the upload**: create the item or category first, then enable the picker. `processImage` writes `image` and bumps the item's `updatedAt` and the root's `draftUpdatedAt`. Clients may only set `image` to `null` (field whitelist: `image` changes allowed only to `null`). The default crop is 1:1. Pass `aspectRatio` if the item card uses a different shape.
- M03 (done 2026-11-14): restaurant currency (price input decimals) via `currentRestaurantProvider` (`Restaurant.currency`, `Currencies.of(code).decimals`). Owner app routes: the setup checklist's "categories" and "items" steps open `Routes.menu`; the dashboard reads `counts.categories` / `counts.items`. Draft autosave pattern to reuse: `DraftAutosave` (`features/restaurant/application/draft_autosave.dart`, 1 s debounce, `SaveStatusIndicator` / `SaveBar`). The rules' owner update on the root is a whitelist; `counts` stays Functions-only. Detail pages inside the shell bring their own `AppBar` (the shell hides its app bar on nested routes).
- M10 (later): plan limits. Until M10 is done, `createCategory`/`createItem` read limits from `plans/{planId}` seeded by M00/M01 data.

## Scope

**In:** category CRUD, item CRUD, reorder, move, soft delete and restore, availability toggle, labels and tags, search and filter in the item list.
**Out:** publishing (M06), plan downgrade handling (M10).

## Data and backend

- Collections `restaurants/{rid}/categories` and `/items` (`docs/architecture.md` §4.2).
- Callables: `createCategory`, `createItem` (check plan limits in a transaction, set `sequence` to last), `deleteCategory({cid, mode: 'move'|'deleteAll', targetCid?})` (FR-018), `moveItems({itemIds, targetCid})`, `restoreDeleted({kind, id})` (restores to the draft).
- Direct client updates (whitelisted fields): name, description, image, priceMinor, dietaryLabelId, tagIds, featured, sequence, active, available.
- Triggers `onItemWrite` and `onCategoryWrite`: keep `counts`, update `draftUpdatedAt`, and when `available` changes write `restaurants/{rid}/live/availability` (FR-095).
- Reordering writes new `sequence` values in a batch (gaps of 1000 to limit rewrites).
- Price input: text field that accepts exactly the currency's decimals and converts to `priceMinor` (int).
- Field limits: category name 60, category description 250, item name 80, item description 500.
- Soft delete sets `deletedAt`; purge after 30 days happens in M12.

## Screens and responsive behaviour

| Screen | Compact | Medium | Expanded |
| --- | --- | --- | --- |
| Menu manager | Category list; tap opens that category's items as a new page | Category rail list + items list side by side | Three panes: categories, items, item editor |
| Item editor | Full-screen page with sticky Save | Dialog 640 px | Right-hand pane, no navigation away |
| Quick availability | Swipe or switch on each item row; "Sold out today" filter chip | Same | Same, plus bulk select |
| Reorder | Drag handles (long-press) | Drag handles | Drag handles + keyboard up/down buttons |
| Delete category with items | Bottom sheet with Move / Delete all (type name to confirm) | Dialog | Dialog |
| Recently deleted | List with Restore | Same | Same |

Item rows show image thumbnail, name, price, dietary icon, availability switch. Dietary labels always show icon plus text (FR-023).

## Tasks

- [ ] Models and repositories for categories, items, dietary labels, tags.
- [ ] Seed data for dietary labels (Vegetarian, Non-vegetarian, Vegan, Contains egg) and tags (Spicy, Bestseller, Chef's special, New).
- [ ] Callables: `createCategory`, `createItem`, `deleteCategory`, `moveItems`, `restoreDeleted`, with zod validation and tests.
- [ ] Triggers: counts, `draftUpdatedAt`, availability overlay.
- [ ] Category list with active/inactive toggle and reorder.
- [ ] Item list per category with search, filters (unavailable, featured, by label) and reorder.
- [ ] Item editor with all FR-022 fields and `Money` price input.
- [ ] Availability switch with optimistic UI and rollback on failure.
- [ ] Bulk move and bulk availability (expanded layout).
- [ ] Delete flows (FR-018) and Recently deleted screen (FR-098).
- [ ] Plan limit errors shown with an "Upgrade" call to action (links to M10 screen when ready).
- [ ] Rules tests: cross-tenant denied, whitelist enforced, client create/delete denied.

## Acceptance checks

- [ ] AC-003, AC-004: create, update, reorder, delete categories and items.
- [ ] AC-006: all four dietary classifications selectable and shown with icon and text.
- [ ] AC-007: availability change reaches `live/availability` immediately (public display checked in M07).
- [ ] AC-027: deleting a category with items forces move or typed confirmation.
- [ ] AC-028: deleted items restore within 30 days.
- [ ] AC-029: a KWD restaurant enters 1.250 and it is stored as 1250.
- [ ] Creating past the plan limit fails on the server even if the UI is bypassed.
- [ ] Usable one-handed at 360 px; three panes at 1280 px.

## Tests

Functions for every callable and trigger (including concurrent creates at the limit). Rules tests. Widget tests: price input per currency, item editor validation, list at 3 widths.

## Completion notes

_Fill in when done._

## Open items

## Change log

- 2026-11-14: Plan created.
