// Lighthouse budget and layout checks for the public menu (M07, FRD §7.1).
//
// Run with `npm run test:lighthouse` (builds, writes robots.txt, starts the
// Firestore, Functions, Storage and Hosting emulators). It:
//   1. seeds two published menus (list and grid themes) with real WebP
//      renditions in the Storage emulator, like processImage makes them;
//   2. runs Lighthouse (mobile, simulated slow 4G) on the Hosting emulator
//      and fails unless LCP <= 2.5 s, the initial payload (everything except
//      images) <= 150 KB and accessibility >= 95;
//   3. opens the page at 360, 768 and 1280 px: no horizontal scroll, the
//      right number of columns, the sidebar on desktop; the lightbox opens
//      and closes with Escape; the category bar follows the scroll; and the
//      page still shows the menu with JavaScript off.
// Reports and screenshots go to functions/lighthouse-report/ (git-ignored).
// Needs Chrome (CHROME_PATH, or the default install) and network access for
// Google Fonts.
/* global document, window, getComputedStyle -- page.evaluate callbacks run in the browser */
import assert from "node:assert/strict";
import fs from "node:fs";
import { createRequire } from "node:module";
import path from "node:path";
import { fileURLToPath } from "node:url";

import * as chromeLauncher from "chrome-launcher";
import { initializeApp } from "firebase-admin/app";
import { getFirestore, Timestamp } from "firebase-admin/firestore";
import { getStorage } from "firebase-admin/storage";
import lighthouse from "lighthouse";
import puppeteer from "puppeteer-core";
import sharp from "sharp";

const require = createRequire(import.meta.url);
const { sampleSnapshot } = require("../lib/public/sample-menu.js");
const { downloadUrl } = require("../lib/publishing/draft-reader.js");

if (!process.env.FIRESTORE_EMULATOR_HOST || !process.env.FIREBASE_STORAGE_EMULATOR_HOST) {
  throw new Error("Run under the emulators: npm run test:lighthouse");
}

const BUDGET = { lcpMs: 2500, payloadBytes: 150 * 1024, accessibility: 0.95 };
const HOST = "http://127.0.0.1:5000";
const here = path.dirname(fileURLToPath(import.meta.url));
const outDir = path.resolve(here, "../lighthouse-report");
fs.mkdirSync(outDir, { recursive: true });

const PROJECT = "demo-eazysuvai";
const BUCKET = `${PROJECT}.appspot.com`;
initializeApp({ projectId: PROJECT, storageBucket: BUCKET });
const db = getFirestore();
const bucket = getStorage().bucket();

// ---- seed ------------------------------------------------------------------

let hue = 0;
/** A photo-like WebP set (smooth noise, like a food photo compresses), uploaded as processImage would. */
async function image(name, width, height) {
  hue = (hue + 47) % 360;
  const base = await sharp({ create: { width, height, channels: 3, background: { r: 120 + (hue % 100), g: 80 + (hue % 60), b: 40 }, noise: { type: "gaussian", mean: 128, sigma: 40 } } })
    .blur(2.5)
    .png()
    .toBuffer();
  const out = { width, height };
  for (const w of [320, 640, 1280]) {
    const file = `restaurants/lh/images/${name}/w${w}.webp`;
    const data = await sharp(base).resize({ width: Math.min(w, width), withoutEnlargement: true }).webp({ quality: 80 }).toBuffer();
    const token = `tok-${name}-${w}`;
    await bucket.file(file).save(data, {
      contentType: "image/webp",
      metadata: { cacheControl: "public, max-age=31536000, immutable", metadata: { firebaseStorageDownloadTokens: token } },
    });
    out[`w${w}`] = downloadUrl(BUCKET, file, token);
  }
  return out;
}

async function seedMenu(slug, rid, layout) {
  const images = {};
  const names = ["logo", "cover", ...sampleSnapshot().items.filter((i) => i.image).map((i) => `item-${i.id}`)];
  for (const n of names) images[n] = await image(n, n === "cover" ? 1500 : 1200, n === "cover" ? 500 : n === "logo" ? 1200 : 900);
  const s = sampleSnapshot((n) => images[n]);
  if (layout === "grid") s.theme.resolved = { ...s.theme.resolved, layout: "grid", cardLayout: "image-top" };
  await Promise.all([
    db.doc(`restaurants/${rid}`).set({ name: s.profile.name, slug, qrCode: "LHTEST22", status: "active", planId: "free", publishedVersion: 1, publishedAt: Timestamp.now() }),
    db.doc(`slugs/${slug}`).set({ restaurantId: rid, current: true }),
    db.doc(`restaurants/${rid}/versions/1`).set({ n: 1, kind: "publish", publishedAt: Timestamp.now(), snapshot: s }),
    db.doc(`restaurants/${rid}/live/availability`).set({ items: {}, updatedAt: Timestamp.now() }),
  ]);
}

await seedMenu("lh-list", "lh_list", "list");
await seedMenu("lh-grid", "lh_grid", "grid");
console.log("seeded lh-list and lh-grid");

// ---- Lighthouse ------------------------------------------------------------

const chrome = await chromeLauncher.launch({ chromeFlags: ["--headless=new", "--no-sandbox"] });
const failures = [];
const summary = {};
try {
  for (const slug of ["lh-list", "lh-grid"]) {
    const url = `${HOST}/${slug}`;
    // Warm the function, as a CDN-cached page would be (a cold emulator worker adds 1-2 s of TTFB).
    for (let i = 0; i < 2; i++) await fetch(url);
    // Default config: mobile (Moto G Power), simulated throttling (150 ms RTT, 1.6 Mbps).
    const result = await lighthouse(url, {
      port: chrome.port,
      output: "html",
      logLevel: "error",
      onlyCategories: ["performance", "accessibility", "seo", "best-practices"],
    });
    const lhr = result.lhr;
    fs.writeFileSync(path.join(outDir, `${slug}.html`), result.report);
    const lcp = lhr.audits["largest-contentful-paint"].numericValue;
    const requests = lhr.audits["network-requests"].details.items;
    const payload = requests.filter((r) => r.resourceType !== "Image").reduce((n, r) => n + (r.transferSize ?? 0), 0);
    const byType = {};
    for (const r of requests) byType[r.resourceType] = (byType[r.resourceType] ?? 0) + (r.transferSize ?? 0);
    const scores = Object.fromEntries(Object.entries(lhr.categories).map(([k, c]) => [k, c.score]));
    summary[slug] = { lcpMs: Math.round(lcp), payloadKB: +(payload / 1024).toFixed(1), byTypeKB: Object.fromEntries(Object.entries(byType).map(([k, v]) => [k, +(v / 1024).toFixed(1)])), scores };
    if (lcp > BUDGET.lcpMs) failures.push(`${slug}: LCP ${Math.round(lcp)} ms > ${BUDGET.lcpMs} ms`);
    if (payload > BUDGET.payloadBytes) failures.push(`${slug}: payload ${payload} B > ${BUDGET.payloadBytes} B`);
    if (scores.accessibility < BUDGET.accessibility) {
      const failed = Object.values(lhr.audits).filter((a) => a.score === 0 && lhr.categories.accessibility.auditRefs.some((r) => r.id === a.id)).map((a) => a.id);
      failures.push(`${slug}: accessibility ${scores.accessibility} < ${BUDGET.accessibility} (${failed.join(", ")})`);
    }
  }

  // ---- layout and behaviour at 360 / 768 / 1280 ----------------------------
  const res = await fetch(`http://127.0.0.1:${chrome.port}/json/version`);
  const { webSocketDebuggerUrl } = await res.json();
  const browser = await puppeteer.connect({ browserWSEndpoint: webSocketDebuggerUrl });
  const page = await browser.newPage();
  const expectCols = { "lh-list": { 360: 1, 768: 2, 1280: 2 }, "lh-grid": { 360: 1, 768: 2, 1280: 3 } };
  for (const slug of ["lh-list", "lh-grid"]) {
    for (const width of [360, 768, 1280]) {
      await page.setViewport({ width, height: 800, deviceScaleFactor: 1 });
      await page.goto(`${HOST}/${slug}`, { waitUntil: "networkidle0" });
      const m = await page.evaluate(() => {
        const cats = document.querySelector(".cats");
        const items = document.querySelector("#c-tiffin .items");
        return {
          overflow: document.documentElement.scrollWidth - window.innerWidth,
          cols: getComputedStyle(items).gridTemplateColumns.split(" ").length,
          sidebar: getComputedStyle(cats.querySelector("ul")).flexDirection === "column",
          sticky: getComputedStyle(cats).position,
        };
      });
      const tag = `${slug} @ ${width}px`;
      if (m.overflow > 0) failures.push(`${tag}: horizontal scroll of ${m.overflow}px`);
      if (m.cols !== expectCols[slug][width]) failures.push(`${tag}: ${m.cols} columns, expected ${expectCols[slug][width]}`);
      if (m.sidebar !== (width >= 1024)) failures.push(`${tag}: sidebar=${m.sidebar}`);
      if (m.sticky !== "sticky") failures.push(`${tag}: category bar is ${m.sticky}, not sticky`);
      await page.screenshot({ path: path.join(outDir, `${slug}-${width}.png`), fullPage: false });
    }
  }

  // Behaviour (360 px, list theme).
  await page.setViewport({ width: 360, height: 740, deviceScaleFactor: 2, isMobile: true, hasTouch: true });
  await page.goto(`${HOST}/lh-list?src=qr`, { waitUntil: "networkidle0" });
  assert.equal(new URL(page.url()).search, "", "?src=qr is removed from the address bar");
  await page.click("#c-tiffin a.zoom");
  await page.waitForSelector("dialog.lb[open]");
  const lbSrc = await page.$eval("dialog.lb img", (i) => i.getAttribute("src"));
  assert.match(lbSrc, /w1280\.webp/, "lightbox shows the large rendition");
  await page.screenshot({ path: path.join(outDir, "lightbox-360.png") });
  await page.keyboard.press("Escape");
  await page.waitForSelector("dialog.lb:not([open])");
  await page.click(".cats a[href='#c-desserts']");
  await page.waitForFunction(() => document.querySelector(".cats a[href='#c-desserts']").getAttribute("aria-current") === "true", { timeout: 5000 });
  await page.evaluate(() => document.querySelector("#c-biryani").scrollIntoView());
  await page.waitForFunction(() => document.querySelector(".cats a[href='#c-biryani']").getAttribute("aria-current") === "true", { timeout: 5000 });
  const moreButtons = await page.$$eval("button.more", (b) => b.length);
  assert.ok(moreButtons >= 1, "long descriptions get a 'more' button");
  await page.click("button.more");
  assert.equal(await page.$eval("button.more", (b) => b.getAttribute("aria-expanded")), "true");

  // Without JavaScript: the menu, links and photos still work.
  const noJs = await browser.newPage();
  await noJs.setJavaScriptEnabled(false);
  await noJs.setViewport({ width: 360, height: 740 });
  await noJs.goto(`${HOST}/lh-list`, { waitUntil: "networkidle0" });
  const nj = await noJs.evaluate(() => ({
    items: document.querySelectorAll(".item").length,
    js: document.documentElement.classList.contains("js"),
    zoomHref: document.querySelector("a.zoom")?.getAttribute("href") ?? "",
    navLinks: document.querySelectorAll(".cats a[href^='#c-']").length,
  }));
  assert.ok(nj.items > 30 && !nj.js && nj.navLinks === 6 && /w1280\.webp/.test(nj.zoomHref), JSON.stringify(nj));
  await noJs.screenshot({ path: path.join(outDir, "no-js-360.png") });
  await browser.disconnect();
} catch (e) {
  failures.push(`behaviour: ${e.message}`);
} finally {
  await chrome.kill();
}

fs.writeFileSync(path.join(outDir, "summary.json"), JSON.stringify({ budget: BUDGET, summary, failures }, null, 2));
console.log(JSON.stringify(summary, null, 2));
if (failures.length > 0) {
  console.error(`Lighthouse budget / layout FAILED:\n- ${failures.join("\n- ")}`);
  process.exit(1);
}
console.log("Lighthouse budget and layout checks: ok");
