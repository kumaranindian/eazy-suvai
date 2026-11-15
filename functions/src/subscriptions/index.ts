import { getFirestore } from "firebase-admin/firestore";
import { logger } from "firebase-functions/v2";
import { onCall } from "firebase-functions/v2/https";
import { onSchedule } from "firebase-functions/v2/scheduler";

import * as impl from "./callables";
import { runSubscriptionDaily } from "./daily";

/** Callable: the owner asks for a paid plan (FR-106). */
export const requestUpgrade = onCall(async (r) => impl.requestUpgrade(getFirestore(), r.auth, r.data));

/** Callable (admin): records an offline payment and activates the plan (FR-106, AC-030). */
export const recordPaymentAndActivate = onCall({ timeoutSeconds: 120 }, async (r) =>
  impl.recordPaymentAndActivate(getFirestore(), r.auth, r.data),
);

/** Callable (admin): extend, modify or downgrade, with a reason (FR-081). */
export const changeSubscription = onCall({ timeoutSeconds: 120 }, async (r) =>
  impl.changeSubscription(getFirestore(), r.auth, r.data),
);

/** Callable (admin): declines an upgrade request. */
export const closeUpgradeRequest = onCall(async (r) => impl.closeUpgradeRequest(getFirestore(), r.auth, r.data));

/** Callable (admin): the upgrade request queue. */
export const adminListUpgradeRequests = onCall(async (r) =>
  impl.adminListUpgradeRequests(getFirestore(), r.auth, r.data),
);

/** Callable (owner): swap hidden items, or downgrade choosing what to hide (FR-101). */
export const setHiddenOverLimit = onCall({ timeoutSeconds: 120 }, async (r) =>
  impl.setHiddenOverLimit(getFirestore(), r.auth, r.data),
);

/** Schedule: reminders, grace and downgrade (FR-100), 00:30 India time. */
export const subscriptionDaily = onSchedule(
  { schedule: "30 0 * * *", timeZone: "Asia/Kolkata", timeoutSeconds: 540, memory: "512MiB" },
  async () => {
    const report = await runSubscriptionDaily(getFirestore(), new Date(), (m, e) => logger.error(m, e));
    logger.info("subscriptionDaily", report);
  },
);
