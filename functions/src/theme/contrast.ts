/**
 * WCAG 2.1 contrast helpers (M05, FR-060). The Dart copy is
 * `packages/core/lib/src/theme/contrast.dart`; both are tested against
 * `contrast-cases.json`, so change them together.
 *
 * Colours are `#RRGGBB` strings (upper case when produced here).
 */

/** WCAG 2.1 AA for normal-size text. */
export const AA_TEXT = 4.5;

/** The preferred readable text colours (FR-060: "near-black or white"). */
export const NEAR_BLACK = "#1A1A1A";
export const WHITE = "#FFFFFF";
const BLACK = "#000000";

const HEX = /^#?([0-9a-fA-F]{6})$/;

/** `#RRGGBB` in upper case, or null when [value] is not a 6-digit hex colour. */
export function normalizeHex(value: unknown): string | null {
  if (typeof value !== "string") return null;
  const m = HEX.exec(value.trim());
  return m ? `#${m[1].toUpperCase()}` : null;
}

function channels(hex: string): [number, number, number] {
  const h = normalizeHex(hex);
  if (h === null) throw new Error(`Not a hex colour: ${hex}`);
  const n = parseInt(h.slice(1), 16);
  return [(n >> 16) & 0xff, (n >> 8) & 0xff, n & 0xff];
}

function toHex(r: number, g: number, b: number): string {
  return `#${[r, g, b].map((c) => c.toString(16).padStart(2, "0")).join("")}`.toUpperCase();
}

function linear(c: number): number {
  const s = c / 255;
  return s <= 0.03928 ? s / 12.92 : Math.pow((s + 0.055) / 1.055, 2.4);
}

/** WCAG relative luminance, 0 (black) to 1 (white). */
export function relativeLuminance(hex: string): number {
  const [r, g, b] = channels(hex);
  return 0.2126 * linear(r) + 0.7152 * linear(g) + 0.0722 * linear(b);
}

/** WCAG contrast ratio of two colours, 1 to 21. Order does not matter. */
export function contrastRatio(a: string, b: string): number {
  const la = relativeLuminance(a);
  const lb = relativeLuminance(b);
  return (Math.max(la, lb) + 0.05) / (Math.min(la, lb) + 0.05);
}

/** Linear blend in sRGB: t = 0 gives [a], t = 1 gives [b]. */
export function mix(a: string, b: string, t: number): string {
  const ca = channels(a);
  const cb = channels(b);
  const c = ca.map((v, i) => Math.round(v + (cb[i] - v) * t));
  return toHex(c[0], c[1], c[2]);
}

/**
 * The better of near-black and white for text on [background]; pure black
 * or white when neither reaches AA, which always does (≥ 4.58:1).
 */
export function readableTextOn(background: string): string {
  const dark = contrastRatio(NEAR_BLACK, background);
  const light = contrastRatio(WHITE, background);
  if (Math.max(dark, light) >= AA_TEXT) return dark >= light ? NEAR_BLACK : WHITE;
  return contrastRatio(BLACK, background) >= light ? BLACK : WHITE;
}

/**
 * [color] if it reaches AA on every one of [backgrounds]; otherwise [color]
 * blended toward [fallback] in steps of 10 % until it does (the fallback
 * itself must pass).
 */
export function ensureContrast(color: string, backgrounds: string[], fallback: string): string {
  for (let step = 0; step <= 10; step++) {
    const c = step === 0 ? normalizeHex(color)! : mix(color, fallback, step / 10);
    if (backgrounds.every((bg) => contrastRatio(c, bg) >= AA_TEXT)) return c;
  }
  return normalizeHex(fallback)!;
}
