# M05 – Menu customization (themes)

Status: Not started
Started:
Completed:

## Goal

Owners choose a predefined theme and adjust colours, font, layouts and light/dark mode, and see the result immediately, while text always stays readable.

## FRD coverage

FR-055 to FR-060, BR-012, AC-012 (settings part).

## Depends on

M03.

## Inputs from other modules

- M00 (done 2026-11-14): brand colours `#FF7A00`/`#C8650A` fail AA for normal text. Theme pickers must check contrast like `packages/core/test/theme/app_theme_test.dart` (architecture §6).
- M03 (done 2026-11-14): logo and cover on the restaurant document (`Restaurant.logo` / `.cover`, M02 image objects). `themeId` and `themeSettings` are already in the owner whitelist with placeholder checks (`themeId`: null or `[A-Za-z0-9_-]{1,64}`; `themeSettings`: any map). **Rules budget:** `validOwnerUpdate` in `firestore.rules` is close to the per-request evaluation limit; add theme checks inline (no helper per field, at most one or two `matches()`), and keep "the heaviest update" in `firestore-tests/test/restaurant-profile.test.js` green. The setup checklist's "Choose a theme" step is done when `themeId != null`; it opens `Routes.settings` until M05 adds its route (update `_stepRoute` in `dashboard_page.dart`). `MenuHeaderPreview` (owner app) can take theme colours.
- M10 (later): which theme IDs the plan allows. Until then, all themes are allowed.

## Scope

**In:** theme gallery, theme settings editor, contrast check and auto-fix, theme preview widget, seed themes.
**Out:** the real public page styling (M07 uses the same tokens), admin theme management screens (M11).

## Data and backend

- `themes/{id}`: `name`, `tokens {primary, secondary, background, surface, text, font, layout: 'list'|'grid', cardLayout: 'compact'|'image-top'|'image-left', mode: 'light'|'dark'}`, `premium: bool`.
- Restaurant draft fields `themeId` and `themeSettings` (overrides).
- Seed at least 6 themes (for example: Saffron, Banana Leaf, Midnight, Café Cream, Minimal, Coastal); 2 marked non-premium for the Free plan.
- Fonts: a curated list in `config/platform.fonts` (start with Poppins, Inter, Lora, Nunito, Playfair Display, Noto Sans) that also covers Tamil and Arabic in later phases.
- Shared contrast utility (in `packages/core` and mirrored in functions for M07): WCAG ratio; if text on background is below 4.5:1, switch text to the better of near-black or white (FR-060).

## Screens and responsive behaviour

| Screen | Compact | Expanded |
| --- | --- | --- |
| Theme gallery | 2-column grid of theme cards | 4-column grid beside a large preview |
| Theme editor | Controls in a scrolling page; a "Preview" button opens a full-screen phone preview | Controls left (360 px), live phone-sized preview and desktop preview toggle right |

The preview is a Flutter widget that imitates the public menu layout using the same tokens. It is an approximation; the exact page is checked in M06 preview.

## Tasks

- [ ] Theme model and seed themes.
- [ ] Theme gallery with premium badges (locked if the plan does not allow, after M10).
- [ ] Colour pickers with hex input, font picker, layout and card layout selectors, light/dark switch.
- [ ] Contrast checker with warning text and auto-adjust.
- [ ] Preview widget with sample or real menu data.
- [ ] Save to the draft (autosave + Saved indicator).

## Acceptance checks

- [ ] Choosing a theme and changing colours updates the preview instantly.
- [ ] A low-contrast colour pair shows a warning and the preview uses the adjusted text colour.
- [ ] One restaurant's theme never changes another's (rules test).
- [ ] Works at 360, 768 and 1280 px.

## Tests

Unit tests for the contrast utility (with known WCAG examples). Widget tests for the editor and preview.

## Completion notes

_Fill in when done._

## Open items

## Change log

- 2026-11-14: Plan created.
