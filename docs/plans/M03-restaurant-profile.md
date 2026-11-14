# M03 – Restaurant onboarding and profile

Status: Not started
Started:
Completed:

## Goal

After first login the owner completes a guided setup, then manages the restaurant profile, public visibility, currency, time zone and menu URL.

## FRD coverage

FR-008, FR-011 to FR-014, FR-092, FR-093, FR-103, §5.1 (onboarding steps 4–6), §6.2–6.4, BR-002, AC-002, AC-023 (slug part).

## Depends on

M01, M02.

## Inputs from other modules

- M01: `restaurants/{rid}` created with slug, QR code, Free plan, defaults.
- M02: `ImagePickerField`, `ResponsiveImage`, image object model.

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

- [ ] Profile repository and Riverpod providers (draft read and write, autosave with a 1 s debounce and a "Saved" indicator).
- [ ] Profile form with every FR-011 field and validation (URL, email, phone by country).
- [ ] Visibility toggles (FR-013).
- [ ] Opening hours editor: per weekday, up to 3 time slots, or closed.
- [ ] Currency and time zone pickers; FR-103 warning dialog.
- [ ] Logo and cover upload with `ImagePickerField`.
- [ ] Slug editor and `changeSlug` callable; old slug kept for redirect.
- [ ] First-run setup wizard and dashboard setup checklist.
- [ ] Rules tests for the field whitelist (owner cannot change `status`, `planId`, `slug`, `counts`, `qrCode`, `publishedVersion`).

## Acceptance checks

- [ ] AC-002: owner creates and updates a full profile.
- [ ] Changing the slug keeps the old slug resolvable to the restaurant (redirect served in M07).
- [ ] A reserved or taken slug is refused with a clear message.
- [ ] Hidden fields are flagged so M07 can omit them.
- [ ] All screens work at 360, 768 and 1280 px.

## Tests

Functions: `changeSlug` (valid, reserved, taken, format errors). Rules: whitelist. Widget: profile form validation; opening hours editor.

## Completion notes

_Fill in when done._

## Open items

## Change log

- 2026-11-14: Plan created.
