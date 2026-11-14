# M02 – Media management

Status: Done
Started: 2026-11-14
Completed: 2026-11-14

## Goal

One reusable image pipeline for logos, covers, category and item images: pick, crop, upload, validate, generate web renditions, and show progress and errors.

## FRD coverage

FR-031, FR-032, FR-102, §7.1 (optimised responsive images), §7.2 (file upload validation), AC-005.

## Depends on

M00.

## Inputs from other modules

- M00 (done 2026-11-14): `storage.rules` denies everything. Open `restaurants/{rid}/images/**` and update the Storage expectations in `firestore-tests/test/baseline.test.js`.
- M01 (done 2026-11-14): claims `{role: 'owner', restaurantId}`, and `email_verified` must be true. Mirror `isOwner(rid)` from `firestore.rules` in `storage.rules` (Storage rules can read the restaurant status with `firestore.get`).

## Scope

**In:** `ImagePickerField` widget (pick from gallery or files, crop to a given aspect ratio, preview, replace, remove), upload service with progress, Storage rules, `processImage` trigger, image object model (`docs/architecture.md` §4.4).
**Out:** where images are used (M03, M04).

## Data and backend

- Upload path: `restaurants/{rid}/images/{uuid}/original.{ext}`.
- Storage rules: only the owner of `{rid}` can write; `contentType` must be `image/jpeg`, `image/png` or `image/webp`; size ≤ 5 MB.
- `processImage` (Storage finalize trigger, uses `sharp`):
  1. Check the real file type from its magic bytes; reject anything else.
  2. Check minimum dimensions by purpose (logo 256×256, cover 1200×400, item and category 400×400). The purpose, the target document path and the field name are stored in the upload's custom metadata; the function checks that the target path is inside the same `restaurants/{rid}`.
  3. Strip EXIF and location data.
  4. Write WebP renditions at 320, 640 and 1280 px wide.
  5. Update the referencing document's image object to `status: 'ready'` with rendition paths, or `rejected` with a reason code.
- Client-side: resize very large images before upload (longest side 2560 px) to save mobile data.

## Screens and responsive behaviour

`ImagePickerField` adapts its preview size: 96 px thumbnail in compact lists, 160 px in forms on medium and expanded. The crop dialog is full-screen on compact and a 640 px dialog elsewhere.

## Tasks

- [x] Image object model in `packages/core`.
- [x] `ImagePickerField` with crop (`image_cropper` on mobile, a web-compatible cropper on web), preview, replace, remove. (One pure-Flutter cropper on all platforms; see Completion notes, decision 1.)
- [x] Upload service with progress stream and cancel.
- [x] Storage rules and rules tests.
- [x] `processImage` with type, size and dimension checks, EXIF strip and renditions.
- [x] `ResponsiveImage` widget that chooses the right rendition for its width and shows a placeholder while processing.
- [x] Localized error messages for each rejection reason.

## Acceptance checks

- [x] AC-005: JPEG, PNG and WebP up to 5 MB upload and display; a 6 MB file and a renamed PDF are rejected with clear messages. (Rules, function and widget tests; end to end in Chrome on the emulators.)
- [x] Renditions exist at 320/640/1280 px and the original has no EXIF. (Function unit, emulator and Chrome end-to-end tests.)
- [x] Another restaurant's owner cannot write to this restaurant's image path. (`storage.test.js`; also through the client SDK in the Chrome end-to-end test.)
- [ ] Works on web, Android and iOS. Web verified end to end in Chrome. The Android debug APK builds but was not run on a device, and iOS cannot be built on Windows. See Open items.

## Tests

Functions: `processImage` with valid, oversized, wrong-type and too-small images. Storage rules tests. Widget test of `ImagePickerField` states.

## Completion notes

**What was built**

- **Storage rules (`storage.rules`):** `restaurants/{rid}/images/{imageId}/{fileName}`.
  - `get`: `isOwner(rid)` (verified, `owner`, `restaurantId` claim, restaurant `active` via `firestore.get`) or `isAdmin()` (TOTP). `list`: nobody.
  - `create`: `isOwner(rid)`, `resource == null`, `imageId` 16–64 url-safe characters, file name `original.(jpg|png|webp)`, size ≤ 5 MB, content type matching the extension, and custom metadata of exactly `{purpose, targetPath, field}` naming an allowed target in the same restaurant.
  - `update` and `delete`: nobody. Every other path is still denied.
- **Function `processImage`** (`functions/src/media/`, Storage `onObjectFinalized`, asia-south1, 1 GiB, 120 s, concurrency 1). Files:
  - `policy.ts`: limits, minimums, reason codes, path parsing, the target allow-list. `logo` → `restaurants/{rid}.logo`, `cover` → `.cover`, `category` → `…/categories/{cid}.image`, `item` → `…/items/{iid}.image`.
  - `image-types.ts`: magic bytes.
  - `renditions.ts` (sharp 0.35): read info with auto-orientation, re-encode the original without metadata, WebP renditions with `withoutEnlargement`.
  - `process-image.ts`: the handler, with an injected `{db, store}`.

  Flow: skip non-originals and originals marked `processed`. Delete uploads with bad metadata or a missing target document. In a transaction, set the field to `processing`, unless a newer upload already owns it or this event was already handled. Then check size, content type against the extension, magic bytes, decodability (50 MP limit) and the minimum dimensions. Write `w320/w640/w1280.webp` (immutable cache headers, download token). Rewrite `original.*` with `processed: 'true'` metadata. In a second transaction, set `ready` only if the field still points at this upload. On a rejection, the files are deleted and the field becomes `{status: 'rejected', reason}`. On an unexpected error (`processing-failed`), the original is kept. A `ready` write bumps `draftUpdatedAt` on the restaurant, and `updatedAt` on items.
- **Core (`packages/core/lib/src/media/`, exported from `core.dart`):**
  - `image_object.dart`: `ImagePurpose` (min size, default aspect, field, wire), `ImageStatus`, `ImageRejectReason` (server codes plus device-only `upload-failed`, `pick-failed`), `ImageRenditions.pathFor(physicalWidth)`, `ImageObject.fromMap`.
  - `image_sniffer.dart`: `ImageFormat`, `sniffImageFormat`, `readImageHeaderSize` (JPEG SOF, PNG IHDR, WebP VP8/VP8L/VP8X).
  - `image_preparer.dart`: `ImagePreparer.load` (5 MB, type, 50 MP, decode, minimum at the aspect ratio) and `.crop` (longest side ≤ 2560 px; JPEG q85, or PNG when transparent; EXIF dropped).
  - `crop_geometry.dart` and `image_crop_dialog.dart`: a fixed-aspect pan/zoom cropper. Pinch, drag, mouse wheel and an accessible slider. Zoom is capped so the crop never goes below the purpose minimum.
  - `image_upload_service.dart`: `ImageUploader` / `ImageUpload` with a `progress` stream, `done` and `cancel()`, plus `newImagePath`. `image_picker_service.dart`: `ImageFilePicker` (image_picker, gallery or file dialog). `storage_image_resolver.dart`: `getDownloadURL`, cached.
  - `image_picker_field.dart` and `responsive_image.dart`: the widgets. `image_messages.dart`: `CoreLocalizations.imageRejectMessage(reason, purpose)`.
  - Fakes in `package:core/testing.dart`: `FakeImageFilePicker`, `FakeImageUploader`, `FakeStorageImageResolver`.
  - Strings: 25 `image*` keys in `core_en.arb`.
- **Owner app:** `NSPhotoLibraryUsageDescription` in iOS `Info.plist`. Developer page `/dev/media` (`features/dev/`, not registered when `ENV=prod`) with the logo and cover pickers on the live restaurant document.
- **Tests:**
  - Functions: `media.test.ts` (19, sharp on generated images) and `process-image.emu.test.ts` (13; the handler on the Firestore emulator, plus one end-to-end run through the real trigger on the Storage and Functions emulators).
  - Rules: `firestore-tests/test/storage.test.js` (10); `baseline.test.js` updated.
  - Core: `test/media/` (50: model, sniffer, geometry, preparer with real decoding and encoding, and both widgets at 360/768/1280).
  - Owner app: `media_test_page_test.dart` (3 widths) and `integration_test/media_flow_test.dart` (Chrome on the emulators: pick → crop → upload → `processImage` → `ready` → rendition displayed via `getDownloadURL`; renamed PDF refused; another tenant's path refused).
- **Tooling and docs:**
  - `npm run test:emulators` also starts the Storage emulator.
  - `tool/integration.sh` runs both end-to-end tests through `tool/integration-drive.sh`. `firebase emulators:exec` uses `cmd.exe` on Windows, so a shell loop can't be inline.
  - `storage.cors.json`. README sections "Trying image uploads (M02)" and "Connecting the real projects" step 6.
  - Architecture §4.4: object shape by status, and who writes it.

**Decisions that differ from the plan**

1. **One pure-Flutter cropper on all platforms**, not `image_cropper` on mobile. `image_cropper` opens native full-screen activities (UCrop and TOCropViewController), which cannot be the 640 px dialog the plan asks for on medium and expanded. A single cropper also behaves the same everywhere, is widget-tested, and enforces the minimum size while zooming.
2. **Files over 5 MB are refused on the device, not shrunk.** The plan also says to "resize very large images before upload", but FR-102 and AC-005 say a 6 MB file is rejected. So the 5 MB check comes first, and the 2560 px downscale applies to accepted files with large dimensions. If you'd rather accept large phone photos and shrink them, it is a one-line change in `ImagePreparer.load`, but it changes AC-005.
3. **The device always re-encodes** (crop → JPEG q85, or PNG for transparent PNG/WebP sources). This drops EXIF before upload. The server still strips and re-encodes, because clients can't be trusted.
4. **Image object fields added:** `reason` (rejected) and `uploadedAt`, used to ignore an older upload that finishes after a newer one. Only `processImage` writes image objects; clients only set a field to `null`. Architecture §4.4 is updated.
5. **A 50-megapixel decode limit** (decompression bombs), on the device (from the file header) and on the server (sharp `limitInputPixels`). It is reported as `too-large`. Not in the FRD.
6. **Rejected uploads are deleted** from Storage. `processing-failed` keeps the original so it can be processed again.
7. **`resource == null` in the `create` rule.** The Storage emulator evaluated an overwrite as `create`, so the rule states it explicitly.
8. **Rules tests run one file at a time** (`--test-concurrency=1`). In parallel, one file's `clearFirestore()` removed another's seed data mid-test. This was hidden while every Storage path was denied.
9. **Emulator tests upload with `fetch`** (GCS JSON API). `@google-cloud/storage` streams fail inside Jest's module sandbox ("Cannot call write after a stream was destroyed"). The function itself uses the SDK, and the end-to-end test proves that works.
10. **Developer page `/dev/media`** in the owner app, so the pipeline can be checked by hand before M03. Not available in prod builds. Remove or keep in M03.

## Open items

- **Android and iOS not run on a device.** The Android debug APK builds with `image_picker` (photo picker, no permission needed). iOS can't be built on Windows; `NSPhotoLibraryUsageDescription` is set. Check by hand: pick, crop (pinch and drag), upload and view on both, including a HEIC photo on iOS (image_picker converts it to JPEG).
- **Real-project setup for Storage** (README → "Connecting the real projects" step 6), still to do on `eazy-suvai-dev` and prod:
  - Accept the Storage → Firestore cross-service rules permission on the first rules deploy.
  - Apply `storage.cors.json` to the bucket. Add the final app domains when they are decided.
  - The Blaze plan is needed for the Storage trigger.
  - Confirm the default bucket is in `asia-south1`.
- **Web encodes JPEGs on the main thread.** `compute()` runs inline on web, so cropping a very large image can pause the UI for about 1–2 s while "Preparing image…" shows. If this matters, encode with the browser canvas (`toBlob('image/jpeg')`) on web.
- **A rejected replacement replaces the previous image in the draft.** The field becomes `rejected` with the reason, so the earlier logo is gone from the draft until a valid one is uploaded. The published menu is not affected. Device checks make server rejections rare (only tampered or unexpected files).
- **If another device's newer upload wins**, this device keeps showing "Processing image…" (with the "taking longer" note after 60 s) until the page is reloaded.
- **Unreferenced image files are never deleted** (replaced or removed images, abandoned uploads). This is deliberate while published versions may reference them. The purge belongs to M12 (noted in its plan).

## Change log

- 2026-11-14: Plan created.
- 2026-11-14: Done. Storage rules, `processImage` (sharp), core media widgets and services, dev page, and unit, emulator, rules and Chrome end-to-end tests. One Flutter cropper instead of `image_cropper`; devices refuse files over 5 MB rather than shrinking them; image objects gain `reason` and `uploadedAt`.
