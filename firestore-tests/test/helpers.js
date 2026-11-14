import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";

import { initializeTestEnvironment } from "@firebase/rules-unit-testing";

const root = fileURLToPath(new URL("../../", import.meta.url));

export const PROJECT_ID = "demo-eazysuvai";

/** Starts a test environment against the running emulators. */
export function createEnv() {
  return initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: { rules: readFileSync(`${root}firestore.rules`, "utf8") },
    storage: { rules: readFileSync(`${root}storage.rules`, "utf8") },
  });
}

/** Custom claims for a verified owner of `restaurantId` (architecture §5). */
export const ownerClaims = (restaurantId) => ({
  email_verified: true,
  role: "owner",
  restaurantId,
});

export const adminClaims = { email_verified: true, role: "platformAdmin" };
