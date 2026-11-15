# M05 – Menu customization (themes)

Status: Done
Started: 2026-11-14
Completed: 2026-11-14

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

- [x] Theme model and seed themes.
- [x] Theme gallery with premium badges. (Locking by plan is M10; see Open items.)
- [x] Colour pickers with hex input, font picker, layout and card layout selectors, light/dark switch.
- [x] Contrast checker with warning text and auto-adjust.
- [x] Preview widget with sample or real menu data.
- [x] Save to the draft (autosave + Saved indicator).

## Acceptance checks

- [x] Choosing a theme and changing colours updates the preview instantly. (Widget tests check the preview before the autosave runs.)
- [x] A low-contrast colour pair shows a warning and the preview uses the adjusted text colour. (Widget test and Chrome end to end.)
- [x] One restaurant's theme never changes another's (rules test in `firestore-tests/test/theme.test.js`).
- [x] Works at 360, 768 and 1280 px. (Widget tests at all three widths, with no overflow; Chrome end to end at 1280.)

## Tests

Unit tests for the contrast utility (with known WCAG examples). Widget tests for the editor and preview.

## Completion notes

**What was built**

- **Shared contrast and theme logic (two copies, one set of test cases)**
  - TypeScript, `functions/src/theme/`:
    - `contrast.ts`: `relativeLuminance`, `contrastRatio`, `mix`, `readableTextOn`, `ensureContrast`, `normalizeHex`, `AA_TEXT = 4.5`.
    - `resolve.ts`: `ThemeTokens`, `ThemeSettings`, `parseThemeTokens`, `parseThemeSettings`, `resolveTheme(tokens, settings)` returning `ResolvedTheme` plus contrast `issues`, `cssVariables()`, `DEFAULT_TOKENS`.
    - `seed-themes.ts`: `SEED_THEMES` and `SEED_FONTS`. `index.ts` re-exports everything for M06/M07. No deployed functions.
  - Dart, `packages/core/lib/src/theme/`:
    - `contrast.dart`: `Contrast.ratio`, `readableTextOn`, `ensure`, `mix`, `normalizeHex`; `hexToColor`, `colorToHex`.
    - `menu_theme.dart`: `MenuLayout`, `CardLayout`, `MenuMode`, `ThemeTokens`, `ThemePreset` (a `themes/{id}` doc), `ThemeSettings`, `ContrastIssue`, `ResolvedMenuTheme`, `resolveMenuTheme()`.
    - `menu_fonts.dart`: `MenuFonts.defaults`; `MenuFontResolver` with `GoogleMenuFontResolver` (google_fonts, run-time loading) and `PlainMenuFontResolver`; `menuFontResolverProvider`.
  - `functions/src/theme/contrast-cases.json` holds WCAG reference pairs, readable-text cases, blends, the seed tokens and 14 resolution cases with their expected output. `theme.test.ts` and `packages/core/test/theme/menu_theme_test.dart` both read it, so the two copies cannot drift apart. Regenerate it only on purpose and review the diff.
  - Resolution rules:
    1. Overrides win over the theme's tokens.
    2. Flipping the mode without choosing a background uses `#FFFFFF` (light) or `#121212` (dark).
    3. The surface is the theme's while the background is the theme's; otherwise it is derived from the background.
    4. Text below 4.5:1 becomes near-black `#1A1A1A` or white, whichever is better (pure black when neither reaches AA). An issue is reported. The same applies to text on cards.
    5. The primary colour used as text (`accent`: headings, prices) is blended toward the readable colour in 10 % steps until it reaches AA on both background and surface.
    6. `mutedText` is the lightest mix of text toward the background that still passes AA.
- **Seed data** (`functions/scripts/seed-platform.mjs`, now also themes and fonts):
  - Themes: `saffron` and `minimal` (Free), plus `banana-leaf`, `midnight` (dark), `cafe-cream` and `coastal` (premium). Every one passes AA unadjusted (tested).
  - `config/platform.fonts`: Poppins, Inter, Lora, Nunito, Playfair Display, Noto Sans.
  - Re-running does not overwrite admin changes. Verified on the emulator: 15 writes the first time, 0 the second.
- **Rules (`firestore.rules`)**
  - `themes/*` (get and list) and `config/platform` (get) are readable by verified owners and TOTP admins; nobody writes them from a client.
  - Theme checks inside `validOwnerUpdate()`:
    - `themeId`: `null`, or an id matching `[A-Za-z0-9_-]{1,64}` whose `themes/{id}` exists;
    - `themeSettings`: `null`, or a map with only the 7 allowed keys, checked with **one** regex over the joined values (upper-case hex, a font name of letters and spaces up to 40, known layout, card layout and mode).
  - "The heaviest update" in `restaurant-profile.test.js` now writes every theme override too, and stays within the rules budget.
- **Core:** `Restaurant.themeSettings`, `RestaurantFields.themeId` / `themeSettings`, `copyWith(themeId:, themeSettings:)`. google_fonts 6.3.2 added to core.
- **Owner app (`features/theme/`)**
  - `data/theme_repository.dart`: `ThemeRepository` (Firestore), `themePresetsProvider` (by `sort`), and `menuFontsProvider` (`config/platform.fonts`, else the defaults).
  - `application/theme_draft.dart`:
    - `ThemeDraft` holds local edits, so the preview changes before anything is saved, and stages them on M03's `DraftAutosave` (1 s, "Saved" indicator).
    - Providers: `currentThemeChoiceProvider`, `currentPresetProvider`, `resolvedThemeProvider`.
    - Choosing a theme writes `themeId` and resets `themeSettings` to `{}`.
  - `presentation/`:
    - `ThemeGalleryPage`:
      - layout: 2 columns on phones with a full-screen preview button; on tablets 2 columns beside a phone preview; on desktops 4 columns beside a 380 px preview;
      - cards: a miniature of the theme, the font name, a Premium badge and a selected state;
      - switching away from a customized theme asks for confirmation;
      - empty state when no themes are seeded.
    - `ThemeEditorPage`:
      - controls: three `ColorField`s (16 swatches plus a hex input, "Use theme colour"), a font dropdown drawn in each font, list/grid, three card layouts, a dark mode switch, "Reset to theme defaults", and `ContrastNotice` (a live region);
      - layout: on phones a scrolling page with a "Preview" app-bar button; on wide screens the controls take 360 px with the preview beside them, and desktops get a phone/desktop toggle.
    - `MenuThemePreview`: laid out at 390×780 or 1280×800 and scaled to fit (or filling the screen in the full-screen preview).
      - Uses the real menu: active categories, items not hidden over the plan limit, prices through `Money.format`, dietary icons, "Sold out".
      - Shows sample dishes while the menu is empty.
  - Routes `/settings/theme` and `/settings/theme/customize`. Settings shows "Theme · Saffron (customized)". The dashboard's "Choose a theme" step opens the gallery (M03's `_stepRoute`).
- **Tests**
  - Functions: `theme.test.ts` (55 tests).
  - Rules: `theme.test.js` (themes and config reads, theme existence, 12 malformed overrides, tenant isolation BR-012, suspended accounts), plus changes to `baseline.test.js` and `restaurant-profile.test.js`.
  - Core: `menu_theme_test.dart` (51 tests, the shared cases included).
  - Owner app: `theme_page_test.dart` (gallery and editor at 360/768/1280, instant preview, contrast warning with adjusted preview text, invalid hex, desktop toggle, real and sample menu, font, Settings and dashboard entry points). `pumpOwnerApp` now overrides `themeRepositoryProvider` (`FakeThemeRepository`, `test/fake_theme.dart`) and `menuFontResolverProvider` (`PlainMenuFontResolver`).
  - Chrome end to end: `integration_test/theme_flow_test.dart` (in `tool/integration.sh`). It chooses a theme, sets a low-contrast background (warning, white preview text, saved), switches dark mode, and checks that the rules refuse a malformed override and an unknown theme.
  - Totals at completion, all passing:

    | Suite | Tests |
    | --- | --- |
    | Core | 213 |
    | Owner app | 134 |
    | Admin app | 19 |
    | Functions unit | 189 |
    | Functions emulator | 66 |
    | Rules | 144 |
    | End to end | 5 of 5 (theme flow re-run alone after a web focus fix) |

**Decisions that differ from the plan**

1. **Contrast covers more than body text.** FR-060 names body text. The resolver also fixes text on cards and the primary colour used as text, and derives a muted text colour, because the menu uses all four.
2. **No callables.** Owners write `themeId` and `themeSettings` directly; the rules check that the theme exists and check the overrides' shape. Plan gating (BR-011) is M10's (see M10 inputs).
3. **Theme documents also have `sort`, `retired` and `updatedAt`,** like the labels in M04. The Dart class is `ThemePreset` because Flutter already has `MenuTheme`.
4. **`config/platform` is readable by verified owners** (the plan keeps fonts there). It holds nothing secret today; M11 must keep it that way.
5. **The rules do not check the font against `config/platform.fonts`** (budget: that would be one more document read and list check). The app offers only listed fonts, and M07 falls back to the system font for unknown ones.
6. **Medium width (768 px):** the gallery has 2 columns beside a phone preview, and the editor has a phone preview only; the desktop toggle needs the expanded width.
7. **The preview never dims sold-out items** (opacity would break AA); it shows a badge instead. M07 should do the same.
8. **Corrected a comment:** `#FF7A00` on white is 2.6:1, not 2.9:1 (`brand_colors.dart`).

## Open items

- **Premium themes are not locked yet.** All themes are selectable until M10 adds plan gating in the rules or a callable and locks the cards (noted in the M10 plan).
- **Real fonts are loaded by google_fonts at run time** and are not checked by automated tests (they use `PlainMenuFontResolver`). Check by hand: the font dropdown and the preview show each typeface on web, Android and iOS. Offline devices fall back to the default font.
- **Android and iOS were not run on a device.** Check the full-screen preview and the colour swatches on a phone.
- **Seed the real projects:** `node functions/scripts/seed-platform.mjs --project eazy-suvai-dev` (after `npm run build`). Until then the gallery shows "No themes are available yet".
- **Tamil and Arabic fonts** (`Noto Sans Tamil`, `Noto Sans Arabic`) are for the later language phases; add them to `config/platform.fonts`.
- The profile page's `MenuHeaderPreview` (M03) still uses the app theme, not the restaurant theme. `MenuThemePreview` replaces it in spirit; switching it over is optional.


## Change log

- 2026-11-14: Plan created.
- 2026-11-14: Done. Shared WCAG contrast and theme resolution (Dart + TypeScript, one test-case file), 6 seed themes and the font list, rules for `themes`, `config/platform` and the theme draft fields, theme gallery and editor with live phone/desktop preview and autosave. Tests: unit, rules, widget at 3 widths, Chrome end to end. Contrast also covers card text and the primary colour used as text; no callables (direct writes checked by the rules).
