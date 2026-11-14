/**
 * Initial platform-managed dietary labels and item tags (FR-023, FR-033,
 * FR-104). `scripts/seed-platform.mjs` writes them to `dietaryLabels/{id}`
 * and `itemTags/{id}`; M11's admin screens manage them afterwards.
 *
 * `icon` is a key the apps map to a drawing (see `DietaryIcon` and
 * `TagIcon` in `packages/core/lib/src/menu/`), not a URL. `color` is the
 * symbol colour; text never relies on it (FR-023).
 */
export interface PlatformLabel {
  id: string;
  name: string;
  icon: string;
  color: string;
  sort: number;
  retired: boolean;
}

export const DIETARY_LABELS: readonly PlatformLabel[] = [
  { id: "vegetarian", name: "Vegetarian", icon: "veg", color: "#2E7D32", sort: 10, retired: false },
  { id: "non-vegetarian", name: "Non-vegetarian", icon: "nonVeg", color: "#8B4513", sort: 20, retired: false },
  { id: "vegan", name: "Vegan", icon: "vegan", color: "#3B7A20", sort: 30, retired: false },
  { id: "contains-egg", name: "Contains egg", icon: "egg", color: "#B26A00", sort: 40, retired: false },
];

export const ITEM_TAGS: readonly PlatformLabel[] = [
  { id: "spicy", name: "Spicy", icon: "spicy", color: "#C62828", sort: 10, retired: false },
  { id: "bestseller", name: "Bestseller", icon: "bestseller", color: "#A8550A", sort: 20, retired: false },
  { id: "chefs-special", name: "Chef's special", icon: "chefsSpecial", color: "#6A1B9A", sort: 30, retired: false },
  { id: "new", name: "New", icon: "new", color: "#1565C0", sort: 40, retired: false },
];
