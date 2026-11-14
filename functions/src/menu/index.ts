import { getFirestore } from "firebase-admin/firestore";
import { onDocumentWritten } from "firebase-functions/v2/firestore";
import { onCall } from "firebase-functions/v2/https";

import * as impl from "./menu-callables";
import { handleMenuWrite, type MenuKind } from "./menu-triggers";

/** Callable: creates a category within the plan limit (M04, FR-015, FR-021). */
export const createCategory = onCall(async (request) => impl.createCategory(getFirestore(), request.auth, request.data));

/** Callable: creates an item within the plan limit (M04, FR-022, BR-004). */
export const createItem = onCall(async (request) => impl.createItem(getFirestore(), request.auth, request.data));

/** Callable: soft-deletes a category, moving or deleting its items (FR-018). */
export const deleteCategory = onCall(async (request) => impl.deleteCategory(getFirestore(), request.auth, request.data));

/** Callable: soft-deletes items (FR-024, FR-098). */
export const deleteItems = onCall(async (request) => impl.deleteItems(getFirestore(), request.auth, request.data));

/** Callable: moves items to another category (FR-097). */
export const moveItems = onCall(async (request) => impl.moveItems(getFirestore(), request.auth, request.data));

/** Callable: restores a soft-deleted category or item to the draft (FR-098). */
export const restoreDeleted = onCall(async (request) => impl.restoreDeleted(getFirestore(), request.auth, request.data));

function menuTrigger(kind: MenuKind) {
  return onDocumentWritten(`restaurants/{rid}/${kind}/{docId}`, async (event) => {
    const change = event.data;
    if (!change) return;
    await handleMenuWrite(
      getFirestore(),
      kind,
      event.params.rid,
      event.params.docId,
      change.before.exists ? change.before.data() : undefined,
      change.after.exists ? change.after.data() : undefined,
      new Date(event.time),
    );
  });
}

/** Trigger: keeps `counts.items`, `draftUpdatedAt` and `live/availability`. */
export const onItemWrite = menuTrigger("items");

/** Trigger: keeps `counts.categories` and `draftUpdatedAt`. */
export const onCategoryWrite = menuTrigger("categories");
