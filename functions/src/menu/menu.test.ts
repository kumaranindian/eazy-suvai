import { Timestamp } from "firebase-admin/firestore";

import { appErrorCodeOf } from "../lib/errors";
import { DEFAULT_PLAN_LIMITS, getPlanLimits, planLimitsFrom } from "../lib/plan-limits";
import { parseInput } from "../lib/validation";
import {
  assertWithinLimit,
  isLive,
  nextSequence,
  normalizeConfirmation,
  withinRestoreWindow,
} from "./menu-callables";
import { isAvailabilityChange, isDraftChange, sameValue } from "./menu-triggers";
import {
  createCategorySchema,
  createItemSchema,
  deleteCategorySchema,
  deleteItemsSchema,
  MENU_LIMITS,
  moveItemsSchema,
  restoreDeletedSchema,
} from "./schemas";
import { DIETARY_LABELS, ITEM_TAGS } from "./seed-data";

function codeOf(fn: () => unknown): string | undefined {
  try {
    fn();
  } catch (e) {
    return appErrorCodeOf(e);
  }
  throw new Error("expected a throw");
}

describe("plan limits (FR-078, BR-011)", () => {
  it("falls back to the FRD §4.11 limits when the plan document is missing", () => {
    expect(planLimitsFrom("free", undefined)).toEqual({ maxItems: 50, maxCategories: 10 });
    expect(planLimitsFrom("pro", undefined)).toEqual({ maxItems: 500, maxCategories: null });
    expect(planLimitsFrom("mystery", undefined)).toEqual(DEFAULT_PLAN_LIMITS.free);
  });

  it("reads plans/{id}.limits; null or negative means unlimited", () => {
    expect(planLimitsFrom("free", { limits: { maxItems: 20, maxCategories: 3 } })).toEqual({
      maxItems: 20,
      maxCategories: 3,
    });
    expect(planLimitsFrom("pro", { limits: { maxItems: -1, maxCategories: null } })).toEqual({
      maxItems: null,
      maxCategories: null,
    });
    // A malformed value keeps the default rather than becoming unlimited.
    expect(planLimitsFrom("free", { limits: { maxItems: "lots" } })).toEqual({ maxItems: 50, maxCategories: 10 });
  });

  it("getPlanLimits reads the plan's path and defaults bad ids to free", async () => {
    const reads: string[] = [];
    const read = async (path: string) => {
      reads.push(path);
      return path === "plans/pro" ? { limits: { maxItems: 600 } } : undefined;
    };
    expect(await getPlanLimits(read, "pro")).toEqual({ maxItems: 600, maxCategories: null });
    expect(await getPlanLimits(read, "../x")).toEqual(DEFAULT_PLAN_LIMITS.free);
    expect(await getPlanLimits(read, undefined)).toEqual(DEFAULT_PLAN_LIMITS.free);
    expect(reads).toEqual(["plans/pro", "plans/free", "plans/free"]);
  });

  it("assertWithinLimit allows up to the limit and reports limit-reached past it", () => {
    const limits = { maxItems: 50, maxCategories: 10 };
    expect(() => assertWithinLimit("items", 49, 1, limits, "free")).not.toThrow();
    expect(codeOf(() => assertWithinLimit("items", 50, 1, limits, "free"))).toBe("limit-reached");
    expect(codeOf(() => assertWithinLimit("categories", 9, 2, limits, "free"))).toBe("limit-reached");
    expect(() => assertWithinLimit("categories", 1000, 1, { maxItems: 1, maxCategories: null }, "pro")).not.toThrow();
    try {
      assertWithinLimit("items", 50, 1, limits, "free");
    } catch (e) {
      expect((e as { details: unknown }).details).toEqual({ code: "limit-reached", limit: "items", max: 50, planId: "free" });
    }
  });
});

describe("menu helpers", () => {
  it("isLive: exists and not soft-deleted", () => {
    expect(isLive(undefined)).toBe(false);
    expect(isLive({ deletedAt: null })).toBe(true);
    expect(isLive({})).toBe(true);
    expect(isLive({ deletedAt: Timestamp.now() })).toBe(false);
  });

  it("nextSequence leaves gaps of 1000 after the largest", () => {
    expect(nextSequence([])).toBe(1000);
    expect(nextSequence([{ sequence: 1000 }, { sequence: 3000 }, { sequence: 2000 }])).toBe(4000);
    // After a drag left an in-between value, the next one is still on the grid.
    expect(nextSequence([{ sequence: 1500 }])).toBe(2000);
    expect(nextSequence([{ name: "no sequence" }])).toBe(1000);
  });

  it("withinRestoreWindow: 30 days from deletedAt (FR-098)", () => {
    const now = new Date("2026-11-14T10:00:00Z");
    const daysAgo = (d: number) => Timestamp.fromMillis(now.getTime() - d * 86_400_000);
    expect(withinRestoreWindow(daysAgo(1), now)).toBe(true);
    expect(withinRestoreWindow(daysAgo(30), now)).toBe(true);
    expect(withinRestoreWindow(daysAgo(30.01), now)).toBe(false);
    expect(withinRestoreWindow(null, now)).toBe(false);
  });

  it("normalizeConfirmation ignores case and extra spaces", () => {
    expect(normalizeConfirmation("  Main   Course ")).toBe(normalizeConfirmation("main course"));
    expect(normalizeConfirmation("Main Course")).not.toBe(normalizeConfirmation("Main Courses"));
  });
});

describe("menu input schemas", () => {
  const base = { restaurantId: "rest_1" };

  it("createCategory: trims, applies FR-016 limits and defaults", () => {
    expect(parseInput(createCategorySchema, { ...base, name: "  Starters " })).toEqual({
      ...base,
      name: "Starters",
      description: "",
      active: true,
    });
    const at = (n: number) => "x".repeat(n);
    expect(() => parseInput(createCategorySchema, { ...base, name: at(MENU_LIMITS.categoryName) })).not.toThrow();
    expect(codeOf(() => parseInput(createCategorySchema, { ...base, name: at(61) }))).toBe("invalid-input");
    expect(codeOf(() => parseInput(createCategorySchema, { ...base, name: "   " }))).toBe("invalid-input");
    expect(codeOf(() => parseInput(createCategorySchema, { ...base, name: "A", description: at(251) }))).toBe(
      "invalid-input",
    );
    expect(codeOf(() => parseInput(createCategorySchema, { ...base, name: "A", sequence: 1 }))).toBe("invalid-input");
  });

  it("createItem: FR-022 fields, integer minor-unit prices (BR-019)", () => {
    const item = { ...base, categoryId: "c1", name: "Masala dosa", priceMinor: 1250, dietaryLabelId: "vegetarian" };
    expect(parseInput(createItemSchema, { ...item, tagIds: ["spicy", "spicy", "new"] })).toEqual({
      ...item,
      description: "",
      tagIds: ["spicy", "new"],
      available: true,
      featured: false,
    });
    for (const bad of [
      { priceMinor: 12.5 },
      { priceMinor: -1 },
      { priceMinor: "1250" },
      { priceMinor: MENU_LIMITS.maxPriceMinor + 1 },
      { name: "x".repeat(81) },
      { description: "x".repeat(501) },
      { dietaryLabelId: undefined },
      { categoryId: "a/b" },
      { tagIds: Array.from({ length: 11 }, (_, i) => `t${i}`) },
      { hiddenOverLimit: true },
    ]) {
      expect(codeOf(() => parseInput(createItemSchema, { ...item, ...bad }))).toBe("invalid-input");
    }
    expect(parseInput(createItemSchema, { ...item, priceMinor: 0 }).priceMinor).toBe(0);
  });

  it("deleteCategory, deleteItems, moveItems and restoreDeleted", () => {
    expect(parseInput(deleteCategorySchema, { ...base, categoryId: "c1", mode: "move", targetCategoryId: "c2" }))
      .toBeTruthy();
    expect(codeOf(() => parseInput(deleteCategorySchema, { ...base, categoryId: "c1", mode: "purge" }))).toBe(
      "invalid-input",
    );
    expect(parseInput(deleteItemsSchema, { ...base, itemIds: ["a", "a", "b"] }).itemIds).toEqual(["a", "b"]);
    expect(codeOf(() => parseInput(deleteItemsSchema, { ...base, itemIds: [] }))).toBe("invalid-input");
    expect(codeOf(() => parseInput(moveItemsSchema, { ...base, itemIds: ["a"] }))).toBe("invalid-input");
    expect(
      codeOf(() =>
        parseInput(moveItemsSchema, {
          ...base,
          itemIds: Array.from({ length: 501 }, (_, i) => `i${i}`),
          targetCategoryId: "c1",
        }),
      ),
    ).toBe("invalid-input");
    expect(parseInput(restoreDeletedSchema, { ...base, kind: "item", id: "i1", targetCategoryId: "c2" })).toBeTruthy();
    expect(codeOf(() => parseInput(restoreDeletedSchema, { ...base, kind: "theme", id: "x" }))).toBe("invalid-input");
  });
});

describe("trigger change detection", () => {
  const item = { name: "Dosa", priceMinor: 100, tagIds: ["spicy"], available: true, updatedAt: Timestamp.fromMillis(1) };

  it("sameValue compares maps, arrays and timestamps", () => {
    expect(sameValue({ a: [1, { b: 2 }] }, { a: [1, { b: 2 }] })).toBe(true);
    expect(sameValue({ a: [1, 2] }, { a: [2, 1] })).toBe(false);
    expect(sameValue(Timestamp.fromMillis(5), Timestamp.fromMillis(5))).toBe(true);
    expect(sameValue(Timestamp.fromMillis(5), null)).toBe(false);
    expect(sameValue({ a: 1 }, { a: 1, b: undefined })).toBe(false);
  });

  it("an availability-only change is not a draft change (BR-018)", () => {
    const toggled = { ...item, available: false, updatedAt: Timestamp.fromMillis(2) };
    expect(isDraftChange(item, toggled)).toBe(false);
    expect(isAvailabilityChange(item, toggled)).toBe(true);
  });

  it("content changes, creates and deletes are draft changes", () => {
    expect(isDraftChange(item, { ...item, priceMinor: 120 })).toBe(true);
    expect(isDraftChange(item, { ...item, tagIds: [] })).toBe(true);
    expect(isDraftChange(undefined, item)).toBe(true);
    expect(isDraftChange(item, undefined)).toBe(true);
    expect(isDraftChange(undefined, undefined)).toBe(false);
    expect(isAvailabilityChange(undefined, item)).toBe(true);
    expect(isAvailabilityChange(item, { ...item, name: "x" })).toBe(false);
  });
});

describe("seed data (FR-023, FR-033)", () => {
  it("has the four dietary classifications and four tags with distinct ids and sort orders", () => {
    expect(DIETARY_LABELS.map((l) => l.name)).toEqual(["Vegetarian", "Non-vegetarian", "Vegan", "Contains egg"]);
    expect(ITEM_TAGS.map((t) => t.name)).toEqual(["Spicy", "Bestseller", "Chef's special", "New"]);
    for (const list of [DIETARY_LABELS, ITEM_TAGS]) {
      expect(new Set(list.map((l) => l.id)).size).toBe(list.length);
      expect(new Set(list.map((l) => l.sort)).size).toBe(list.length);
      for (const l of list) {
        expect(l.id).toMatch(/^[a-z-]+$/);
        expect(l.color).toMatch(/^#[0-9A-F]{6}$/);
      }
    }
  });
});
