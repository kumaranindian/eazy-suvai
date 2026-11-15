import { gzipSync } from "node:zlib";

import { getFirestore } from "firebase-admin/firestore";
import { logger } from "firebase-functions/v2";
import { onRequest } from "firebase-functions/v2/https";

import { handleMenuRequest, menuBaseUrl } from "./serve";

/** Bodies smaller than this are sent as they are. */
const GZIP_MIN_BYTES = 1024;

/**
 * HTTPS: the public menu site (M07, architecture §3). Firebase Hosting's
 * `menu` site rewrites every path here; responses are cached at the CDN
 * for 60 s (`s-maxage=60`). Bodies are gzipped when the client accepts it
 * (`Vary: Accept-Encoding`), so the CDN stores and serves the small copy.
 */
export const renderMenu = onRequest(
  { invoker: "public", memory: "256MiB", concurrency: 80, timeoutSeconds: 30 },
  async (req, res) => {
    const q = req.originalUrl.indexOf("?");
    const result = await handleMenuRequest(
      getFirestore(),
      {
        method: req.method,
        path: req.path,
        query: q >= 0 ? req.originalUrl.slice(q) : "",
        headers: { "if-none-match": req.get("if-none-match") },
      },
      {
        baseUrl: menuBaseUrl(),
        allowHttpImages: process.env.FUNCTIONS_EMULATOR === "true",
        logError: (message, error) => logger.error(message, error),
      },
    );
    res.status(result.status).set(result.headers);
    if (result.body === "" || req.method === "HEAD") {
      res.end();
      return;
    }
    res.vary("Accept-Encoding");
    if (Buffer.byteLength(result.body) >= GZIP_MIN_BYTES && /\bgzip\b/.test(req.get("accept-encoding") ?? "")) {
      res.set("Content-Encoding", "gzip").send(gzipSync(result.body));
      return;
    }
    res.send(result.body);
  },
);
