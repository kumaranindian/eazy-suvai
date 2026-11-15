// Load test for the public menu (M13, FRD §7.3: 200 requests/s at peak,
// mostly served from the CDN). Run with `npm run test:load` (Firestore,
// Functions and Hosting emulators), which runs both modes:
//
// `node scripts/load-test.mjs render`: what one renderMenu request costs
//   after its three Firestore point reads, at RATE (200) requests/s on ONE
//   core, in an open loop: render + gzip of a 36-item menu. Fails unless
//   p95 <= 50 ms and no request fails. It also reports the CPU cost of a
//   200-item menu, to size instances.
// `node scripts/load-test.mjs hosting`: the full Hosting -> Functions
//   emulator chain at 15 requests/s (90 % pages, 10 % beacons). Fails on
//   >= 1 % errors, p95 > 1000 ms or a page without `s-maxage`. On one
//   machine the Functions emulator queues requests from about 20/s (the
//   handler itself does 240+/s per core), so this checks
//   correctness under concurrency, not capacity.
//
// The emulators have no CDN. For 200 requests/s through the real CDN, run
// scripts/load/menu.k6.js against dev (never prod without agreement).
import assert from "node:assert/strict";
import { createRequire } from "node:module";

import { initializeApp } from "firebase-admin/app";
import { getFirestore, Timestamp } from "firebase-admin/firestore";

const require = createRequire(import.meta.url);
const { sampleSnapshot } = require("../lib/public/sample-menu.js");
const { loadMenu } = require("../lib/public/loader.js");
const { renderMenuPage } = require("../lib/public/render-menu.js");
const { gzipSync } = require("node:zlib");

if (!process.env.FIRESTORE_EMULATOR_HOST) throw new Error("Run under the emulators: npm run test:load");

const MODE = process.argv[2] ?? process.env.MODE ?? "render";
const HOST = "http://127.0.0.1:5000";
const RATE = Number(process.env.RATE ?? (MODE === "hosting" ? 15 : 200));
const DURATION = Number(process.env.DURATION ?? 30);
const P95_MS = Number(process.env.P95_MS ?? (MODE === "hosting" ? 1000 : 50));
const MENUS = 20;

initializeApp({ projectId: "demo-eazysuvai" });
const db = getFirestore();

const slugs = [];
for (let i = 0; i < MENUS; i++) {
  const slug = `load-${i}`;
  const rid = `load_${i}`;
  const s = sampleSnapshot();
  s.profile.name = `Load Test ${i}`;
  await Promise.all([
    db.doc(`restaurants/${rid}`).set({ name: s.profile.name, slug, qrCode: `LOAD${String(i).padStart(4, "0")}`, status: "active", planId: "free", publishedVersion: 1, publishedAt: Timestamp.now() }),
    db.doc(`slugs/${slug}`).set({ restaurantId: rid, current: true }),
    db.doc(`restaurants/${rid}/versions/1`).set({ n: 1, kind: "publish", publishedAt: Timestamp.now(), snapshot: s }),
    db.doc(`restaurants/${rid}/live/availability`).set({ items: {}, updatedAt: Timestamp.now() }),
  ]);
  slugs.push(slug);
}

// Warm up: one request per menu (instance start, caches).
for (const slug of slugs) {
  const r = await fetch(`${HOST}/${slug}`);
  assert.equal(r.status, 200, `warm-up ${slug}`);
  assert.match(r.headers.get("cache-control") ?? "", /s-maxage=\d+/, "CDN cache header");
  await r.arrayBuffer();
}
console.log(`seeded and warmed ${MENUS} menus; mode ${MODE}, ${RATE} req/s for ${DURATION} s`);

// Render mode: the menus as renderMenu loads them (the same three reads).
const loaded = {};
for (const slug of slugs) loaded[slug] = await loadMenu(db, slug);
function render(slug, snapshot = loaded[slug].snapshot) {
  const m = loaded[slug];
  const body = renderMenuPage(snapshot, { availability: m.availability, branding: m.branding, canonicalUrl: `https://menu.example/${slug}`, slug, beacon: "/e" });
  gzipSync(body);
  return body;
}
let largeMs = null;
if (MODE === "render") {
  const big = structuredClone(loaded[slugs[0]].snapshot);
  const base = big.items;
  big.items = Array.from({ length: 200 }, (_, i) => ({ ...base[i % base.length], id: `x${i}`, sequence: i }));
  for (let i = 0; i < 20; i++) render(slugs[0], big);
  const t = performance.now();
  for (let i = 0; i < 100; i++) render(slugs[0], big);
  largeMs = (performance.now() - t) / 100;
}

const UA = "Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Mobile Safari/537.36";
const latencies = [];
let failed = 0;
let missingCache = 0;
const inflight = new Set();

async function one(n) {
  const slug = slugs[n % MENUS];
  const beacon = n % 10 === 9;
  const t0 = performance.now();
  try {
    if (MODE === "render") {
      if (!render(slug).includes("</html>")) failed++;
      return;
    }
    const r = beacon
      ? await fetch(`${HOST}/e`, { method: "POST", headers: { "content-type": "text/plain", "user-agent": UA }, body: JSON.stringify({ type: "view", slug, src: "direct" }) })
      : await fetch(`${HOST}/${slug}`, { headers: { "user-agent": UA } });
    await r.arrayBuffer();
    if (r.status >= 400) failed++;
    if (!beacon && !/s-maxage=\d+/.test(r.headers.get("cache-control") ?? "")) missingCache++;
  } catch {
    failed++;
  } finally {
    latencies.push(performance.now() - t0);
  }
}

const total = RATE * DURATION;
const start = performance.now();
let n = 0;
while (n < total) {
  // Open loop: request n is due at n / RATE seconds, whatever the latency.
  // Each tick starts every request now due (timers are ~15 ms coarse on
  // Windows, so sleeping per request would undershoot the rate).
  const now = performance.now();
  while (n < total && start + (n * 1000) / RATE <= now) {
    const p = one(n).finally(() => inflight.delete(p));
    inflight.add(p);
    n++;
  }
  await new Promise((r) => setTimeout(r, 2));
}
await Promise.all(inflight);
const elapsed = (performance.now() - start) / 1000;

latencies.sort((a, b) => a - b);
const pct = (q) => Math.round(latencies[Math.min(latencies.length - 1, Math.floor(q * latencies.length))]);
const summary = {
  requests: total,
  achievedRps: +(total / elapsed).toFixed(1),
  failed,
  errorRate: +((failed / total) * 100).toFixed(2),
  p50: pct(0.5),
  p95: pct(0.95),
  p99: pct(0.99),
  max: Math.round(latencies.at(-1)),
  missingCacheHeader: missingCache,
  ...(largeMs == null ? {} : { item200RenderMs: +largeMs.toFixed(1), item200RpsPerCore: Math.round(1000 / largeMs) }),
};
console.log(JSON.stringify(summary, null, 2));

const failures = [];
if (summary.errorRate >= 1) failures.push(`error rate ${summary.errorRate} % >= 1 %`);
if (summary.p95 > P95_MS) failures.push(`p95 ${summary.p95} ms > ${P95_MS} ms`);
if (missingCache > 0) failures.push(`${missingCache} menu responses without s-maxage`);
if (summary.achievedRps < RATE * 0.9) failures.push(`achieved ${summary.achievedRps} req/s < 90 % of ${RATE}`);
if (failures.length) {
  console.error(failures.join("\n"));
  process.exit(1);
}
console.log("Load test: ok");
process.exit(0);
