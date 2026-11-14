/**
 * EazySuvai Cloud Functions entry point.
 *
 * Every function runs in asia-south1 (architecture §1). Modules add their
 * exports here, for example `export { completeRegistration } from "./auth";`
 * (M01). See the inventory in docs/architecture.md §7.
 */
import { initializeApp } from "firebase-admin/app";
import { setGlobalOptions } from "firebase-functions/v2";

const REGION = "asia-south1";

setGlobalOptions({ region: REGION, maxInstances: 10 });
initializeApp();

// Shared helpers live in ./lib and are imported by each module directly.
// Do not export non-function values here: the deploy tool reads every export.

export { cleanupUnverifiedUsers, completeRegistration } from "./auth";
export { processImage } from "./media";
export { changeSlug, onRestaurantUpdated } from "./restaurant";
export {
  createCategory,
  createItem,
  deleteCategory,
  deleteItems,
  moveItems,
  onCategoryWrite,
  onItemWrite,
  restoreDeleted,
} from "./menu";
