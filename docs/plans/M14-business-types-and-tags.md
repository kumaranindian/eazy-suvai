# M14 – Business types, capabilities and dynamic tags

Status: In progress
Started: 2026-11-25
Completed: –

## Goal

Make EazySuvai fit every kind of food business (restaurants, cafés, bakeries, juice bars, fast food and stalls, bars/pubs/lounges, hotels/resorts, clubs, canteens, cloud kitchens, caterers). The owner picks a **business type** and answers a few **capability** questions. Tag groups, extra item fields, starter categories and public-menu behaviour come from that choice. They are stored as platform data, so nothing is hard-coded per type in the apps, and a new type needs no app release.

View-only menus. No ordering, cart or payments.

## How this maps onto the existing code (read first)

The request was written for a generic Flutter + Firebase app. Five points differ in this repo, and the plan follows the repo:

| Request says | This repo | What the plan does |
| --- | --- | --- |
| Plan file in `docs/modules/` | AGENTS.md: module plans live in `docs/plans/Mxx-*.md` with a row in `00-master-plan.md` | This file is `docs/plans/M14-…`. A master-plan row is added when work starts |
| "Admin app" = the owner's app; "Platform admin" = AVAIL404 | `apps/owner_app` (owners) and `apps/admin_app` (platform admins) | "Owner app" and "admin app" below mean those two apps |
| Public menu in Flutter | The public menu is server-rendered HTML from `renderMenu` (`functions/src/public/`), built from the **published snapshot** (`versions/{n}`), not from live data (FR-012, architecture §3) | `menuConfig` is copied into the snapshot at publish time. Changes show after the next publish, like every other draft change |
| New field `businessTypeId` | `restaurants/{rid}.businessType` already exists (enum `BusinessType` in core, `BUSINESS_TYPES` in functions, `validBusinessType()` in rules, the snapshot, SEO JSON-LD) | Keep the field name `businessType`. Its value becomes an id in `businessTypes/{id}` instead of a fixed enum. No second field |
| Diet, spice and other tags as one model | `items.dietaryLabelId` (exactly one, FR-023) from `dietaryLabels/{id}`, plus `items.tagIds[]` from `itemTags/{id}` | See decision D1. Recommended: keep `dietaryLabelId` as the storage for the required `diet` group, and keep the existing tag ids, so existing items are not rewritten |

### Requirement changes this module needs approved (AGENTS.md: "do not silently change a requirement")

The FRD puts several of these in **Phase 2**:

- Restaurant-defined tags (FR-033, FRD §3 "Phase 2": restaurant-defined dietary labels and tags).
- Allergens (FRD roadmap, Phase 2 "Advanced menus").
- Item variants (Phase 2). Drink serving sizes with a price per size are a small form of variants.
- Multiple branches (Phase 2). This module only stores a `multipleOutlets` flag, which is fine.

Building them now needs your OK. The FRD then gets a v1.2 change note (new FR ids continuing from the last one) in the same piece of work. If you prefer, custom tags and serving sizes can be cut from this module. Everything else stands on its own.

## FRD coverage

FR-002, FR-011 (business type), FR-023, FR-033, FR-104 (labels and tags), FR-038 (public menu shows tags), FR-078 (plan feature flags), BR-011 (server-side checks), BR-019 (money). New FR ids for capabilities, alcohol notice and serving sizes once approved.

## Depends on

M03, M04, M06, M07, M10, M11 (all Done).

## Inputs from other modules

- M01: `completeRegistration` (`functions/src/auth/register.ts`) creates the restaurant with `businessType`; `BUSINESS_TYPES` in `functions/src/auth/countries.ts`.
- M03: setup wizard `apps/owner_app/lib/features/setup/presentation/setup_wizard_page.dart` (profile → images → menu); `validOwnerUpdate()` in `firestore.rules`, which is close to its evaluation budget ("heaviest update" test); `onRestaurantUpdated`.
- M04: `dietaryLabels` / `itemTags` (seed in `functions/src/menu/seed-data.ts`), `createItem` checks label and tag ids, the `validItemUpdate()` rule, `ItemEditor` (dietary `ChoiceChip`s, tag `FilterChip`s), `selectableLabels()`, `MenuLabelBadge`.
- M06: snapshot builder `functions/src/publishing/snapshot.ts` (`SNAPSHOT_SCHEMA = 1`; items carry `dietaryLabel` and `tags` objects), `draft-reader.ts`, problem codes.
- M07: `renderMenuPage()` already draws label pills and dietary/tag filter chips (`render-menu.ts` ~L96–190); `seo.ts` `SCHEMA_TYPE` by business type; sitemap.
- M10: `planFeatures` on the restaurant root, copied from `plans/{id}.limits`; `syncPlanFeatures`.
- M11: admin catalog (`functions/src/admin/catalog.ts`: `upsertLabel`, `adminListCatalog`; `apps/admin_app/lib/features/catalog/catalog_pages.dart`), `writeAudit()`, `runAdminAction()`.
- M12: `exportMenu` (JSON/CSV includes `dietaryLabelId`, `tagIds`).

## Scope

**In:** platform catalogs (business types, capabilities, tag groups, alcohol notices), effective `menuConfig` computed by Functions, the setup wizard's type, features and starter-category steps, a "Business type & features" settings page, a schema-driven item editor, tags, filters, notices and badges on the public menu, admin CRUD and the "recompute" action, seed and migration scripts, tests.

**Out:** ordering, outlets UI (Phase 2), translated tag names (the data model leaves room: see Localisation), item variants beyond drink serving sizes.

## Decisions (approved 2026-11-25: the recommended option of each)

- **D1. Diet storage.** (a) *Recommended:* the `diet` group is stored in `dietaryLabelId`, as today. Other groups go in `tagIds`. FR-023's "exactly one" stays a simple rule check, and publishing, export and the renderer barely change. (b) Move diet into `tagIds` and stop using `dietaryLabelId`. This is more uniform, but every item gets rewritten and the rules must count diet ids inside a list.
- **D2. Tag ids.** (a) *Recommended:* keep the existing ids (`vegetarian`, `non-vegetarian`, `vegan`, `contains-egg`, `spicy`, `bestseller`, `chefs-special`, `new`) and name new ones in the same kebab-case (`jain`, `mild`, `medium`, `extra-spicy`, `chefs-special`, `recommended`, `eggless`, `sugar-free`, `gluten-free`, `order-in-advance`, `hot`, `cold`, `contains-caffeine`, `fresh`, `alcoholic`, `non-alcoholic`, `beer`, `wine`, `spirit`, `cocktail`, `in-room`, `available-24h`, `breakfast-only`, `nuts`, `dairy`, `gluten`, `seafood`). Existing items keep working with no rewrite. (b) Use the snake_case ids from the request (`veg`, `non_veg`, …) and rewrite all items.
- **D3. Business type ids.** (a) *Recommended:* keep the 10 existing ids (`restaurant`, `cafe`, `bakery`, `cloudKitchen`, `sweetShop`, `juiceBar`, `foodTruck`, `bar`, `hotel`, `other`). Show `bar` as "Bar, pub or lounge" and `hotel` as "Hotel or resort". Add `fastFood`, `club`, `canteen`, `caterer`. `foodTruck` stays as its own type with fast-food defaults. `sweetShop` (common in India) and `other` stay, though the request leaves them out. No restaurant documents need rewriting. (b) Use the request's 11 ids and migrate the old values.
- **D4. Where the type is chosen.** (a) *Recommended:* the sign-up form keeps its business type dropdown (FR-002), filled from `businessTypes`. That collection becomes readable without sign-in, because the form runs before sign-in and the catalog is not sensitive. The setup wizard then opens with the type grid pre-selected, so the owner can change it. (b) Remove the type from sign-up and ask only in the wizard. Sign-up gets shorter, but FR-002 has to be reworded.
- **D5. How owners change type, capabilities and groups.** *Recommended:* a callable `updateMenuFeatures`, not direct writes. It validates the input, writes the root fields and recomputes `menuConfig` in one transaction, and writes an audit entry. The item form never sees a stale config, the plan check for custom tags stays server-side (BR-011), and `validOwnerUpdate()` gets no heavier. A trigger also recomputes as a safety net (see Backend).
- **D6. Tag rules for items.** *Recommended:* the rules check that **newly added** tag ids are in `menuConfig.allowedTagIds`. Ids already on an item may stay, so hidden tags survive an edit (AC 5). The rules also check `dietaryLabelId` against `menuConfig.allowedDietIds`, and "at most one" for up to 4 single-select groups that `menuConfig` lists as fixed slots `single0`…`single3`, using set intersection. That costs one extra `get()`. Full validation (group shape, attributes) also runs in `createItem` and in publish validation. Fallback if the rules budget doesn't fit: move `tagIds` / `attributes` edits to a callable `updateItemTags`.
- **D7. Serving sizes and price.** `attributes.servingSizes: [{label, volumeMl?, priceMinor}]` (≤ 6; `priceMinor` int, BR-019). `priceMinor` stays required on the item and the editor sets it to the lowest size price, so sorting, export and old snapshots keep working. The menu shows "from {lowest}" in compact cards and every size in the item detail. `abv` is stored as `abvTenths` (int, 0–1000, so 4.5 % = 45) to avoid floats in rules.
- **D8. Plan gating.** Add `limits.customTags` (bool) and `limits.maxCustomTags` (int) to `plans/*`, and copy them into `planFeatures`. Pro = on, 20 tags; Free = off. Rename them if you want other values.
- **D9. Alcohol region.** Notices are keyed by ISO 3166-2 region (`IN-TN`, `IN-PY`) with a country fallback (`IN`) and a global default. Restaurants get a new optional owner field `region`, chosen in Regional settings from the regions that have notices. Admins enter the minimum ages and texts. The code ships no legal values. The request's examples (TN 21, PY 18) go in the seed as editable placeholders, marked "verify before launch".
- **D10. noindex.** `seo.indexable` on the root: absent means the type or capability default (`servesAlcohol` → false), and the owner can override it. It is copied into the snapshot. Pages with `false` get `noindex` and are left out of `sitemap.xml`.

## Data model

### Platform collections (written by Functions only)

| Path | Fields |
| --- | --- |
| `businessTypes/{id}` | `name`, `icon` (key the apps draw, like labels today), `sort`, `active`, `version` (int, bumped on every edit), `terminology {itemLabel, itemLabelPlural}` (e.g. Dish/Drink/Item), `defaultCapabilities {pureVeg, servesAlcohol, hasRooms, multipleOutlets, bakeryItems}`, `defaultCategories [{key, name}]`, `tagGroupIds []`, `schemaType` (JSON-LD, replaces the `SCHEMA_TYPE` map in `seo.ts`), `updatedAt` |
| `capabilities/{id}` | `question`, `help`, `sort`, `active`, `addTagGroupIds []`, `hideTagGroupIds []`, `hideTagIds []`, `addItemFields []` (`servingSizes`, `abv`), `addNotices []` (`alcohol`), `addBadges []` (`pureVeg`), `addFilters []` (`non-alcoholic`), `addCategories [{key, name}]` (`hasRooms` → In-Room Dining), `seoIndexableDefault?` (bool), `updatedAt` |
| `tagGroups/{id}` | `name`, `sort`, `active`, `selection` (`single` / `multi`), `required` (bool), `exclusive [[tagId, …]]` (mutually exclusive sets inside a multi group, e.g. alcoholic/non-alcoholic), `filterable` (bool), `tags [{id, name, icon, color, sort, retired}]`, `updatedAt` |
| `config/platform.alcoholNotices` | `{ "IN-TN": {minAge: 21, text}, "IN": {…}, "default": {…} }` |

Tag ids are unique across all groups. A seed test and `upsertTagGroup` both check this, because items store bare ids.

**Legacy:** `dietaryLabels` and `itemTags` stay in place and stop being read once `tagGroups` exists. The `diet` group replaces `dietaryLabels`, and the other groups replace `itemTags`. Deleting the legacy collections is a separate step, done only after you approve it.

### Tenant fields

`restaurants/{rid}` (written by `updateMenuFeatures` and `completeRegistration`):

- `businessType`: an id in `businessTypes` (existing field).
- `capabilities {pureVeg, servesAlcohol, hasRooms, multipleOutlets, bakeryItems}`: booleans. Absent means "use the type default" (this also covers existing restaurants).
- `disabledTagGroupIds []`: only optional groups. `diet` can't be disabled.
- `customTags [{id, name, groupId, icon, color}]`: ids prefixed `c-` so they never collide with platform ids. Plan-gated.
- `region?`: ISO 3166-2 (D9). `seo {indexable?}` (D10). Both are added to the owner whitelist in rules with one regex.
- `setupProgress {type, features, categories}`: timestamps that make the wizard resumable.

`restaurants/{rid}/settings/menuConfig` (computed, Functions only, owner read):

```jsonc
{
  "configVersion": 7,                 // +1 on every recompute
  "computedAt": "<Timestamp>",
  "inputs": { "businessType": "bar", "typeVersion": 3, "capabilities": {…}, "disabledTagGroupIds": [], "planCustomTags": true },
  "terminology": { "itemLabel": "Drink", "itemLabelPlural": "Drinks" },
  "tagGroups": [ { "id": "diet", "name": "Diet", "selection": "single", "required": true, "exclusive": [], "filterable": true,
                   "tags": [ { "id": "vegetarian", "name": "Vegetarian", "icon": "veg", "color": "#2E7D32" } ] } ],
  "allowedTagIds": ["spicy", "…"],    // every non-diet tag, for the rules
  "allowedDietIds": ["vegetarian", "vegan"],
  "single0": ["mild", "medium", "spicy", "extra-spicy"], "single1": ["alcoholic", "non-alcoholic"], "single2": [], "single3": [],
  "itemFields": ["servingSizes", "abv"],
  "notices": ["alcohol"],
  "badges": ["pureVeg"],
  "filters": [ { "id": "vegetarian", "kind": "diet" }, { "id": "non-alcoholic", "kind": "tag" } ],
  "seoIndexableDefault": false
}
```

### Items

- `dietaryLabelId` (D1) and `tagIds []` (existing fields).
- New `attributes {servingSizes?: [{label, volumeMl?, priceMinor}], abvTenths?}`, added to the item whitelist in rules.

### Snapshot (`SNAPSHOT_SCHEMA` 1 → 2)

Adds `menu {terminology, filters, notices, badges, alcoholNotice?: {minAge, text}, indexable}`. Items gain `servingSizes?` and `abvTenths?`. Tags and diet labels that `menuConfig` no longer allows are left out of the snapshot (hidden, never deleted). The renderer must keep rendering **schema 1**, because `rollbackMenu` can put an old version back live.

## Backend (functions/src/menu-config/, new)

1. `computeMenuConfig(inputs)`: a **pure** function (`compute.ts`) that takes the type, capability docs, tag groups, restaurant fields and plan flags and returns the `menuConfig` document. The order is: groups from the type, plus groups added by capabilities, minus groups hidden by capabilities, minus groups the owner disabled (only optional ones); then tags hidden by capabilities are removed (`pureVeg` hides `non-vegetarian`, `contains-egg` and any meat tags); then the owner's custom tags are added if the plan allows them; then single-select slots, filters, notices, badges and terminology are derived. Unit tests cover every rule.
2. `loadMenuConfigInputs(read, rid)` + `writeMenuConfig(tx, rid)`: shared by every caller.
3. Callables:
   - `updateMenuFeatures({restaurantId, businessType?, capabilities?, disabledTagGroupIds?, dryRun?})`. The dry run returns what would be hidden: counts of items with tags or fields that would be hidden, for the warning dialog. Audit action `restaurant.updateFeatures`.
   - `upsertCustomTag` / `retireCustomTag`. Plan-checked (`limit-reached` with `{limit: 'customTags'}`), audited.
   - `createStarterCategories({restaurantId, keys[]})`. Uses the same counted transaction as `createCategory` and keeps to the plan's `maxCategories`. Idempotent per key.
4. `completeRegistration` writes the type's default capabilities and the first `menuConfig` in its transaction.
5. Trigger: `onRestaurantUpdated` (existing) recomputes when `businessType`, `capabilities`, `disabledTagGroupIds`, `customTags` or `planFeatures` change and `menuConfig.inputs` differ. This covers plan downgrades by `subscriptionDaily` and admin edits.
6. `createItem` and `publishMenu` validate tags, diet and attributes against `menuConfig`. New problem code `invalid-tags` (`ProblemCode` and `PublishProblemCode` changed together).
7. Admin callables:
   - `upsertBusinessType`, `upsertCapability`, `upsertTagGroup`: retire instead of delete (FR-104); audited `businessType.*`, `capability.*`, `tagGroup.*`.
   - `updatePlatformConfig` gains `alcoholNotices`.
   - `recomputeMenuConfigs({businessType?, dryRun})`: pages through restaurants in batches of 200 and reports how many changed. Audit `platform.recomputeMenuConfigs`.
   - `adminListCatalog` gains the kinds `businessTypes`, `capabilities` and `tagGroups`.
8. Export (M12): add `attributes` and tag group names to JSON and CSV.

## Security rules

- `businessTypes`: `allow read: if true` (D4). `capabilities` and `tagGroups`: readable by verified owners and admins. All three: `write: false`.
- `restaurants/{rid}/settings/{doc}`: owner and admin read; `write: false`.
- `validItemUpdate()` (D6):
  - `dietaryLabelId` must be in `menuConfig.allowedDietIds`. This replaces the `exists(dietaryLabels/…)` check, so it costs the same.
  - `tagIds.toSet().difference(resource.data.tagIds.toSet())` must be a subset of `allowedTagIds`, with size ≤ 15.
  - For each of `single0`…`single3`, at most one tag may intersect.
  - `attributes`: allowed keys only, `servingSizes` a list of ≤ 6 entries, `abvTenths` an int from 0 to 1000.
- Root whitelist: add `region` and `seo` (one regex). The "heaviest update" test must stay green.
- Tenant isolation is unchanged. A rules test is added for every new path.

## Owner app

| Area | Change |
| --- | --- |
| Core models | `BusinessTypeDef`, `CapabilityDef`, `TagGroup`, `TagDef`, `MenuConfig` (freezed, `fromMap`). Repositories and providers: `businessTypesProvider`, `menuConfigProvider(rid)`. The `BusinessType` enum and its arb labels are replaced by data; the `menu_header_preview` and profile dropdown read the catalog |
| Sign-up | The dropdown is filled from `businessTypes` (D4). `completeRegistration` accepts any active id (zod checks it against Firestore instead of an enum) |
| Setup wizard | New first steps: **What kind of place is it?** (type grid with icons) → **Tell us a bit more** (capability switches pre-set from the type) → **Start your menu** (starter categories, all ticked) → the existing profile → images → finish. Each step saves through `updateMenuFeatures` / `createStarterCategories` and stamps `setupProgress`, so the wizard reopens at the first unfinished step. Compact: one step per page. Expanded: stepper plus preview, as today |
| Settings → Business type & features | New route `/settings/features`: type, capability switches, optional groups, and custom tags (Pro; Free shows an upgrade prompt). A change shows a dialog based on the dry-run counts: "12 items have tags that will be hidden. Nothing is deleted; turning this back on restores them." |
| Item editor | Schema-driven from `menuConfig`. It loops over `tagGroups`: single groups become `ChoiceChip`s (required ones marked), multi groups become `FilterChip`s with the exclusive pairs enforced. Serving sizes (a list editor with `PriceField`) and ABV appear only when they are in `itemFields`. Hidden ids already on an item are kept in the save. The item label comes from `terminology` |
| Regional settings | `region` picker (D9) when the restaurant serves alcohol |
| Menu link / SEO | "Show in search engines" switch (D10) |

All UI strings go in `app_en.arb` / `core_en.arb`. Tag and group names come from Firestore data: English now, with `names {ta, ar}` maps added later without changing the schema. Layout uses directional widgets. Every new screen is tested at 360, 768 and 1280 px and added to `route_sweep_test.dart`.

## Public menu (functions/src/public/)

- Tag pills come from snapshot tags, which publishing has already filtered by `menuConfig`. Diet keeps the India veg/non-veg symbol (FR-023).
- Filter chips come from `snapshot.menu.filters` instead of "every label in use". "Veg only", "Non-alcoholic" and "Eggless" work through the existing `data-d` / `data-t` script, which must stay under 10 KB.
- A "Pure Veg" badge in the header when `badges` has `pureVeg`.
- An alcohol notice in the footer (age and text) when `notices` has `alcohol`.
- Serving sizes: the price per size in the item, "from" the lowest price on compact cards. ABV shown as "4.5 % ABV".
- `noindex` and no sitemap entry when `indexable` is false.
- New strings in `text.ts`. The Lighthouse budget still has to pass.

## Admin app

A new **Catalog** tab for each of: business types (with a starter-category list editor), capabilities (pickers for the groups and tags they add or hide), tag groups (an inline tag table with icon, colour, sort and retire), and alcohol notices by region (in Settings). Each type gets a "Recompute menu config for restaurants of this type" action (dry run → confirm → result counts) that uses `runAdminAction()` and `askReason()`. Editing a template never changes restaurants by itself. Read-only below 600 px, as for the other editors.

## Seed and migration

- `functions/scripts/seed-platform.mjs` (idempotent; `--confirm-prod`) seeds business types, capabilities, tag groups (diet copied from the existing `DIETARY_LABELS` ids, existing `ITEM_TAGS` folded into `spice`/`highlights`) and the placeholder alcohol notices. The data lives in `functions/src/menu-config/seed-data.ts`.
- `functions/scripts/migrate-business-types.mjs`, run through a new `ops/migrate-business-types.sh` (dry run by default, `--apply`, `CONFIRM_PROD=yes`). For each restaurant:
  - map an unknown `businessType` to `restaurant`;
  - leave `capabilities` empty (the type defaults apply);
  - compute `menuConfig`.

  With D1–D3 accepted, **no item documents change**. Legacy label ids are already valid tag ids, and items whose old tags are outside the new config keep them (hidden). The report lists restaurants by type, the `menuConfig` documents written, and the items carrying hidden tags. With D2(b), the same script also rewrites `dietaryLabelId` and `tagIds` through a mapping table, counted in dry run.
- Run only against the emulators until you approve a real-project run.

## Tasks

- [x] 0a. Approval of this plan and decisions D1–D10 (2026-11-25); master-plan row M14 set to In progress.
- [ ] 0b. FRD v1.2 change note for the Phase 2 items pulled in (custom tags, allergens, serving sizes) and the new FR ids.
- [x] 1. `menu-config/` pure `computeMenuConfig` + seed data + unit tests.
- [ ] 2. Seed script update; legacy readers moved to `tagGroups` (`createItem`, `draft-reader`, snapshot).
- [ ] 3. `menuConfig` writer, `updateMenuFeatures`, `createStarterCategories`, custom-tag callables, `completeRegistration` and `onRestaurantUpdated` changes; plan flags `customTags` / `maxCustomTags` (+ `syncPlanFeatures`). *Partly done, see Current status.*
- [ ] 4. Firestore rules (catalogs, `settings/*`, item tags and attributes, root `region` / `seo`) + rules tests; heaviest-update test still green.
- [ ] 5. Snapshot schema 2 (menu block, attributes, filtering by config, `invalid-tags` problem) + renderer (badge, notice, filters, sizes, ABV, noindex, sitemap), still rendering schema 1; snapshots and Lighthouse.
- [ ] 6. Core models and repositories; remove the `BusinessType` enum use; sign-up dropdown from data.
- [ ] 7. Setup wizard: type, features and starter-category steps, resumable.
- [ ] 8. Settings → Business type & features (warning dialog, optional groups, custom tags with plan gate); region and SEO switches.
- [ ] 9. Schema-driven item editor (groups, exclusive pairs, serving sizes, ABV, keep hidden ids).
- [ ] 10. Admin callables + Catalog screens + alcohol notices + recompute action.
- [ ] 11. Migration script + ops wrapper + dry-run test on emulator data.
- [ ] 12. Export (M12) fields; architecture §4/§5/§7 and master-plan cross-module notes updated.
- [ ] 13. `tool/check.sh` green; acceptance walk-through on the emulators.

## Tests

- **Unit (Jest), `computeMenuConfig`:** each of the 14 types with no capabilities; each capability on and off for restaurant, bar, bakery and hotel; `pureVeg` hides non-veg and egg (also when the type is `bar`); a disabled required group is ignored; custom tags dropped on Free and kept on Pro; single slots and exclusive sets; tag-id uniqueness across groups; stable output (same inputs give the same document).
- **Rules (`firestore-tests/test/menu-config.test.js`):** an owner can't write `settings/menuConfig`; can't add a tag outside `allowedTagIds`; can keep a hidden tag while editing the name; can't set two tags from one single-select group; can't set a disallowed diet (pure veg + non-veg); can't read another tenant's `menuConfig`; catalogs are read-only; `businessTypes` is readable signed out; the heaviest update still fits.
- **Functions emulator:** `updateMenuFeatures` (dry-run counts, audit, recompute), plan gating of custom tags, `createStarterCategories` at the plan limit, `createItem` rejecting bad tags, publish `invalid-tags`, a plan downgrade recomputing through the trigger, `recomputeMenuConfigs`.
- **Renderer:** HTML snapshots for bar (notice, Non-alcoholic filter, sizes, noindex), pure-veg (badge, no non-veg chips), bakery and hotel; a schema-1 version still renders.
- **Widget (owner app):** the wizard steps and resume at 3 widths; the item editor renders the right groups for bar vs bakery vs pure-veg restaurant, keeps hidden ids, and shows the serving-size editor only when enabled; the features page shows the warning dialog and the plan gate.
- **Widget (admin app):** the catalog editors and the recompute action.
- **Migration:** a dry run on seeded emulator data reports the counts and writes nothing; apply writes `menuConfig` and changes no items; re-running changes nothing.

## Acceptance

1. A new owner picks "Bar, pub or lounge": Serves alcohol is pre-ticked, the bar starter categories are created, and the item form shows the Alcohol group plus serving sizes. After publishing, the public menu shows the alcohol notice and the Non-alcoholic filter.
2. A pure-veg restaurant never sees the Non-veg or Egg tags, and its public menu shows the Pure Veg badge.
3. A bakery sees Eggless and Sugar-free, and does not see the Alcohol or Hotel groups.
4. A hotel sees the Hotel tags and the In-Room Dining category.
5. Turning Serves alcohol off hides the alcohol tags without deleting them. Turning it on restores them (editor and, after publishing, the menu).
6. An owner can't save an item with a tag outside `menuConfig`: the rules, `createItem` and publish all reject it.
7. A platform admin can add a new business type and it appears in sign-up and the wizard with no app release.
8. Existing restaurants migrate without data loss: the dry-run and apply reports match, and no item documents change (with D1–D3).
9. This file is up to date.

## Current status (2026-11-25)

**Done and tested** (`npm run lint` clean; `npx jest` 382/382 on Node 22):

- `functions/src/menu-config/types.ts`: catalog, config and input types. Sets inside groups are stored as `{ids: [...]}` maps because Firestore can't store nested arrays (`exclusive`, `extraSingles`).
- `functions/src/menu-config/seed-data.ts`:
  - 14 business types (the 10 M01 ids plus `fastFood`, `club`, `canteen`, `caterer`), 5 capabilities and 8 tag groups;
  - alcohol notices for `IN-TN`, `IN-PY` and `default`, as **placeholders** to verify.
  - Diet and the M04 tag ids are kept (D1–D3).
- `functions/src/menu-config/compute.ts`:
  - `computeMenuConfig` (pure);
  - `checkItemTags` (diet, allowed tags, single and exclusive sets, kept ids) and `visibleTagIds`;
  - defensive parsers for catalog documents and restaurant fields.
- `compute.test.ts`: 45 tests (seed integrity, every type, bar, pure veg, bakery, hotel, all capabilities, disabled groups, fallback type, retired and inactive entries, custom tags and the plan cap, slot overflow, item checks, parsing).
- Plan flags `customTags` / `maxCustomTags` (D8):
  - `PlanFeatures` and `restaurantPlanFeatures` in `lib/plan-limits.ts`;
  - `SEED_PLANS` (Free off/0, Pro on/20);
  - `upsertPlan` schema (optional, so older admin builds keep working).

**Written, not yet compiled into an index or tested:**

- `functions/src/menu-config/store.ts`: catalog loader, `configFor`, fingerprint-based `writeMenuConfig`, `recomputeMenuConfig` and the item attribute schema (D7).
- `functions/src/menu-config/callables.ts`: `updateMenuFeatures` (with dry-run impact), `createStarterCategories` and `upsertCustomTag`.
  - Not exported from `functions/src/index.ts` yet.
  - No emulator tests yet.
  - **Change from the plan:** `region` and `seo` are written through `updateMenuFeatures` instead of the owner whitelist in rules, so `validOwnerUpdate()` stays within its evaluation budget.
  - Custom tags are retired (`retired: true`), never removed, so their names survive for items that keep them.

**Next:**

1. Export the callables.
2. Add `completeRegistration` (first config, catalog-checked type) and the `onRestaurantUpdated` recompute.
3. Write emulator tests.
4. Move on to task 2 (seed script, legacy readers) and task 4 (rules).

**Machine notes (this workstation):**

- Functions need **Node 22**. On Node 20, npm skips firebase-admin's optional `@google-cloud/firestore`, and `tsc` reports about 115 errors in untouched files. Node 22.23.5 is installed through nvm; the default is still 20.
- The emulators need **Java 21+**. Only 17 and 11 are installed system-wide, and Android Studio's JBR is 11. A Temurin 21 was unpacked in the session's temporary folder for this work.
- The disk was full (about 150–340 MB free), which stopped the rules-test install (`firestore-tests` `npm ci`). Free space before running the emulator suites.

## Open items

- Decisions D1–D10 above.
- Approval for the Phase 2 features (custom tags, allergens, serving sizes), or a decision to cut them.
- Real alcohol notice texts and ages per region (legal input; the seed values are placeholders).
- Which starter categories each type gets. The seed will propose lists, e.g. bar: Beer, Wine, Spirits, Cocktails, Mocktails, Bar bites. Please review them.

## Completion notes

_To fill in when done._

## Change log

- 2026-11-25: Plan written; waiting for approval.
- 2026-11-25: Approved (D1–D10 as recommended). Task 1 done (pure config merge, seed data, 45 tests); plan flags for custom tags; store and owner callables drafted.
