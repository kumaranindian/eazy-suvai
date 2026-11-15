import { getAuth } from "firebase-admin/auth";
import { getFirestore } from "firebase-admin/firestore";
import { getStorage } from "firebase-admin/storage";
import { logger } from "firebase-functions/v2";
import { onCall } from "firebase-functions/v2/https";
import { onSchedule } from "firebase-functions/v2/scheduler";

import { adminListAuditLogs as listAudit } from "./audit-viewer";
import { requestAccountDeletion as requestDeletion } from "./deletion";
import { exportMenu as exportImpl } from "./export";
import { runPurgeDaily, type PurgeDeps } from "./purge";
import { recomputeStats } from "../admin/stats";

/** Callable (owner): the menu as JSON and CSV (FR-105). */
export const exportMenu = onCall({ memory: "512MiB" }, async (r) => exportImpl(getFirestore(), r.auth, r.data));

/** Callable (owner): close the account; purged after 90 days (FR-105). */
export const requestAccountDeletion = onCall(async (r) => requestDeletion(getFirestore(), r.auth, r.data, { auth: getAuth() }));

/** Callable (admin): the audit log (FR-090). */
export const adminListAuditLogs = onCall(async (r) => listAudit(getFirestore(), r.auth, r.data));

/** Storage helpers for the purge (real bucket or the emulator). */
export function storagePurgeDeps(): Pick<PurgeDeps, "deletePrefix" | "listImageFolders"> {
  const bucket = () => getStorage().bucket();
  return {
    deletePrefix: async (prefix) => {
      await bucket().deleteFiles({ prefix, force: true });
    },
    listImageFolders: async (rid) => {
      const [files] = await bucket().getFiles({ prefix: `restaurants/${rid}/images/` });
      const folders = new Map<string, Date>();
      for (const f of files) {
        const m = /^(restaurants\/[^/]+\/images\/[^/]+\/)/.exec(f.name);
        if (!m) continue;
        const t = new Date(String(f.metadata.updated ?? f.metadata.timeCreated ?? 0));
        const cur = folders.get(m[1]);
        if (!cur || t > cur) folders.set(m[1], t);
      }
      return [...folders].map(([folder, updatedAt]) => ({ folder, updatedAt }));
    },
  };
}

/** Schedule: the retention rules of FRD §7.7, daily at 02:30 India time. */
export const purgeDaily = onSchedule(
  { schedule: "30 2 * * *", timeZone: "Asia/Kolkata", timeoutSeconds: 540, memory: "1GiB" },
  async () => {
    const report = await runPurgeDaily(getFirestore(), new Date(), { auth: getAuth(), ...storagePurgeDeps() });
    logger.info("purgeDaily", report);
    // Nightly exact recount of the dashboard counters, including the FRD §13
    // median time to first publish (M13).
    logger.info("purgeDaily stats", await recomputeStats(getFirestore()));
  },
);
