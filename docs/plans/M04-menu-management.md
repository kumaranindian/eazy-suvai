# M04 – Menu management (categories and items)

Status: Done
Started: 2026-11-14
Completed: 2026-11-14

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

- [x] Models and repositories for categories, items, dietary labels, tags.
- [x] Seed data for dietary labels (Vegetarian, Non-vegetarian, Vegan, Contains egg) and tags (Spicy, Bestseller, Chef's special, New).
- [x] Callables: `createCategory`, `createItem`, `deleteCategory`, `moveItems`, `restoreDeleted`, with zod validation and tests.
- [x] Triggers: counts, `draftUpdatedAt`, availability overlay.
- [x] Category list with active/inactive toggle and reorder.
- [x] Item list per category with search, filters (unavailable, featured, by label) and reorder.
- [x] Item editor with all FR-022 fields and `Money` price input.
- [x] Availability switch with optimistic UI and rollback on failure.
- [x] Bulk move and bulk availability (expanded layout).
- [x] Delete flows (FR-018) and Recently deleted screen (FR-098).
- [x] Plan limit errors shown with an "Upgrade" call to action (links to M10 screen when ready).
- [x] Rules tests: cross-tenant denied, whitelist enforced, client create/delete denied.

## Acceptance checks

- [x] AC-003, AC-004: create, update, reorder, delete categories and items. (Functions emulator tests, widget tests, Chrome end to end.)
- [x] AC-006: all four dietary classifications selectable and shown with icon and text. (Editor and badge widget tests, light and dark.)
- [x] AC-007: availability change reaches `live/availability` immediately (public display checked in M07). (Emulator trigger test and Chrome end to end: row switch → rules → `onItemWrite` → overlay.)
- [x] AC-027: deleting a category with items forces move or typed confirmation. (Server refuses a wrong or missing name; the dialog's confirm stays disabled until the name matches.)
- [x] AC-028: deleted items restore within 30 days. (Restore in the emulator tests and end to end; refused after 30 days.)
- [x] AC-029: a KWD restaurant enters 1.250 and it is stored as 1250. (Price field and editor widget tests at 3 widths; `createItem` emulator test.)
- [x] Creating past the plan limit fails on the server even if the UI is bypassed. (Six concurrent `createItem` calls at a limit of 3 let exactly 2 through; same for categories.)
- [x] Usable one-handed at 360 px; three panes at 1280 px. (Widget tests at 360/768/1280; Chrome end to end at 1280. Not tried on a phone, see Open items.)

## Tests

Functions for every callable and trigger (including concurrent creates at the limit). Rules tests. Widget tests: price input per currency, item editor validation, list at 3 widths.

## Completion notes

**What was built**

- **Functions (`functions/src/menu/`, exported from `src/index.ts`)**
  - `schemas.ts`: zod schemas (strict, trimmed) and `MENU_LIMITS` (60/250/80/500, price ≤ 999,999,999 minor units, ≤ 10 tags, ≤ 500 ids per bulk call), `SEQUENCE_GAP = 1000`, `RESTORE_DAYS = 30`.
  - `menu-callables.ts`, all `assertOwner` first, every write in one transaction:
    - `createCategory({restaurantId, name, description?, active?})` → `{id, sequence}`.
    - `createItem({restaurantId, categoryId, name, description?, priceMinor, dietaryLabelId, tagIds?, available?, featured?})` → `{id, sequence}`. The category must exist and not be deleted (`not-found` / `category-deleted`); the label and tags must exist and not be retired (`invalid-input`, FR-104).
    - `deleteCategory({restaurantId, categoryId, mode: 'move'|'deleteAll', targetCategoryId?, confirmName?})` → `{moved, deleted}`. With items, `move` appends them to the target in order; `deleteAll` needs `confirmName` equal to the name (case and extra spaces ignored) and soft-deletes the items with `deletedWith: categoryId`.
    - `deleteItems({restaurantId, itemIds})` → `{deleted}` (soft delete; already deleted ones are skipped).
    - `moveItems({restaurantId, itemIds, targetCategoryId})` → `{moved}` (appended in the order given).
    - `restoreDeleted({restaurantId, kind: 'category'|'item', id, targetCategoryId?})` → `{categories, items, categoryId}`. Within 30 days of `deletedAt` (else `not-found` with `reason: 'expired'`). A category returns at the end with the items deleted with it; an item returns at the end of its category or of `targetCategoryId`, and fails with `category-deleted` when its category is gone and no target is given. Restores count against the plan limits.
  - **Limit check:** each create/restore transaction counts the live documents (aggregate `count()` on `deletedAt == null`) and **writes the restaurant root** (`counts.*` and `draftUpdatedAt`). Two concurrent transactions therefore conflict on the root and the retry sees the first one's document. Error `limit-reached` with details `{limit: 'items'|'categories', max, planId}`.
  - `functions/src/lib/plan-limits.ts`: `getPlanLimits(read, planId)` / `planLimitsFrom()`. Reads `plans/{planId}.limits.{maxItems, maxCategories}` (`null` or negative = unlimited) and falls back to the FRD §4.11 values (Free 50/10, Pro 500/unlimited) while the plan documents don't exist.
  - `menu-triggers.ts` (`onItemWrite`, `onCategoryWrite` on `restaurants/{rid}/{items|categories}/{docId}`):
    - **counts:** recounted (not incremented) when a document starts or stops counting, so a retried event can't drift;
    - **`draftUpdatedAt`:** set when a field other than `available`/`updatedAt` changed, unless the root already records a later change (one bump per reorder batch);
    - **`live/availability`:** `{items: {iid: bool}, updatedAt}`, written from a transactional re-read of the item so out-of-order events still leave the latest value; a removed item's key is deleted.
  - `seed-data.ts` + `scripts/seed-platform.mjs`: `dietaryLabels/{vegetarian, non-vegetarian, vegan, contains-egg}` and `itemTags/{spicy, bestseller, chefs-special, new}` with `name`, `icon` (key), `color`, `sort`, `retired`. Creates missing documents only, unless `--overwrite`.
  - New error code `category-deleted` (functions, Dart `AppErrorCode`, `core_en.arb`).
- **Rules (`firestore.rules`)**
  - `categories/{cid}` and `items/{iid}`: read by the owner (active restaurant) and TOTP admins. Owners update only:
    - categories: `name, description, image, sequence, active, updatedAt`;
    - items: `name, description, image, priceMinor, dietaryLabelId, tagIds, featured, sequence, available, updatedAt`.
  - Every update must set `updatedAt == request.time`, and soft-deleted documents can't be edited.
  - Value checks: name lengths, description lengths, `image` only to `null`, `priceMinor` int 0–999,999,999, `dietaryLabelId` must `exists()` in `dietaryLabels`, `tagIds` a list of ≤ 10, `sequence` a non-negative int, booleans.
  - Create and delete are denied (callables only).
  - `dietaryLabels` and `itemTags`: readable by verified owners and TOTP admins; no client writes.
  - A 40-document reorder/availability batch is tested to fit the rules budget.
- **Core (`packages/core`)**
  - `menu/menu_models.dart`: `MenuCategory`, `MenuItem`, `MenuLabel` (+ `MenuLabelKind`), `MenuLimits`, `MenuFields`, `selectableLabels()` (retired labels only kept for the current item), `parseHexColor`.
  - `menu/sequencing.dart`: `sequencesAfterMove()` (one write between neighbours; renumbers on the 1000 grid only when there is no room), `renumbered()`, `compareSequenced()`.
  - `menu/dietary_icon.dart`: `MenuLabelIcon` (India veg/non-veg marks drawn as square + dot / triangle; leaf, egg and tag icons; always on a white tile for contrast in both themes) and `MenuLabelBadge` (icon + name).
  - `money/price_field.dart`: `PriceInputFormatter` (digits and at most the currency's decimals; whole digits capped by the maximum), `parsePriceMinor()` (via `Money.parse`, no `double`), `formatPriceInput()`, and the `PriceField` widget. The field pads to every decimal place on blur (KWD `1.25` → `1.250`), with a helper line "KWD prices have 3 decimal places.".
- **Owner app (`lib/features/menu/`)**
  - `data/menu_repository.dart`: `MenuRepository` / `FirestoreMenuRepository`. Callables through `regionalFunctions`; direct updates stamp `updatedAt` with the server time; availability and reorder batches are split into batches of 100.
  - `application/menu_state.dart`:
    - `menuDataProvider` (`MenuData`: live categories and items in display order, deleted ones, lookups);
    - `PendingChangesNotifier` for optimistic availability and reordering (cleared when the write ends, so a failed write rolls back to the stream's value);
    - `dietaryLabelsProvider`, `itemTagsProvider`;
    - selection, editor target, dirty flag, filter and bulk selection providers.
  - Presentation:
    - `menu_page.dart`: `MenuPage` (1, 2 or 3 panes by breakpoint), `ItemEditorDialog`, `ItemEditorPage`, `CategoryItemsPage`, `openItemEditor()`;
    - `category_list.dart`: "All items" entry, active switch, drag handle, More menu with Edit / Move up / Move down / Delete;
    - `item_list.dart`: search, chips (Sold out with count, Featured, one per dietary label), rows (thumbnail, name, price, dietary badge, tags, "Sold out", availability switch, More menu, drag handle), and the bulk bar (select all, mark available, mark sold out, move, delete);
    - `item_editor.dart`: every FR-022 field, explicit Save in a pinned footer, unsaved-changes guard; a new item switches to edit mode so a photo can be added;
    - `category_dialogs.dart`: category editor, FR-018 delete (dialog or bottom sheet with typed name), category picker;
    - `recently_deleted_page.dart`;
    - `menu_actions.dart`: `runMenuAction()` (floating snack bars with Undo; `limit-reached` opens the upgrade prompt), `MenuKeys`.
  - Routes:
    - `/menu`;
    - `/menu/category/:cid` (compact);
    - `/menu/item/new?category=` and `/menu/item/:iid` (root navigator, above the nav bar);
    - `/menu/deleted`;
    - `/settings/plan` (`PlanPage` placeholder for M10).
- **Tests** (all passing at completion)

  | Suite | Tests | M04 additions |
  | --- | --- | --- |
  | Core | 166 | `test/menu/menu_test.dart` (15) |
  | Owner app | 114 | `menu_page_test.dart` (17), `item_editor_test.dart` (11), `shell_test.dart` updated |
  | Admin app | 19 | – |
  | Functions unit | 134 | `menu/menu.test.ts` (15) |
  | Functions emulator | 66 | `menu/menu.emu.test.ts` (19, incl. concurrent creates and triggers through the Functions emulator) |
  | Rules | 124 | `menu.test.js` (16); `baseline.test.js` opens the new paths |
  | End to end (Chrome) | 4 of 4 | `integration_test/menu_flow_test.dart` (in `tool/integration.sh`) |

**Decisions that differ from the plan**

1. **New callable `deleteItems`.** The plan lists no way to delete an item, and `deletedAt` is not client-writable. A callable keeps `counts` exact in the same transaction and allows bulk delete.
2. **`deletedWith` on items.** Items deleted together with their category carry its id, so restoring the category brings them back (FR-098). Items deleted on their own stay in Recently deleted.
3. **Counts are written by the callables and recounted by the triggers.** The plan has the triggers keep `counts`, but a trigger-maintained count can't serve the limit check (it lags the write). The callables count inside their transaction and write the root (which also serialises concurrent creates); the triggers recount only to catch writes outside the callables.
4. **An availability-only change does not bump `draftUpdatedAt`.** It goes live without a publish (BR-018), so it shouldn't mark the draft as having unpublished changes.
5. **Plan limits fall back to the FRD values** when `plans/{planId}` doesn't exist (it doesn't yet, see the M01 note), instead of failing or allowing everything.
6. **Item editor saves explicitly** (Save in a pinned footer, as the plan's screen table says) rather than autosaving like the M03 profile. Category edits also use a dialog with Save.
7. **Keyboard reordering is in each row's More menu** (Move up / Move down) on every layout, not as separate buttons on expanded only. Panes at 1280 px are too narrow for both a switch and two extra buttons per row, and the menu also serves screen-reader and keyboard users on phones.
8. **Bulk select appears on medium and expanded** (any layout wider than a phone), not on expanded only.
9. **An "All items" entry** in the category list shows every item with its category name, for the "Sold out" check during service (FRD §5.4); reordering is off there and whenever a search or filter is active.
10. **Upgrade goes to a placeholder `/settings/plan`** until M10 builds the plans screen.
11. **Tags are not checked for existence in the rules** (only list and size): the rules can't loop over a list. `createItem` checks them; M06 should drop unknown tag ids when publishing.
12. **Category tiles show the drag handle instead of a thumbnail**, so the name has room in the 256 px pane. The category image is set in the category dialog.
13. **Menu snack bars float** (400 px wide on tablets and desktops), so they never cover the editor's Save bar. A fixed snack bar did, and the Chrome end-to-end test caught it.

## Open items

- **Not run on Android or iOS devices.** Check by hand on a phone: one-handed use at 360 px, dragging handles with touch, the delete bottom sheet with the keyboard open, and adding an item photo.
- **Seed the platform labels on real projects:** `node functions/scripts/seed-platform.mjs --project eazy-suvai-dev` (and prod when it exists). Until then the item editor shows "Dietary labels are not available right now".
- **The item editor has no autosave** (decision 6). If you'd rather have autosave like the profile, items could use the `DraftAutosave` pattern; prices would then be saved while still being typed.
- **Swipe to toggle availability** (plan's "Swipe or switch") is not built; the switch on every row covers it.
- **Purge after 30 days** is M12 (`deletedAt`, `deletedWith`).

## Change log

- 2026-11-14: Plan created.
- 2026-11-14: Built and verified. Callables (plus `deleteItems`), triggers, rules, core models/price field/labels, owner app menu manager at 3 widths, seed script, tests and the Chrome end-to-end flow. Status Done.
