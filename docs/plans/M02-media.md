# M02 – Media management

Status: Not started
Started:
Completed:

## Goal

One reusable image pipeline for logos, covers, category and item images: pick, crop, upload, validate, generate web renditions, and show progress and errors.

## FRD coverage

FR-031, FR-032, FR-102, §7.1 (optimised responsive images), §7.2 (file upload validation), AC-005.

## Depends on

M00.

## Inputs from other modules

- M00 (done 2026-11-14): `storage.rules` denies everything. Open `restaurants/{rid}/images/**` and update the Storage expectations in `firestore-tests/test/baseline.test.js`.
- M01 provides the `restaurantId` claim used in storage paths and rules (can be stubbed with emulator claims while building).

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

- [ ] Image object model in `packages/core`.
- [ ] `ImagePickerField` with crop (`image_cropper` on mobile, a web-compatible cropper on web), preview, replace, remove.
- [ ] Upload service with progress stream and cancel.
- [ ] Storage rules and rules tests.
- [ ] `processImage` with type, size and dimension checks, EXIF strip and renditions.
- [ ] `ResponsiveImage` widget that chooses the right rendition for its width and shows a placeholder while processing.
- [ ] Localized error messages for each rejection reason.

## Acceptance checks

- [ ] AC-005: JPEG, PNG and WebP up to 5 MB upload and display; a 6 MB file and a renamed PDF are rejected with clear messages.
- [ ] Renditions exist at 320/640/1280 px and the original has no EXIF.
- [ ] Another restaurant's owner cannot write to this restaurant's image path.
- [ ] Works on web, Android and iOS.

## Tests

Functions: `processImage` with valid, oversized, wrong-type and too-small images. Storage rules tests. Widget test of `ImagePickerField` states.

## Completion notes

_Fill in when done._

## Open items

## Change log

- 2026-11-14: Plan created.
