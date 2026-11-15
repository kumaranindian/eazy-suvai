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

// App Check (M13): every callable refuses calls without a valid App Check
// token when ENFORCE_APP_CHECK=true. It is set per project in
// functions/.env.<projectId> (true for prod); the emulators and dev leave it
// off. HTTP functions (renderMenu, collectEvent) are public and unaffected.
setGlobalOptions({
  region: REGION,
  maxInstances: 10,
  enforceAppCheck: process.env.ENFORCE_APP_CHECK === "true",
});
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
export { discardDraft, previewMenu, publishMenu, rollbackMenu } from "./publishing";
export { renderMenu } from "./public";
export { collectEvent } from "./analytics";
export {
  adminListUpgradeRequests,
  changeSubscription,
  closeUpgradeRequest,
  recordPaymentAndActivate,
  requestUpgrade,
  setHiddenOverLimit,
  subscriptionDaily,
} from "./subscriptions";
export {
  adminDashboard,
  adminGetRestaurant,
  adminListAdmins,
  adminListCatalog,
  adminSearchRestaurants,
  onRestaurantStats,
  recomputePlatformStats,
  setAdminRole,
  setAnnouncement,
  setRestaurantStatus,
  updatePlatformConfig,
  upsertLabel,
  upsertPlan,
  upsertTheme,
} from "./admin";
export { adminListAuditLogs, exportMenu, purgeDaily, requestAccountDeletion } from "./lifecycle";
