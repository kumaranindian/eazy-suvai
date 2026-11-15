// Copies each restaurant's plan flags to `restaurants/{rid}.planFeatures`
// (M10). Run once after deploying M10 on a project that already has
// restaurants, and after changing a plan when the change should reach
// existing subscribers (FR-077: plan edits apply only when applied).
// Build first: npm run build
//
//   node scripts/backfill-plan-features.mjs --project eazy-suvai-dev [--plan pro]
//   (emulators: set FIRESTORE_EMULATOR_HOST first)
import { createRequire } from "node:module";
import { parseArgs } from "node:util";

import { initializeApp } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";

const require = createRequire(import.meta.url);
const { syncPlanFeatures } = require("../lib/subscriptions/daily.js");

const { values } = parseArgs({ options: { project: { type: "string" }, plan: { type: "string" } } });
if (!values.project) {
  console.error("Usage: node scripts/backfill-plan-features.mjs --project <id> [--plan <planId>]");
  process.exit(2);
}
initializeApp({ projectId: values.project });
const db = getFirestore();
let q = db.collection("restaurants");
if (values.plan) q = q.where("planId", "==", values.plan);
const snap = await q.select().get();
let n = 0;
for (const d of snap.docs) {
  await syncPlanFeatures(db, d.id);
  n++;
}
console.log(`planFeatures written for ${n} restaurant(s)`);
