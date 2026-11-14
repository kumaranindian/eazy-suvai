import { z } from "zod";

/**
 * Field limits for menu content (FR-016, FR-022). Keep in sync with
 * `MenuLimits` in `packages/core/lib/src/menu/menu_models.dart` and the
 * category and item rules in `firestore.rules`.
 */
export const MENU_LIMITS = {
  categoryName: 60,
  categoryDescription: 250,
  itemName: 80,
  itemDescription: 500,
  /** 999,999,999 minor units: INR 9,999,999.99 or KWD 999,999.999. */
  maxPriceMinor: 999_999_999,
  maxTags: 10,
  /** Items handled by one bulk call (Pro allows 500 items). */
  maxBulk: 500,
} as const;

/** New documents go after the last one, this far apart, so a drag only
 * rewrites the moved document until a gap runs out (M04 plan). */
export const SEQUENCE_GAP = 1000;

/** Soft-deleted content can be restored for this long (FR-098, §7.7). */
export const RESTORE_DAYS = 30;

const docId = z
  .string()
  .min(1)
  .max(128)
  .regex(/^[A-Za-z0-9_-]+$/);

const uniqueIds = (max: number) =>
  z
    .array(docId)
    .max(max)
    .transform((ids) => [...new Set(ids)]);

export const createCategorySchema = z
  .object({
    restaurantId: docId,
    name: z.string().trim().min(1).max(MENU_LIMITS.categoryName),
    description: z.string().trim().max(MENU_LIMITS.categoryDescription).default(""),
    active: z.boolean().default(true),
  })
  .strict();

export const createItemSchema = z
  .object({
    restaurantId: docId,
    categoryId: docId,
    name: z.string().trim().min(1).max(MENU_LIMITS.itemName),
    description: z.string().trim().max(MENU_LIMITS.itemDescription).default(""),
    priceMinor: z.number().int().min(0).max(MENU_LIMITS.maxPriceMinor),
    dietaryLabelId: docId,
    tagIds: uniqueIds(MENU_LIMITS.maxTags).default([]),
    available: z.boolean().default(true),
    featured: z.boolean().default(false),
  })
  .strict();

export const deleteCategorySchema = z
  .object({
    restaurantId: docId,
    categoryId: docId,
    /** What happens to the category's items (FR-018). Ignored when empty. */
    mode: z.enum(["move", "deleteAll"]),
    /** Required for `move` when the category has items. */
    targetCategoryId: docId.optional(),
    /** The category name typed by the owner; required for `deleteAll`
     * when the category has items. */
    confirmName: z.string().max(200).optional(),
  })
  .strict();

export const deleteItemsSchema = z
  .object({
    restaurantId: docId,
    itemIds: uniqueIds(MENU_LIMITS.maxBulk).pipe(z.array(docId).min(1)),
  })
  .strict();

export const moveItemsSchema = z
  .object({
    restaurantId: docId,
    /** In the order they should appear at the end of the target. */
    itemIds: uniqueIds(MENU_LIMITS.maxBulk).pipe(z.array(docId).min(1)),
    targetCategoryId: docId,
  })
  .strict();

export const restoreDeletedSchema = z
  .object({
    restaurantId: docId,
    kind: z.enum(["category", "item"]),
    id: docId,
    /** Item only: restore into this category instead of its own (needed
     * when its own category is deleted). */
    targetCategoryId: docId.optional(),
  })
  .strict();
