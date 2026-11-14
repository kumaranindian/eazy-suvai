import { getFirestore } from "firebase-admin/firestore";
import { onDocumentUpdated } from "firebase-functions/v2/firestore";
import { onCall } from "firebase-functions/v2/https";

import { handleRestaurantUpdated } from "./on-restaurant-updated";
import { changeSlug as changeSlugImpl } from "./slug-change";

/**
 * Callable `{restaurantId, slug, dryRun?}`: changes the menu slug, keeping
 * the old one for redirects (M03, FR-092, FR-093). See {@link changeSlugImpl}.
 */
export const changeSlug = onCall(async (request) => changeSlugImpl(getFirestore(), request.auth, request.data));

/**
 * Trigger: keeps `nameLower` in sync and sets `pricesNeedReview` when the
 * currency changes after a publish (M03, FR-103).
 */
export const onRestaurantUpdated = onDocumentUpdated("restaurants/{rid}", async (event) => {
  const change = event.data;
  if (!change) return;
  await handleRestaurantUpdated(change.after.ref, change.before.data(), change.after.data());
});
