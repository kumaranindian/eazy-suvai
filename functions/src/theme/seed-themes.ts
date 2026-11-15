/**
 * Initial platform themes and fonts (M05, FR-056, FR-059).
 * `scripts/seed-platform.mjs` writes them to `themes/{id}` and
 * `config/platform.fonts`; M11's admin screens manage them afterwards.
 *
 * Every theme passes WCAG AA without adjustment in its own mode
 * (`theme.test.ts` checks it). `premium: false` themes are the ones the
 * Free plan gets (M10 enforces it through `plans/{id}.limits.themeIds`).
 */
import type { ThemeTokens } from "./resolve";

export interface PlatformTheme {
  id: string;
  name: string;
  premium: boolean;
  sort: number;
  retired: boolean;
  tokens: ThemeTokens;
}

export const SEED_THEMES: readonly PlatformTheme[] = [
  {
    id: "saffron",
    name: "Saffron",
    premium: false,
    sort: 10,
    retired: false,
    tokens: {
      primary: "#A8550A",
      secondary: "#3B7A20",
      background: "#FFF8EE",
      surface: "#FFFFFF",
      text: "#2B2B2B",
      font: "Poppins",
      layout: "list",
      cardLayout: "image-left",
      mode: "light",
    },
  },
  {
    id: "minimal",
    name: "Minimal",
    premium: false,
    sort: 20,
    retired: false,
    tokens: {
      primary: "#222222",
      secondary: "#5C5C5C",
      background: "#FFFFFF",
      surface: "#F6F6F6",
      text: "#1A1A1A",
      font: "Inter",
      layout: "list",
      cardLayout: "compact",
      mode: "light",
    },
  },
  {
    id: "banana-leaf",
    name: "Banana Leaf",
    premium: true,
    sort: 30,
    retired: false,
    tokens: {
      primary: "#2E6B1F",
      secondary: "#B35C00",
      background: "#F3F8EC",
      surface: "#FFFFFF",
      text: "#1F2A1A",
      font: "Nunito",
      layout: "list",
      cardLayout: "image-left",
      mode: "light",
    },
  },
  {
    id: "midnight",
    name: "Midnight",
    premium: true,
    sort: 40,
    retired: false,
    tokens: {
      primary: "#FFB454",
      secondary: "#8FCB6B",
      background: "#121417",
      surface: "#1E2126",
      text: "#F2EDE8",
      font: "Inter",
      layout: "grid",
      cardLayout: "image-top",
      mode: "dark",
    },
  },
  {
    id: "cafe-cream",
    name: "Café Cream",
    premium: true,
    sort: 50,
    retired: false,
    tokens: {
      primary: "#7A4A2A",
      secondary: "#9C5518",
      background: "#F7F0E6",
      surface: "#FFFBF5",
      text: "#3A2A20",
      font: "Lora",
      layout: "list",
      cardLayout: "image-left",
      mode: "light",
    },
  },
  {
    id: "coastal",
    name: "Coastal",
    premium: true,
    sort: 60,
    retired: false,
    tokens: {
      primary: "#0B6580",
      secondary: "#F4A259",
      background: "#F2F8FA",
      surface: "#FFFFFF",
      text: "#12303A",
      font: "Playfair Display",
      layout: "grid",
      cardLayout: "image-top",
      mode: "light",
    },
  },
];

/**
 * `config/platform.fonts` (FR-055, FR-059): Google Fonts family names.
 * Tamil and Arabic menus (later phases) add `Noto Sans Tamil` and
 * `Noto Sans Arabic`. Keep `MenuFonts.defaults` in core in sync.
 */
export const SEED_FONTS: readonly string[] = ["Poppins", "Inter", "Lora", "Nunito", "Playfair Display", "Noto Sans"];
