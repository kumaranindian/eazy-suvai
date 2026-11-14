import type { DocumentReference } from "firebase-admin/firestore";

type Data = Record<string, unknown>;

/**
 * Fields `onRestaurantUpdated` must change after an update of
 * `restaurants/{rid}`, or `null` when nothing is needed.
 *
 * - `pricesNeedReview: true` when `currency` changed and the menu has been
 *   published (`publishedVersion` not null). Prices are stored in minor
 *   units and are never converted (FR-103), so the owner must review them;
 *   M06 asks them to confirm before the next publish and clears the flag.
 * - `nameLower` follows `name`, for the admin search (M11).
 *
 * Returns only real differences, so the write it causes produces no
 * further patch (the trigger cannot loop).
 *
 * @param before Data before the update.
 * @param after Data after the update.
 * @return The patch, or null.
 */
export function restaurantUpdatePatch(before: Data | undefined, after: Data | undefined): Data | null {
  if (!before || !after) return null;
  const patch: Data = {};

  const currencyChanged =
    typeof before.currency === "string" && typeof after.currency === "string" && before.currency !== after.currency;
  const published = after.publishedVersion !== null && after.publishedVersion !== undefined;
  if (currencyChanged && published && after.pricesNeedReview !== true) {
    patch.pricesNeedReview = true;
  }

  if (typeof after.name === "string") {
    const lower = after.name.toLowerCase();
    if (after.nameLower !== lower) patch.nameLower = lower;
  }

  return Object.keys(patch).length === 0 ? null : patch;
}

/**
 * Applies [restaurantUpdatePatch] to the document.
 *
 * @param ref The restaurant document.
 * @param before Data before the update.
 * @param after Data after the update.
 * @return The patch written, or null.
 */
export async function handleRestaurantUpdated(
  ref: Pick<DocumentReference, "update">,
  before: Data | undefined,
  after: Data | undefined,
): Promise<Data | null> {
  const patch = restaurantUpdatePatch(before, after);
  if (!patch) return null;
  try {
    await ref.update(patch);
  } catch (e) {
    // Deleted meanwhile (account purge, M12): nothing to keep in sync.
    if ((e as { code?: unknown }).code === 5) return null;
    throw e;
  }
  return patch;
}
