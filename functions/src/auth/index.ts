import { getAuth } from "firebase-admin/auth";
import { getFirestore } from "firebase-admin/firestore";
import { logger } from "firebase-functions/v2";
import { onCall } from "firebase-functions/v2/https";
import { onSchedule } from "firebase-functions/v2/scheduler";

import { cleanupUnverifiedUsers as cleanup } from "./cleanup";
import { registerOwner } from "./register";

/**
 * Callable: creates the caller's restaurant tenant after
 * `createUserWithEmailAndPassword` (M01). See {@link registerOwner}.
 */
export const completeRegistration = onCall(async (request) =>
  registerOwner({ db: getFirestore(), auth: getAuth() }, request.auth, request.data),
);

/** Daily: deletes accounts left unverified for 7 days (FR-091). */
export const cleanupUnverifiedUsers = onSchedule(
  { schedule: "every day 03:30", timeZone: "UTC" },
  async () => {
    const deleted = await cleanup({ db: getFirestore(), auth: getAuth() });
    logger.info("cleanupUnverifiedUsers", { deleted: deleted.length });
  },
);
