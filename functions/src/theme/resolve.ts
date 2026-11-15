/**
 * Turns a theme plus the restaurant's overrides into the colours the menu
 * uses, fixing text colours that fail WCAG AA (M05, FR-055, FR-060).
 *
 * The Dart copy is `resolveMenuTheme()` in
 * `packages/core/lib/src/theme/menu_theme.dart`; both are tested against
 * `contrast-cases.json`. M07 renders the public menu from
 * {@link ResolvedTheme} with the CSS custom properties in {@link cssVariables}.
 */
import {
  AA_TEXT,
  contrastRatio,
  ensureContrast,
  mix,
  NEAR_BLACK,
  normalizeHex,
  readableTextOn,
  WHITE,
} from "./contrast";

export const MENU_LAYOUTS = ["list", "grid"] as const;
export const CARD_LAYOUTS = ["compact", "image-top", "image-left"] as const;
export const MENU_MODES = ["light", "dark"] as const;

export type MenuLayout = (typeof MENU_LAYOUTS)[number];
export type CardLayout = (typeof CARD_LAYOUTS)[number];
export type MenuMode = (typeof MENU_MODES)[number];

/** `themes/{id}.tokens`. Colours are `#RRGGBB`. */
export interface ThemeTokens {
  primary: string;
  secondary: string;
  background: string;
  surface: string;
  text: string;
  font: string;
  layout: MenuLayout;
  cardLayout: CardLayout;
  mode: MenuMode;
}

/** `restaurants/{rid}.themeSettings`: the owner's overrides; every field optional. */
export interface ThemeSettings {
  primary?: string;
  secondary?: string;
  background?: string;
  font?: string;
  layout?: MenuLayout;
  cardLayout?: CardLayout;
  mode?: MenuMode;
}

export type ContrastIssueKind = "text" | "surfaceText" | "accent";

/** A colour pair below AA and what it was changed to. */
export interface ContrastIssue {
  kind: ContrastIssueKind;
  /** The colour that failed and the ratio it had. */
  original: string;
  ratio: number;
  adjusted: string;
}

export interface ResolvedTheme {
  primary: string;
  onPrimary: string;
  secondary: string;
  onSecondary: string;
  background: string;
  surface: string;
  /** Body text on `background`. */
  text: string;
  /** Text on `surface` (cards). */
  surfaceText: string;
  /** Descriptions; AA on both background and surface. */
  mutedText: string;
  /** Primary as a text colour (headings, prices); AA on both backgrounds. */
  accent: string;
  /** Dividers and card outlines (decorative). */
  border: string;
  font: string;
  layout: MenuLayout;
  cardLayout: CardLayout;
  mode: MenuMode;
  issues: ContrastIssue[];
}

/** Used when a restaurant has no theme yet, or its theme is missing. */
export const DEFAULT_TOKENS: ThemeTokens = {
  primary: "#A8550A",
  secondary: "#3B7A20",
  background: "#FFF8EE",
  surface: "#FFFFFF",
  text: "#2B2B2B",
  font: "Poppins",
  layout: "list",
  cardLayout: "image-left",
  mode: "light",
};

/** Background when the owner flips the mode and has not chosen one. */
export const MODE_BACKGROUND: Record<MenuMode, string> = { light: "#FFFFFF", dark: "#121212" };

function oneOf<T extends string>(values: readonly T[], v: unknown): T | undefined {
  return typeof v === "string" && (values as readonly string[]).includes(v) ? (v as T) : undefined;
}

/** Reads a stored settings map, dropping unknown keys and invalid values. */
export function parseThemeSettings(value: unknown): ThemeSettings {
  if (value === null || typeof value !== "object") return {};
  const m = value as Record<string, unknown>;
  const s: ThemeSettings = {};
  const primary = normalizeHex(m.primary);
  const secondary = normalizeHex(m.secondary);
  const background = normalizeHex(m.background);
  if (primary) s.primary = primary;
  if (secondary) s.secondary = secondary;
  if (background) s.background = background;
  if (typeof m.font === "string" && m.font.trim() !== "") s.font = m.font.trim();
  const layout = oneOf(MENU_LAYOUTS, m.layout);
  const cardLayout = oneOf(CARD_LAYOUTS, m.cardLayout);
  const mode = oneOf(MENU_MODES, m.mode);
  if (layout) s.layout = layout;
  if (cardLayout) s.cardLayout = cardLayout;
  if (mode) s.mode = mode;
  return s;
}

/** Reads `themes/{id}.tokens`, filling gaps from {@link DEFAULT_TOKENS}. */
export function parseThemeTokens(value: unknown): ThemeTokens {
  const m = value !== null && typeof value === "object" ? (value as Record<string, unknown>) : {};
  return {
    primary: normalizeHex(m.primary) ?? DEFAULT_TOKENS.primary,
    secondary: normalizeHex(m.secondary) ?? DEFAULT_TOKENS.secondary,
    background: normalizeHex(m.background) ?? DEFAULT_TOKENS.background,
    surface: normalizeHex(m.surface) ?? DEFAULT_TOKENS.surface,
    text: normalizeHex(m.text) ?? DEFAULT_TOKENS.text,
    font: typeof m.font === "string" && m.font.trim() !== "" ? m.font.trim() : DEFAULT_TOKENS.font,
    layout: oneOf(MENU_LAYOUTS, m.layout) ?? DEFAULT_TOKENS.layout,
    cardLayout: oneOf(CARD_LAYOUTS, m.cardLayout) ?? DEFAULT_TOKENS.cardLayout,
    mode: oneOf(MENU_MODES, m.mode) ?? DEFAULT_TOKENS.mode,
  };
}

/**
 * Resolution rules (keep in step with the Dart copy):
 * 1. Overrides win over the theme's tokens.
 * 2. Changing the mode without choosing a background uses {@link MODE_BACKGROUND}.
 * 3. The surface is the theme's while the background is the theme's;
 *    otherwise it is derived from the background (lighter on dark, darker on light).
 * 4. Text is the theme's text colour (or the readable one after a mode
 *    change). Below 4.5:1 it becomes near-black or white and an issue is
 *    reported. The same for text on the surface.
 * 5. The accent (primary as text) must reach AA on background and surface;
 *    otherwise it is blended toward the text colour and an issue is reported.
 */
export function resolveTheme(base: ThemeTokens | null, settings: ThemeSettings = {}): ResolvedTheme {
  const t = base ?? DEFAULT_TOKENS;
  const s = parseThemeSettings(settings);
  const mode = s.mode ?? t.mode;
  const sameMode = mode === t.mode;
  const primary = s.primary ?? t.primary;
  const secondary = s.secondary ?? t.secondary;
  const background = s.background ?? (sameMode ? t.background : MODE_BACKGROUND[mode]);
  const themeBackground = background === t.background && sameMode;
  const surface = themeBackground
    ? t.surface
    : isLight(background)
      ? mix(background, "#000000", 0.04)
      : mix(background, "#FFFFFF", 0.08);

  const issues: ContrastIssue[] = [];

  const wanted = sameMode ? t.text : readableTextOn(background);
  let text = wanted;
  const textRatio = contrastRatio(wanted, background);
  if (textRatio < AA_TEXT) {
    text = readableTextOn(background);
    issues.push({ kind: "text", original: wanted, ratio: round2(textRatio), adjusted: text });
  }

  let surfaceText = text;
  const surfaceRatio = contrastRatio(text, surface);
  if (surfaceRatio < AA_TEXT) {
    surfaceText = readableTextOn(surface);
    issues.push({ kind: "surfaceText", original: text, ratio: round2(surfaceRatio), adjusted: surfaceText });
  }

  const accentRatio = Math.min(contrastRatio(primary, background), contrastRatio(primary, surface));
  const accent = ensureContrast(primary, [background, surface], readableTextOn(background));
  if (accentRatio < AA_TEXT) {
    issues.push({ kind: "accent", original: primary, ratio: round2(accentRatio), adjusted: accent });
  }

  let mutedText = text;
  for (const amount of [0.3, 0.2, 0.1]) {
    const m = mix(text, background, amount);
    if (contrastRatio(m, background) >= AA_TEXT && contrastRatio(m, surface) >= AA_TEXT) {
      mutedText = m;
      break;
    }
  }

  return {
    primary,
    onPrimary: readableTextOn(primary),
    secondary,
    onSecondary: readableTextOn(secondary),
    background,
    surface,
    text,
    surfaceText,
    mutedText,
    accent,
    border: mix(background, text, 0.15),
    font: s.font ?? t.font,
    layout: s.layout ?? t.layout,
    cardLayout: s.cardLayout ?? t.cardLayout,
    mode,
    issues,
  };
}

/** Whether dark text reads better than white on [color]. */
export function isLight(color: string): boolean {
  return contrastRatio(NEAR_BLACK, color) >= contrastRatio(WHITE, color);
}

function round2(n: number): number {
  return Math.round(n * 100) / 100;
}

/**
 * The CSS custom properties M07 sets on the menu page (`--es-primary`,
 * `--es-on-primary`, …). The names are part of the cross-module contract.
 */
export function cssVariables(r: ResolvedTheme): Record<string, string> {
  return {
    "--es-primary": r.primary,
    "--es-on-primary": r.onPrimary,
    "--es-secondary": r.secondary,
    "--es-on-secondary": r.onSecondary,
    "--es-background": r.background,
    "--es-surface": r.surface,
    "--es-text": r.text,
    "--es-surface-text": r.surfaceText,
    "--es-muted-text": r.mutedText,
    "--es-accent": r.accent,
    "--es-border": r.border,
  };
}
