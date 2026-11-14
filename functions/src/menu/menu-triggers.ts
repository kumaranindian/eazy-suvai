import { FieldValue, Timestamp, type Firestore } from "firebase-admin/firestore";

import { isLive } from "./menu-callables";

type Data = Record<string, unknown>;

export type MenuKind = "categories" | "items";

/** Fields whose change is not a draft change. `available` goes live at once
 * without a publish (FR-095, BR-018), so it does not make the draft differ
 * from the published menu. */
const NOT_DRAFT: ReadonlySet<string> = new Set(["available", "updatedAt"]);

/**
 * Deep equality for Firestore values (maps, arrays, Timestamps, primitives).
 *
 * @param a A value.
 * @param b Another value.
 * @return True when equal.
 */
export function sameValue(a: unknown, b: unknown): boolean {
  if (a === b) return true;
  if (a instanceof Timestamp || b instanceof Timestamp) {
    return a instanceof Timestamp && b instanceof Timestamp && a.isEqual(b);
  }
  if (Array.isArray(a) || Array.isArray(b)) {
    return Array.isArray(a) && Array.isArray(b) && a.length === b.length && a.every((v, i) => sameValue(v, b[i]));
  }
  if (a !== null && b !== null && typeof a === "object" && typeof b === "object") {
    const ka = Object.keys(a as Data);
    const kb = Object.keys(b as Data);
    return ka.length === kb.length && ka.every((k) => sameValue((a as Data)[k], (b as Data)[k]));
  }
  return false;
}

/**
 * Whether a write changed draft content: any create or delete, or a change
 * to a field other than `available` / `updatedAt`.
 *
 * @param before Data before the write.
 * @param after Data after the write.
 * @return True for a draft change.
 */
export function isDraftChange(before: Data | undefined, after: Data | undefined): boolean {
  if (!before || !after) return before !== after;
  const keys = new Set([...Object.keys(before), ...Object.keys(after)]);
  for (const k of keys) {
    if (NOT_DRAFT.has(k)) continue;
    if (!sameValue(before[k], after[k])) return true;
  }
  return false;
}

/** Whether a write changed `available` (including create and delete). */
export function isAvailabilityChange(before: Data | undefined, after: Data | undefined): boolean {
  return before?.available !== after?.available;
}

function millisOf(v: unknown): number | undefined {
  return v instanceof Timestamp ? v.toMillis() : undefined;
}

/**
 * Keeps the restaurant root in step with a category or item write
 * (`onCategoryWrite`, `onItemWrite`, M04):
 *
 * - `counts.{kind}`: recounted when a document starts or stops counting
 *   (created, soft-deleted, restored, removed). A recount, not an
 *   increment, so a retried event cannot drift the count. The callables set
 *   the same value in their own transaction; this catches everything else
 *   (console edits, M12 purges).
 * - `draftUpdatedAt`: set when draft content changed and the root does not
 *   already record a later change. Callables stamp it in the same commit,
 *   and a batch of reorders bumps it once.
 *
 * @param db Firestore.
 * @param kind `categories` or `items`.
 * @param restaurantId The restaurant.
 * @param before Data before the write.
 * @param after Data after the write.
 * @param eventTime When the write happened.
 * @return The patch written to the root, or null.
 */
export async function syncRestaurantRoot(
  db: Firestore,
  kind: MenuKind,
  restaurantId: string,
  before: Data | undefined,
  after: Data | undefined,
  eventTime: Date,
): Promise<Data | null> {
  const countChanged = isLive(before) !== isLive(after);
  const draftChanged = isDraftChange(before, after);
  if (!countChanged && !draftChanged) return null;

  const root = db.doc(`restaurants/${restaurantId}`);
  const rootSnap = await root.get();
  if (!rootSnap.exists) return null;
  const patch: Data = {};

  if (countChanged) {
    const counted = await root.collection(kind).where("deletedAt", "==", null).count().get();
    const n = counted.data().count;
    const counts = (rootSnap.get("counts") ?? {}) as Data;
    if (counts[kind] !== n) patch[`counts.${kind}`] = n;
  }
  if (draftChanged) {
    const changedAt = millisOf(after?.updatedAt) ?? eventTime.getTime();
    const recorded = millisOf(rootSnap.get("draftUpdatedAt")) ?? 0;
    if (recorded < changedAt) patch.draftUpdatedAt = FieldValue.serverTimestamp();
  }
  if (Object.keys(patch).length === 0) return null;
  try {
    await root.update(patch);
  } catch (e) {
    // Restaurant purged meanwhile (M12).
    if ((e as { code?: unknown }).code === 5) return null;
    throw e;
  }
  return patch;
}

/**
 * Writes the item's current availability to `restaurants/{rid}/live/
 * availability` (`{items: {iid: bool}, updatedAt}`), which the public menu
 * lays over the published version (FR-095, BR-018, AC-007).
 *
 * Reads the item inside a transaction instead of trusting the event, so two
 * quick toggles whose events arrive out of order still leave the latest
 * value. A removed item is taken out of the map.
 *
 * @param db Firestore.
 * @param restaurantId The restaurant.
 * @param itemId The item.
 * @return The value written, or null when the key was removed.
 */
export async function syncAvailability(db: Firestore, restaurantId: string, itemId: string): Promise<boolean | null> {
  const itemRef = db.doc(`restaurants/${restaurantId}/items/${itemId}`);
  const liveRef = db.doc(`restaurants/${restaurantId}/live/availability`);
  return db.runTransaction(async (tx) => {
    const snap = await tx.get(itemRef);
    const value = snap.exists ? snap.get("available") === true : null;
    tx.set(
      liveRef,
      {
        items: { [itemId]: value === null ? FieldValue.delete() : value },
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
    return value;
  });
}

/**
 * Handles one category or item write.
 *
 * @param db Firestore.
 * @param kind `categories` or `items`.
 * @param restaurantId From the path.
 * @param docId From the path.
 * @param before Data before.
 * @param after Data after.
 * @param eventTime The event time.
 */
export async function handleMenuWrite(
  db: Firestore,
  kind: MenuKind,
  restaurantId: string,
  docId: string,
  before: Data | undefined,
  after: Data | undefined,
  eventTime: Date,
): Promise<void> {
  const tasks: Promise<unknown>[] = [syncRestaurantRoot(db, kind, restaurantId, before, after, eventTime)];
  if (kind === "items" && isAvailabilityChange(before, after)) {
    tasks.push(syncAvailability(db, restaurantId, docId));
  }
  await Promise.all(tasks);
}
