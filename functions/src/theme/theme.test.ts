import { readFileSync } from "node:fs";
import { join } from "node:path";

import {
  AA_TEXT,
  contrastRatio,
  cssVariables,
  ensureContrast,
  mix,
  normalizeHex,
  parseThemeSettings,
  parseThemeTokens,
  readableTextOn,
  relativeLuminance,
  resolveTheme,
  SEED_FONTS,
  SEED_THEMES,
  type ThemeSettings,
  type ResolvedTheme,
  type ThemeTokens,
} from "./index";

/** The cases shared with the Dart tests (packages/core/test/theme/menu_theme_test.dart). */
interface SharedCases {
  contrast: { a: string; b: string; ratio: number }[];
  readable: { background: string; text: string }[];
  mix: { a: string; b: string; t: number; result: string }[];
  themes: Record<string, ThemeTokens>;
  resolve: { theme: string | null; settings: Record<string, unknown>; expected: ResolvedTheme }[];
}

const cases = JSON.parse(readFileSync(join(__dirname, "contrast-cases.json"), "utf8")) as SharedCases;

const round2 = (n: number) => Math.round(n * 100) / 100;

describe("contrast (WCAG 2.1)", () => {
  it("matches published reference ratios", () => {
    // Independent of the shared cases: values from the WCAG definition.
    expect(contrastRatio("#000000", "#FFFFFF")).toBeCloseTo(21, 5);
    expect(contrastRatio("#FFFFFF", "#FFFFFF")).toBeCloseTo(1, 5);
    expect(round2(contrastRatio("#777777", "#FFFFFF"))).toBe(4.48);
    expect(round2(contrastRatio("#767676", "#FFFFFF"))).toBe(4.54);
    expect(relativeLuminance("#FFFFFF")).toBeCloseTo(1, 10);
    expect(relativeLuminance("#000000")).toBe(0);
  });

  it("is symmetric", () => {
    expect(contrastRatio("#A8550A", "#FFF8EE")).toBe(contrastRatio("#FFF8EE", "#A8550A"));
  });

  it.each(cases.contrast)("ratio $a on $b = $ratio", ({ a, b, ratio }) => {
    expect(round2(contrastRatio(a, b))).toBe(ratio);
  });

  it.each(cases.readable)("readable text on $background is $text", ({ background, text }) => {
    expect(readableTextOn(background)).toBe(text);
    expect(contrastRatio(text, background)).toBeGreaterThanOrEqual(AA_TEXT);
  });

  it("always finds AA text for every grey", () => {
    for (let v = 0; v <= 255; v++) {
      const hex = `#${v.toString(16).padStart(2, "0").repeat(3)}`;
      expect(contrastRatio(readableTextOn(hex), hex)).toBeGreaterThanOrEqual(AA_TEXT);
    }
  });

  it.each(cases.mix)("mix $a and $b by $t", ({ a, b, t, result }) => {
    expect(mix(a, b, t)).toBe(result);
  });

  it("normalizes hex input", () => {
    expect(normalizeHex("#ff7a00")).toBe("#FF7A00");
    expect(normalizeHex("ff7a00")).toBe("#FF7A00");
    expect(normalizeHex(" #FF7A00 ")).toBe("#FF7A00");
    expect(normalizeHex("#fff")).toBeNull();
    expect(normalizeHex("red")).toBeNull();
    expect(normalizeHex(12)).toBeNull();
  });

  it("ensureContrast keeps a passing colour and blends a failing one", () => {
    expect(ensureContrast("#A8550A", ["#FFFFFF"], "#1A1A1A")).toBe("#A8550A");
    const fixed = ensureContrast("#FFD54F", ["#FFFFFF"], "#1A1A1A");
    expect(contrastRatio(fixed, "#FFFFFF")).toBeGreaterThanOrEqual(AA_TEXT);
  });
});

describe("resolveTheme", () => {
  const themes = cases.themes;

  it.each(cases.resolve)("$theme with $settings", ({ theme, settings, expected }) => {
    const r = resolveTheme(theme ? themes[theme] : null, settings as ThemeSettings);
    expect(r).toEqual(expected);
  });

  it("every resolved text colour reaches AA", () => {
    for (const c of cases.resolve) {
      const r = resolveTheme(c.theme ? themes[c.theme] : null, c.settings as ThemeSettings);
      expect(contrastRatio(r.text, r.background)).toBeGreaterThanOrEqual(AA_TEXT);
      expect(contrastRatio(r.surfaceText, r.surface)).toBeGreaterThanOrEqual(AA_TEXT);
      expect(contrastRatio(r.mutedText, r.background)).toBeGreaterThanOrEqual(AA_TEXT);
      expect(contrastRatio(r.mutedText, r.surface)).toBeGreaterThanOrEqual(AA_TEXT);
      expect(contrastRatio(r.accent, r.background)).toBeGreaterThanOrEqual(AA_TEXT);
      expect(contrastRatio(r.onPrimary, r.primary)).toBeGreaterThanOrEqual(AA_TEXT);
      expect(contrastRatio(r.onSecondary, r.secondary)).toBeGreaterThanOrEqual(AA_TEXT);
    }
  });

  it("reports a low-contrast background and adjusts the text (FR-060)", () => {
    const r = resolveTheme(themes.saffron, { background: "#2B2B2B" });
    expect(r.issues.map((i) => i.kind)).toContain("text");
    expect(r.text).toBe("#FFFFFF");
  });

  it("overrides win; invalid overrides are ignored", () => {
    const r = resolveTheme(themes.coastal, { font: "Lora", layout: "list", cardLayout: "compact" });
    expect([r.font, r.layout, r.cardLayout]).toEqual(["Lora", "list", "compact"]);
    const bad = resolveTheme(themes.saffron, { primary: "nope" } as unknown as ThemeSettings);
    expect(bad.primary).toBe(themes.saffron.primary);
  });

  it("parses stored maps defensively", () => {
    expect(parseThemeSettings(null)).toEqual({});
    expect(parseThemeSettings({ mode: "sepia", primary: "#abcdef" })).toEqual({ primary: "#ABCDEF" });
    expect(parseThemeTokens({}).font).toBe("Poppins");
  });

  it("exposes the CSS custom properties M07 uses", () => {
    expect(Object.keys(cssVariables(resolveTheme(null)))).toEqual([
      "--es-primary",
      "--es-on-primary",
      "--es-secondary",
      "--es-on-secondary",
      "--es-background",
      "--es-surface",
      "--es-text",
      "--es-surface-text",
      "--es-muted-text",
      "--es-accent",
      "--es-border",
    ]);
  });
});

describe("seed themes", () => {
  it("has at least 6 themes, 2 of them for the Free plan", () => {
    expect(SEED_THEMES.length).toBeGreaterThanOrEqual(6);
    expect(SEED_THEMES.filter((t) => !t.premium)).toHaveLength(2);
    expect(new Set(SEED_THEMES.map((t) => t.id)).size).toBe(SEED_THEMES.length);
  });

  it.each(SEED_THEMES.map((t) => [t.id, t] as const))("%s passes AA as designed and uses a listed font", (_, t) => {
    expect(resolveTheme(t.tokens).issues).toEqual([]);
    expect(SEED_FONTS).toContain(t.tokens.font);
    expect(t.id).toMatch(/^[A-Za-z0-9_-]{1,64}$/);
  });

  it("matches the shared cases file", () => {
    expect(Object.fromEntries(SEED_THEMES.map((t) => [t.id, t.tokens]))).toEqual(cases.themes);
  });
});
