import { getFirestore } from "firebase-admin/firestore";
import { logger } from "firebase-functions/v2";
import { onRequest } from "firebase-functions/v2/https";

import { handleCollect } from "./collect";

/**
 * HTTPS: `POST /e`, the public menu's analytics beacon (M09). Hosting
 * rewrites `/e` here (before the `**` rewrite to `renderMenu`).
 * Always answers without a body; never cached.
 */
export const collectEvent = onRequest(
  { invoker: "public", memory: "256MiB", concurrency: 80, timeoutSeconds: 10 },
  async (req, res) => {
    const raw = req.rawBody ? req.rawBody.toString("utf8") : typeof req.body === "string" ? req.body : JSON.stringify(req.body ?? "");
    // Hosting forwards the client address first in X-Forwarded-For.
    const ip = (req.get("x-forwarded-for") ?? "").split(",")[0].trim() || req.ip;
    try {
      const result = await handleCollect(getFirestore(), {
        method: req.method,
        body: raw,
        userAgent: req.get("user-agent"),
        ip,
      });
      res.status(result.status);
    } catch (e) {
      logger.error("collectEvent", e);
      res.status(500);
    }
    res.set("Cache-Control", "no-store").end();
  },
);
