import { getAuth } from "firebase-admin/auth";
import { getFirestore } from "firebase-admin/firestore";
import { onDocumentWritten } from "firebase-functions/v2/firestore";
import { onCall } from "firebase-functions/v2/https";

import * as admins from "./admins";
import * as catalog from "./catalog";
import * as restaurants from "./restaurants";
import * as stats from "./stats";

const db = () => getFirestore();

/** Trigger: keeps the `stats/platform` counters (FR-085). */
export const onRestaurantStats = onDocumentWritten("restaurants/{rid}", async (event) => {
  await stats.applyStatsDelta(db(), stats.statsDelta(event.data?.before.data(), event.data?.after.data()));
});

/** Callables (admin, TOTP; every change audit-logged, BR-014). */
export const adminDashboard = onCall(async (r) => admins.adminDashboard(db(), r.auth));
export const recomputePlatformStats = onCall({ timeoutSeconds: 300 }, async (r) => stats.recomputePlatformStats(db(), r.auth));
export const adminSearchRestaurants = onCall(async (r) => restaurants.adminSearchRestaurants(db(), r.auth, r.data));
export const adminGetRestaurant = onCall(async (r) => restaurants.adminGetRestaurant(db(), r.auth, r.data, { auth: getAuth() }));
export const setRestaurantStatus = onCall(async (r) => restaurants.setRestaurantStatus(db(), r.auth, r.data, { auth: getAuth() }));
export const setAdminRole = onCall(async (r) => admins.setAdminRole(db(), r.auth, r.data, { auth: getAuth() }));
export const adminListAdmins = onCall(async (r) => admins.adminListAdmins(db(), r.auth));
export const upsertPlan = onCall({ timeoutSeconds: 300 }, async (r) => catalog.upsertPlan(db(), r.auth, r.data));
export const upsertLabel = onCall(async (r) => catalog.upsertLabel(db(), r.auth, r.data));
export const upsertTheme = onCall(async (r) => catalog.upsertTheme(db(), r.auth, r.data));
export const updatePlatformConfig = onCall(async (r) => catalog.updatePlatformConfig(db(), r.auth, r.data));
export const setAnnouncement = onCall(async (r) => catalog.setAnnouncement(db(), r.auth, r.data));
export const adminListCatalog = onCall(async (r) => catalog.adminListCatalog(db(), r.auth, r.data));
