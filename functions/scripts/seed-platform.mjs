// Seeds the platform-managed dietary labels and item tags (M04; FR-023,
// FR-033, FR-104). Safe to run again: existing documents keep any admin
// changes (only missing ones are created) unless --overwrite is given.
//
// Build first (the data lives in src/menu/seed-data.ts): npm run build
//
// Emulators:
//   FIRESTORE_EMULATOR_HOST=localhost:8080 node scripts/seed-platform.mjs --project demo-eazysuvai
//
// Real project (Application Default Credentials):
//   node scripts/seed-platform.mjs --project eazy-suvai-dev
import { createRequire } from "node:module";
import { parseArgs } from "node:util";

import { initializeApp } from "firebase-admin/app";
import { FieldValue, getFirestore } from "firebase-admin/firestore";

const require = createRequire(import.meta.url);
const { DIETARY_LABELS, ITEM_TAGS } = require("../lib/menu/seed-data.js");

const { values } = parseArgs({
  options: {
    project: { type: "string" },
    overwrite: { type: "boolean", default: false },
  },
});
if (!values.project) {
  console.error("Usage: node scripts/seed-platform.mjs --project <id> [--overwrite]");
  process.exit(2);
}
if (!process.env.FIRESTORE_EMULATOR_HOST && values.project.startsWith("demo-")) {
  console.error("demo- projects only exist on the emulators. Set FIRESTORE_EMULATOR_HOST.");
  process.exit(2);
}

initializeApp({ projectId: values.project });
const db = getFirestore();

let created = 0;
for (const [collection, entries] of [
  ["dietaryLabels", DIETARY_LABELS],
  ["itemTags", ITEM_TAGS],
]) {
  for (const { id, ...data } of entries) {
    const ref = db.doc(`${collection}/${id}`);
    if (!values.overwrite && (await ref.get()).exists) continue;
    await ref.set({ ...data, updatedAt: FieldValue.serverTimestamp() });
    created++;
  }
}
console.log(`Seeded ${created} platform label/tag documents in ${values.project}.`);
