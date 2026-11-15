// Compares document counts between the live Firestore database and a
// restored copy (ops/restore-test.sh, M13). Read-only on both.
//
//   node ops/compare-counts.mjs --project <id> --database <restored-db>
//
// Counts can differ by writes made after the backup; the report shows the
// difference per collection and fails only if the restored copy has none
// of a collection the live database has.
import { parseArgs } from "node:util";
import { createRequire } from "node:module";

const require = createRequire(new URL("../functions/package.json", import.meta.url));
const { initializeApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");

const { values } = parseArgs({ options: { project: { type: "string" }, database: { type: "string" } } });
if (!values.project || !values.database) {
  console.error("Usage: node ops/compare-counts.mjs --project <id> --database <restored-db>");
  process.exit(2);
}

const app = initializeApp({ projectId: values.project });
const live = getFirestore(app);
const restored = getFirestore(app, values.database);

const TOP = ["restaurants", "slugs", "qrCodes", "users", "plans", "themes", "dietaryLabels", "itemTags", "auditLogs", "upgradeRequests"];
const GROUPS = ["categories", "items", "versions", "payments", "analyticsDaily"];

const count = async (db, q) => (await q(db).count().get()).data().count;
const rows = [];
let failed = false;
for (const [name, q] of [
  ...TOP.map((c) => [c, (db) => db.collection(c)]),
  ...GROUPS.map((g) => [`*/${g}`, (db) => db.collectionGroup(g)]),
]) {
  const [a, b] = await Promise.all([count(live, q), count(restored, q)]);
  rows.push({ collection: name, live: a, restored: b, diff: a - b });
  if (a > 0 && b === 0) failed = true;
}
console.table(rows);
if (failed) {
  console.error("A collection is empty in the restored copy.");
  process.exit(1);
}
console.log("Restore check: ok");
