import {
  FieldValue,
  Timestamp,
  type CollectionReference,
  type DocumentSnapshot,
  type Firestore,
  type QueryDocumentSnapshot,
  type Transaction,
} from "firebase-admin/firestore";

import { assertOwner, type CallerAuth , assertSignedIn } from "../lib/auth";
import { appError } from "../lib/errors";
import { getPlanLimits, type PlanLimits } from "../lib/plan-limits";
import { parseInput } from "../lib/validation";
import {
  createCategorySchema,
  createItemSchema,
  deleteCategorySchema,
  deleteItemsSchema,
  moveItemsSchema,
  restoreDeletedSchema,
  RESTORE_DAYS,
  SEQUENCE_GAP,
} from "./schemas";

type Data = Record<string, unknown>;

/** Options shared by the menu callables (tests override the clock). */
export interface MenuCallOptions {
  now?: Date;
}

/** True for a document that exists and is not soft-deleted. */
export function isLive(data: Data | undefined): boolean {
  return data !== undefined && (data.deletedAt === null || data.deletedAt === undefined);
}

/**
 * The `sequence` for a document added after [docs]: the largest sequence
 * plus [SEQUENCE_GAP] (deleted documents included, so a restore cannot
 * collide with a newer one).
 *
 * @param docs Existing documents' data.
 * @return The next sequence.
 */
export function nextSequence(docs: readonly Data[]): number {
  let max = 0;
  for (const d of docs) {
    if (typeof d.sequence === "number" && d.sequence > max) max = d.sequence;
  }
  return Math.floor(max / SEQUENCE_GAP) * SEQUENCE_GAP + SEQUENCE_GAP;
}

/**
 * Throws `limit-reached` when [current] + [adding] exceeds the plan limit
 * (BR-011, FR-021). Details carry `{limit, max, planId}` for the app's
 * upgrade prompt.
 *
 * @param kind Which limit.
 * @param current Non-deleted documents now.
 * @param adding Documents the call adds.
 * @param limits The plan's limits.
 * @param planId The plan, for the message.
 */
export function assertWithinLimit(
  kind: "items" | "categories",
  current: number,
  adding: number,
  limits: PlanLimits,
  planId: string,
): void {
  const max = kind === "items" ? limits.maxItems : limits.maxCategories;
  if (max !== null && current + adding > max) {
    throw appError("limit-reached", `Plan limit of ${max} ${kind} reached.`, { limit: kind, max, planId });
  }
}

/**
 * Whether a soft-deleted document can still be restored (FR-098: 30 days).
 *
 * @param deletedAt The `deletedAt` value.
 * @param now The current time.
 * @return True inside the window.
 */
export function withinRestoreWindow(deletedAt: unknown, now: Date): boolean {
  if (!(deletedAt instanceof Timestamp)) return false;
  return now.getTime() - deletedAt.toMillis() <= RESTORE_DAYS * 24 * 60 * 60 * 1000;
}

/** Lower-cased, trimmed, inner spaces collapsed: for the typed confirmation. */
export function normalizeConfirmation(text: string): string {
  return text.trim().replace(/\s+/g, " ").toLowerCase();
}

function dataOf(snap: DocumentSnapshot): Data | undefined {
  return snap.exists ? (snap.data() as Data) : undefined;
}

async function liveCount(tx: Transaction, col: CollectionReference): Promise<number> {
  const snap = await tx.get(col.where("deletedAt", "==", null).count());
  return snap.data().count;
}

function bySequence(a: QueryDocumentSnapshot, b: QueryDocumentSnapshot): number {
  const sa = (a.get("sequence") as number | undefined) ?? 0;
  const sb = (b.get("sequence") as number | undefined) ?? 0;
  return sa - sb || a.id.localeCompare(b.id);
}

function refs(db: Firestore, restaurantId: string) {
  const root = db.doc(`restaurants/${restaurantId}`);
  return {
    root,
    categories: root.collection("categories"),
    items: root.collection("items"),
  };
}

async function limitsFor(tx: Transaction, db: Firestore, restaurant: Data | undefined) {
  const planId = typeof restaurant?.planId === "string" ? restaurant.planId : "free";
  const limits = await getPlanLimits(async (path) => dataOf(await tx.get(db.doc(path))), planId);
  return { planId, limits };
}

/**
 * Callable `createCategory` (FR-015, FR-016, FR-021).
 *
 * Checks the plan's category limit inside a transaction that also writes the
 * restaurant root, so two devices creating at once cannot both pass the
 * limit. The category goes after the last one.
 *
 * @param db Firestore.
 * @param auth The caller.
 * @param data `{restaurantId, name, description?, active?}`.
 * @return `{id, sequence}`.
 */
export async function createCategory(
  db: Firestore,
  auth: CallerAuth | undefined | null,
  data: unknown,
): Promise<{ id: string; sequence: number }> {
  assertSignedIn(auth); // before input checks: anonymous callers learn nothing (M13)
  const input = parseInput(createCategorySchema, data);
  const { restaurantId } = await assertOwner(auth, input.restaurantId, { db });
  const { root, categories, items } = refs(db, restaurantId);
  const ref = categories.doc();

  return db.runTransaction(async (tx) => {
    const restaurant = dataOf(await tx.get(root));
    const { planId, limits } = await limitsFor(tx, db, restaurant);
    const all = await tx.get(categories);
    const current = all.docs.filter((d) => isLive(d.data())).length;
    assertWithinLimit("categories", current, 1, limits, planId);
    const itemCount = await liveCount(tx, items);

    const sequence = nextSequence(all.docs.map((d) => d.data()));
    const now = FieldValue.serverTimestamp();
    tx.create(ref, {
      name: input.name,
      description: input.description,
      image: null,
      sequence,
      active: input.active,
      deletedAt: null,
      createdAt: now,
      updatedAt: now,
    });
    tx.update(root, {
      "counts.categories": current + 1,
      "counts.items": itemCount,
      "draftUpdatedAt": now,
    });
    return { id: ref.id, sequence };
  });
}

/**
 * Callable `createItem` (FR-022, FR-023, FR-033, BR-004, BR-011).
 *
 * The category must exist and not be deleted; the dietary label and tags
 * must exist and not be retired (FR-104). Checks the plan's item limit in
 * the same transaction as the write. The item goes after the last item of
 * its category.
 *
 * @param db Firestore.
 * @param auth The caller.
 * @param data See `createItemSchema`.
 * @return `{id, sequence}`.
 */
export async function createItem(
  db: Firestore,
  auth: CallerAuth | undefined | null,
  data: unknown,
): Promise<{ id: string; sequence: number }> {
  assertSignedIn(auth); // before input checks: anonymous callers learn nothing (M13)
  const input = parseInput(createItemSchema, data);
  const { restaurantId } = await assertOwner(auth, input.restaurantId, { db });
  const { root, categories, items } = refs(db, restaurantId);
  const ref = items.doc();

  return db.runTransaction(async (tx) => {
    const [rootSnap, categorySnap, labelSnap, ...tagSnaps] = await tx.getAll(
      root,
      categories.doc(input.categoryId),
      db.doc(`dietaryLabels/${input.dietaryLabelId}`),
      ...input.tagIds.map((id) => db.doc(`itemTags/${id}`)),
    );
    const category = dataOf(categorySnap);
    if (!category) throw appError("not-found", "Category not found.", { field: "categoryId" });
    if (!isLive(category)) throw appError("category-deleted", "Category is deleted.");
    const label = dataOf(labelSnap);
    if (!label || label.retired === true) {
      throw appError("invalid-input", "Unknown dietary label.", { field: "dietaryLabelId" });
    }
    if (tagSnaps.some((s) => !s.exists || s.get("retired") === true)) {
      throw appError("invalid-input", "Unknown tag.", { field: "tagIds" });
    }

    const { planId, limits } = await limitsFor(tx, db, dataOf(rootSnap));
    const current = await liveCount(tx, items);
    assertWithinLimit("items", current, 1, limits, planId);
    const inCategory = await tx.get(items.where("categoryId", "==", input.categoryId));

    const sequence = nextSequence(inCategory.docs.map((d) => d.data()));
    const now = FieldValue.serverTimestamp();
    tx.create(ref, {
      categoryId: input.categoryId,
      name: input.name,
      description: input.description,
      image: null,
      priceMinor: input.priceMinor,
      dietaryLabelId: input.dietaryLabelId,
      tagIds: input.tagIds,
      available: input.available,
      featured: input.featured,
      sequence,
      hiddenOverLimit: false,
      deletedAt: null,
      deletedWith: null,
      createdAt: now,
      updatedAt: now,
    });
    tx.update(root, { "counts.items": current + 1, "draftUpdatedAt": now });
    return { id: ref.id, sequence };
  });
}

/**
 * Callable `deleteCategory` (FR-018, FR-098, AC-027). Soft-deletes the
 * category. When it still has items, `mode` decides:
 *
 * - `move`: the items go to the end of `targetCategoryId`, in their order;
 * - `deleteAll`: the items are soft-deleted with `deletedWith: categoryId`
 *   (restoring the category brings them back). `confirmName` must match the
 *   category name (case and extra spaces ignored).
 *
 * @param db Firestore.
 * @param auth The caller.
 * @param data See `deleteCategorySchema`.
 * @return How many items were moved or deleted.
 */
export async function deleteCategory(
  db: Firestore,
  auth: CallerAuth | undefined | null,
  data: unknown,
): Promise<{ moved: number; deleted: number }> {
  assertSignedIn(auth); // before input checks: anonymous callers learn nothing (M13)
  const input = parseInput(deleteCategorySchema, data);
  const { restaurantId } = await assertOwner(auth, input.restaurantId, { db });
  const { root, categories, items } = refs(db, restaurantId);
  const categoryRef = categories.doc(input.categoryId);

  return db.runTransaction(async (tx) => {
    const [categorySnap] = await tx.getAll(categoryRef);
    const category = dataOf(categorySnap);
    if (!isLive(category)) throw appError("not-found", "Category not found.");
    const all = await tx.get(categories);
    const inCategory = (await tx.get(items.where("categoryId", "==", input.categoryId))).docs
      .filter((d) => isLive(d.data()))
      .sort(bySequence);
    const itemCount = await liveCount(tx, items);

    let targetItems: Data[] = [];
    if (inCategory.length > 0) {
      if (input.mode === "move") {
        const target = all.docs.find((d) => d.id === input.targetCategoryId);
        if (!input.targetCategoryId || input.targetCategoryId === input.categoryId) {
          throw appError("invalid-input", "Choose another category.", { field: "targetCategoryId" });
        }
        if (!target) throw appError("not-found", "Target category not found.", { field: "targetCategoryId" });
        if (!isLive(target.data())) throw appError("category-deleted", "Target category is deleted.");
        targetItems = (await tx.get(items.where("categoryId", "==", input.targetCategoryId))).docs.map((d) =>
          d.data(),
        );
      } else {
        const name = String(category?.name ?? "");
        if (normalizeConfirmation(input.confirmName ?? "") !== normalizeConfirmation(name)) {
          throw appError("invalid-input", "Type the category name to confirm.", { field: "confirmName" });
        }
      }
    }

    const now = FieldValue.serverTimestamp();
    const moving = inCategory.length > 0 && input.mode === "move";
    let sequence = nextSequence(targetItems) - SEQUENCE_GAP;
    for (const item of inCategory) {
      if (moving) {
        sequence += SEQUENCE_GAP;
        tx.update(item.ref, { categoryId: input.targetCategoryId, sequence, updatedAt: now });
      } else {
        tx.update(item.ref, { deletedAt: now, deletedWith: input.categoryId, updatedAt: now });
      }
    }
    tx.update(categoryRef, { deletedAt: now, updatedAt: now });
    const liveCategories = all.docs.filter((d) => isLive(d.data())).length;
    const deleted = moving ? 0 : inCategory.length;
    tx.update(root, {
      "counts.categories": liveCategories - 1,
      "counts.items": itemCount - deleted,
      "draftUpdatedAt": now,
    });
    return { moved: moving ? inCategory.length : 0, deleted };
  });
}

/**
 * Callable `deleteItems` (FR-024, FR-098): soft-deletes items. Items that
 * are already deleted are skipped.
 *
 * @param db Firestore.
 * @param auth The caller.
 * @param data `{restaurantId, itemIds}`.
 * @return How many items were deleted.
 */
export async function deleteItems(
  db: Firestore,
  auth: CallerAuth | undefined | null,
  data: unknown,
): Promise<{ deleted: number }> {
  assertSignedIn(auth); // before input checks: anonymous callers learn nothing (M13)
  const input = parseInput(deleteItemsSchema, data);
  const { restaurantId } = await assertOwner(auth, input.restaurantId, { db });
  const { root, items } = refs(db, restaurantId);

  return db.runTransaction(async (tx) => {
    const snaps = await tx.getAll(...input.itemIds.map((id) => items.doc(id)));
    if (snaps.some((s) => !s.exists)) throw appError("not-found", "Item not found.");
    const itemCount = await liveCount(tx, items);
    const now = FieldValue.serverTimestamp();
    const live = snaps.filter((s) => isLive(dataOf(s)));
    for (const s of live) {
      tx.update(s.ref, { deletedAt: now, deletedWith: null, updatedAt: now });
    }
    if (live.length > 0) {
      tx.update(root, { "counts.items": itemCount - live.length, "draftUpdatedAt": now });
    }
    return { deleted: live.length };
  });
}

/**
 * Callable `moveItems` (FR-097): moves items, one or in bulk, to the end of
 * another category, in the order given. Items already there stay put.
 *
 * @param db Firestore.
 * @param auth The caller.
 * @param data `{restaurantId, itemIds, targetCategoryId}`.
 * @return How many items moved.
 */
export async function moveItems(
  db: Firestore,
  auth: CallerAuth | undefined | null,
  data: unknown,
): Promise<{ moved: number }> {
  assertSignedIn(auth); // before input checks: anonymous callers learn nothing (M13)
  const input = parseInput(moveItemsSchema, data);
  const { restaurantId } = await assertOwner(auth, input.restaurantId, { db });
  const { root, categories, items } = refs(db, restaurantId);

  return db.runTransaction(async (tx) => {
    const [targetSnap, ...snaps] = await tx.getAll(
      categories.doc(input.targetCategoryId),
      ...input.itemIds.map((id) => items.doc(id)),
    );
    const target = dataOf(targetSnap);
    if (!target) throw appError("not-found", "Target category not found.", { field: "targetCategoryId" });
    if (!isLive(target)) throw appError("category-deleted", "Target category is deleted.");
    if (snaps.some((s) => !isLive(dataOf(s)))) throw appError("not-found", "Item not found.");
    const targetItems = await tx.get(items.where("categoryId", "==", input.targetCategoryId));

    const now = FieldValue.serverTimestamp();
    let sequence = nextSequence(targetItems.docs.map((d) => d.data())) - SEQUENCE_GAP;
    let moved = 0;
    for (const s of snaps) {
      if (s.get("categoryId") === input.targetCategoryId) continue;
      sequence += SEQUENCE_GAP;
      moved++;
      tx.update(s.ref, { categoryId: input.targetCategoryId, sequence, updatedAt: now });
    }
    if (moved > 0) tx.update(root, { draftUpdatedAt: now });
    return { moved };
  });
}

/**
 * Callable `restoreDeleted` (FR-098, AC-028). Restores a soft-deleted
 * category or item, deleted at most 30 days ago, to the draft (not the live
 * menu).
 *
 * - A category goes back at the end of the list, with the items that were
 *   deleted together with it (`deletedWith`).
 * - An item goes back at the end of its category, or of `targetCategoryId`.
 *   If its own category is deleted and no target is given, the call fails
 *   with `category-deleted` (BR-004).
 *
 * Restoring counts against the plan limits like creating does.
 *
 * @param db Firestore.
 * @param auth The caller.
 * @param data See `restoreDeletedSchema`.
 * @param options Clock override.
 * @return How many categories and items came back.
 */
export async function restoreDeleted(
  db: Firestore,
  auth: CallerAuth | undefined | null,
  data: unknown,
  options: MenuCallOptions = {},
): Promise<{ categories: number; items: number; categoryId: string }> {
  assertSignedIn(auth); // before input checks: anonymous callers learn nothing (M13)
  const input = parseInput(restoreDeletedSchema, data);
  const { restaurantId } = await assertOwner(auth, input.restaurantId, { db });
  const { root, categories, items } = refs(db, restaurantId);
  const clock = options.now ?? new Date();

  return db.runTransaction(async (tx) => {
    const restaurant = dataOf(await tx.get(root));
    const { planId, limits } = await limitsFor(tx, db, restaurant);
    const allCategories = await tx.get(categories);
    const liveCategories = allCategories.docs.filter((d) => isLive(d.data())).length;
    const itemCount = await liveCount(tx, items);
    const now = FieldValue.serverTimestamp();

    if (input.kind === "category") {
      const category = allCategories.docs.find((d) => d.id === input.id);
      if (!category || isLive(category.data())) throw appError("not-found", "Nothing to restore.");
      if (!withinRestoreWindow(category.get("deletedAt"), clock)) {
        throw appError("not-found", "Deleted more than 30 days ago.", { reason: "expired" });
      }
      const withIt = (await tx.get(items.where("deletedWith", "==", input.id))).docs.filter(
        (d) => !isLive(d.data()) && withinRestoreWindow(d.get("deletedAt"), clock),
      );
      assertWithinLimit("categories", liveCategories, 1, limits, planId);
      assertWithinLimit("items", itemCount, withIt.length, limits, planId);

      tx.update(category.ref, {
        deletedAt: null,
        sequence: nextSequence(allCategories.docs.filter((d) => isLive(d.data())).map((d) => d.data())),
        updatedAt: now,
      });
      for (const item of withIt) {
        tx.update(item.ref, { deletedAt: null, deletedWith: null, categoryId: input.id, updatedAt: now });
      }
      tx.update(root, {
        "counts.categories": liveCategories + 1,
        "counts.items": itemCount + withIt.length,
        "draftUpdatedAt": now,
      });
      return { categories: 1, items: withIt.length, categoryId: input.id };
    }

    const [itemSnap] = await tx.getAll(items.doc(input.id));
    const item = dataOf(itemSnap);
    if (!item || isLive(item)) throw appError("not-found", "Nothing to restore.");
    if (!withinRestoreWindow(item.deletedAt, clock)) {
      throw appError("not-found", "Deleted more than 30 days ago.", { reason: "expired" });
    }
    const categoryId = input.targetCategoryId ?? String(item.categoryId ?? "");
    const category = allCategories.docs.find((d) => d.id === categoryId);
    if (!category || !isLive(category.data())) {
      throw appError("category-deleted", "Choose a category for this item.", { categoryId });
    }
    assertWithinLimit("items", itemCount, 1, limits, planId);
    const inCategory = await tx.get(items.where("categoryId", "==", categoryId));

    tx.update(itemSnap.ref, {
      deletedAt: null,
      deletedWith: null,
      categoryId,
      sequence: nextSequence(inCategory.docs.filter((d) => d.id !== input.id).map((d) => d.data())),
      updatedAt: now,
    });
    tx.update(root, { "counts.items": itemCount + 1, "draftUpdatedAt": now });
    return { categories: 0, items: 1, categoryId };
  });
}
