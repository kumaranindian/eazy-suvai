// Checks storageUrlResolver (M06) against the Storage emulator. It uses
// getDownloadURL, which Jest's VM cannot run (dynamic import), so this runs
// with plain Node after the emulator Jest suite (`npm run test:emulators`).
// Build first: npm run build.
import assert from "node:assert/strict";
import { createRequire } from "node:module";

import { initializeApp } from "firebase-admin/app";
import { getStorage } from "firebase-admin/storage";

const require = createRequire(import.meta.url);
const { storageUrlResolver } = require("../lib/publishing/draft-reader.js");

if (!process.env.FIREBASE_STORAGE_EMULATOR_HOST) {
  throw new Error("Run under the Storage emulator (npm run test:emulators).");
}

const bucket = "demo-eazysuvai.appspot.com";
initializeApp({ projectId: "demo-eazysuvai", storageBucket: bucket });

const path = "restaurants/check/images/abc/w320.webp";
await getStorage()
  .bucket()
  .file(path)
  .save(Buffer.from("webp"), { contentType: "image/webp", metadata: { metadata: { firebaseStorageDownloadTokens: "tok-1" } } });

const urls = await storageUrlResolver([path, "restaurants/check/images/missing/w320.webp"]);
assert.deepEqual(Object.keys(urls), [path], "only the existing file resolves");
assert.match(urls[path], /token=tok-1/);
assert.ok(urls[path].includes(encodeURIComponent(path)), urls[path]);
// Customers load it without signing in (the token is the access check).
const res = await fetch(urls[path]);
assert.equal(res.status, 200, `anonymous GET ${urls[path]}`);
assert.equal(Buffer.from(await res.arrayBuffer()).toString(), "webp");
console.log("check-storage-urls: ok", urls[path]);

// M12: the purge's Storage helpers (list image folders, delete a prefix).
const { storagePurgeDeps } = require("../lib/lifecycle/index.js");
const purge = storagePurgeDeps();
for (const name of ["restaurants/check2/images/a/w320.webp", "restaurants/check2/images/a/w640.webp", "restaurants/check2/images/b/w320.webp"]) {
  await getStorage().bucket().file(name).save(Buffer.from("x"), { contentType: "image/webp" });
}
let folders = (await purge.listImageFolders("check2")).map((f) => f.folder).sort();
assert.deepEqual(folders, ["restaurants/check2/images/a/", "restaurants/check2/images/b/"]);
await purge.deletePrefix("restaurants/check2/images/a/");
folders = (await purge.listImageFolders("check2")).map((f) => f.folder);
assert.deepEqual(folders, ["restaurants/check2/images/b/"]);
await purge.deletePrefix("restaurants/check2/");
assert.deepEqual(await purge.listImageFolders("check2"), []);
console.log("check-storage-purge: ok");
