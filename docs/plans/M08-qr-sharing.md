# M08 – QR codes and sharing

Status: Done
Started: 2026-11-15
Completed: 2026-11-15

## Goal

Owners preview and download their permanent QR code as PNG or a print-ready PDF poster or table card, optionally with their logo, and share the menu link on WhatsApp or any app.

## FRD coverage

FR-047 to FR-054, FR-067 to FR-070, BR-006, §5.1 steps 13–15, AC-010, AC-011, AC-014.

## Depends on

M07.

## Inputs from other modules

- M01: `qrCode` on the restaurant (never changes).
- M03 (done 2026-11-14): the dashboard's QR card links to `Routes.share` and shows `menuUrl(slug)` (`features/restaurant/presentation/menu_link_page.dart`, built on `AppEnv.menuBaseUrl`). The menu link page explains that the QR code keeps working after a slug change.
- M07 (done 2026-11-15):
  - `/q/{code}` answers 302 to `/{current-slug}?src=qr`, in any letter case, so a printed code follows slug changes (AC-011). Unknown codes give 404.
  - Link previews (AC-014, FR-070) come from the slug page: `og:title` "{Name} – Menu | EazySuvai", `og:description`, `og:image` (cover at 1280 px, else logo at 640 px) and `twitter:card`.
  - Share the canonical slug URL (`menuUrl(slug)`) in text; the QR code encodes `{menuBaseUrl}/q/{qrCode}`.
  - Before the first publish, the slug page is the 404 "Menu coming soon" (FR-049).
- M10 (later): `limits.qrLogo` (logo in the QR is a Pro feature).

## Scope

**In:** QR screen, PNG and PDF generation in the app, logo overlay with a decode check, share actions.
**Out:** table QR codes (Phase 2; FR-094 notes the same mechanism).

## Data and backend

- The QR always encodes `https://menu.eazysuvai.com/q/{code}`, never the slug.
- Generation in Flutter: `qr_flutter` (or `qr` + custom painter) for the code; `pdf` + `printing` packages for PDFs.
- PNG: at least 1024×1024 px, quiet zone of 4 modules.
- With logo: error correction level H, logo at most 20% of the area, white padding behind it. Before offering the download, decode the rendered image (`zxing2` or `mobile_scanner`'s image analysis on mobile, a Dart decoder on web). If decoding fails, fall back to the plain code and tell the owner.
- PDF templates (FR-050): A4 poster and A6 table card with restaurant name, logo, the code, "Scan to view our menu", and the short URL in text.
- Share: copy link (clipboard + snackbar); WhatsApp via `https://wa.me/?text=` with a localized prefilled message; native share sheet with `share_plus` (Web Share API on web).

## Screens and responsive behaviour

| Screen | Compact | Expanded |
| --- | --- | --- |
| QR and sharing | QR preview on top, options (logo on/off, template), buttons stacked: Download PNG, Download PDF, Share, Copy link | Preview left at 360 px, options and actions right |
| Template preview | Full-screen PDF preview | Dialog with PDF preview |

## Tasks

- [x] QR widget and image export.
- [x] Logo overlay with decode check and fallback.
- [x] A4 and A6 PDF templates using brand fonts and the restaurant's theme colour.
- [x] Download on web (browser download), save/share on Android and iOS.
- [x] Copy, WhatsApp and native share actions.
- [x] Dashboard shortcut card to this screen.

## Acceptance checks

- [ ] AC-010: PNG and both PDFs download and scan correctly on Android and iPhone camera apps.
- [x] AC-011: the same printed code still works after content changes, a publish and a slug change.
- [ ] AC-014: WhatsApp share opens with the link; the link shows a rich preview.
- [x] A logo QR that fails to decode is never offered.

## Tests

Unit test: encoded URL is the `/q/` URL. Test that generated PNGs decode back to that URL (with and without logo). Widget tests of the screen at 3 widths.

## Completion notes

**What was built** (owner app, `lib/features/qr/`; route `/share`, the "QR & share" tab)

- **`domain/qr_link.dart`**:
  - `qrUrlFor(code)` gives `{AppEnv.menuBaseUrl}/q/{CODE}` (upper case). It never uses the slug (FR-047, BR-006).
  - `shortUrlText(url)` is the URL without the scheme, for print.
  - `whatsAppShareUri(message)` gives `https://wa.me/?text=…`.
  - `fileSlug(name)` makes file names (`spice-garden-qr.png`, `…-poster-a4.pdf`, `…-table-card-a6.pdf`).
- **`application/qr_image.dart`** (pure Dart: `qr`, `image` and `zxing2`, so it runs the same on web, Android, iOS and in tests):
  - `renderQrPng(data, {logo})`: black on white, a 4-module quiet zone, and at least 1024 px (the module size is rounded up, so the PNG is a little over 1024 px: 1035 px for a production `/q/` URL with a logo). Error correction is M for the plain code and H with a logo.
  - With a logo: a white rounded pad covers 18 % of the symbol area (the FR-053 limit is 20 %, `qrMaxLogoArea`). The logo keeps its aspect ratio inside the pad. Any format `image` reads works, including the WebP renditions.
  - `decodeQrImage(png)` tries the hybrid binarizer, then the global-histogram one.
  - `qrDecodesTo(png, url)` must decode at full size **and** scaled down to 360 px (a small print or a distant phone).
  - `buildQrArtifact(QrJob)` returns the logo version only if it passes; otherwise the plain code with `logoRejected`. An undecodable logo file falls back the same way.
- **`application/qr_pdf.dart`**: `buildQrPdf(QrTemplate.poster | tableCard, input)` with the `pdf` package.
  - A4 or A6, one page: a header band in the theme's primary colour with the logo on a white tile and the name in the readable colour on it (`onPrimary`, FR-060).
  - Then "Scan to view our menu", the checked QR PNG at full resolution in a primary-coloured frame (340 pt on A4, 180 pt on A6), "or visit" and the short `/q/` URL.
  - Poppins Regular and SemiBold are bundled in `assets/fonts/` with `OFL.txt` (SIL OFL 1.1).
- **`application/qr_providers.dart`**:
  - `qrUrlProvider`, `qrLogoChoiceProvider` (off by default), `qrTemplateChoiceProvider` and `qrLogoBytesProvider`.
  - `qrStateProvider` gives `QrState(artifact, logoLoadFailed)`. It is built through `qrArtifactBuilderProvider`: `compute()` in an isolate on mobile; tests run it directly.
  - `qrPdfProvider((template, scanToView, orVisit))` takes its colours from M05's `resolvedThemeProvider`.
- **`data/`**:
  - `QrShareActions` (`qrShareActionsProvider`):
    - copy to the clipboard;
    - WhatsApp through `url_launcher` (external app);
    - `shareText` through `share_plus`. On web this is the Web Share API. It reports `unsupported` when `navigator.share` is missing, and the screen then copies the link instead.
    - `saveFile`: on web a Blob `<a download>` (`platform_web.dart`, `package:web`); on Android and iOS the share sheet with the file (`platform_io.dart`), which offers Save to Files / Save image / Drive / print.
  - `QrLogoLoader` (`qrLogoLoaderProvider`) downloads the 640 px logo rendition with `FirebaseStorage.ref(path).getData`.
  - `qrFontsProvider` loads the bundled fonts.
- **`presentation/`**:
  - `QrSharePage`:
    - The preview card shows the PNG itself (what is downloaded), its size, "with your logo" when used, and why the code survives slug changes.
    - Before the first publish, a note says scans show "Menu coming soon" (FR-049).
    - Download and print: the logo switch (disabled with a hint when there is no ready logo; it shows the fallback reason), Download PNG, the template choice (A4 poster / A6 table card), Preview and Download PDF.
    - Share: the canonical slug link, Copy link, WhatsApp, Share….
    - Layout: one column below 680 px of content (phones and tablets with the rail), 360 px preview left and options right on desktop.
  - `showQrPdfPreview`: a full-screen page on compact windows and a dialog otherwise, with Download PDF in the app bar. It shows the PDF through `printing`'s `PdfPreview` (`qrPdfViewBuilderProvider`; pdf.js on web).
  - `QrMiniView`: a vector QR on the dashboard's existing QR card (M03). Tapping it opens `/share`.
- **Strings:** 34 in `app_en.arb` (`qr…`). The WhatsApp / share message is "Take a look at the menu of {name}: {url}".
- **Dependencies (owner app):**
  - `qr` 3.0.3, `zxing2` 0.2.4, `pdf` 3.11.3, `printing` 5.14.3, `share_plus` 12.0.2, `url_launcher` 6.3.2.
  - `image` (now a normal dependency) is **4.5.4**. **Core's constraint went from `^4.13.0` to `^4.5.0`**: `pdf` versions that accept `image` 4.6 and later need Dart 3.12 and a newer `vector_math` than Flutter 3.32 pins. Core's media tests pass on 4.5.4.

**What the QR code encodes and what is shared**

| Where | URL |
| --- | --- |
| QR code (PNG, PDFs, dashboard thumbnail) | `{menuBaseUrl}/q/{qrCode}`. M07 answers 302 to the current slug, so slug changes don't matter (AC-011) |
| Printed text on the PDFs | the same `/q/` URL without `https://` |
| Copy, WhatsApp, Share… | the canonical `{menuBaseUrl}/{slug}`: it carries the Open Graph preview (FR-070) and is the indexable URL |

**Tests** (all passing at completion)

| Suite | Tests | M08 additions |
| --- | --- | --- |
| Owner app | 194 | `qr_image_test.dart` (9): `/q/` URL (never the slug), short URL, WhatsApp link, file names; plain PNG ≥ 1024 px with a white quiet zone and level M that decodes; logo version level H, ≤ 20 % area, decodes; wide logo; fallback when the logo version fails the check or the logo file is broken; plain code that fails throws. `qr_pdf_test.dart` (5): A4 and A6 page sizes, the full-size QR and the logo embedded, Poppins embedded (no Helvetica), no logo image without a logo, colours. `qr_share_test.dart` (17): the screen at 360 / 768 / 1280 (decodes the PNG shown, layout, 48 px buttons), the not-published note, PNG download (≥ 1024 px, decodes, file name), logo on (decodes) / fallback / load failure, both PDFs, preview as a page (360) and a dialog (1280), copy, WhatsApp (and the copy fallback), share sheet (and the copy fallback), the dashboard thumbnail |
| Core | 222 | – (rerun on `image` 4.5.4) |
| Admin app | 19 | – |
| End to end (Chrome) | 6 of 6 | – (rerun after M07's renderer changes) |
| Functions / rules | 267 unit, 96 emulator, 149 rules | – |

`flutter build web` succeeds (the `package:web` download path compiles).

**Decisions that differ from the plan**

1. **Decoding uses `zxing2` everywhere** (pure Dart), not `mobile_scanner` on mobile. One decoder means one behaviour and lets the tests run. The check is stricter than one decode: full size and 360 px.
2. **The logo covers 18 %, not 20 %.** This leaves a margin for print and blur; 20 % is the hard limit in the code.
3. **The plain code uses error correction M** (H only with a logo, as the plan says). M gives a less dense code that scans better from a distance.
4. **Shared links are the slug URL; the QR code is the `/q/` URL.** Shared text should show the restaurant's name and get the rich preview (FR-070); the QR code must survive slug changes (BR-006).
5. **"Download" on Android and iOS opens the share sheet** with the file (Save to Files, Save image, Drive, print). The app needs no storage permission, and it is the platform's normal save path.
6. **Desktop only for two panes.** At 768 px the content beside the navigation rail is under 680 px, too narrow for a 360 px preview plus the template buttons, so tablets get the stacked layout.
7. **The dashboard card already existed (M03).** It gains a live QR thumbnail that opens the screen.
8. **Logo in the QR is open to every plan for now.** M10 gates it with `limits.qrLogo` (see Cross-module notes).

## Open items

- **AC-010 on real phones (needs you):** scan the downloaded PNG (on screen and printed), the A4 poster and the A6 table card with the stock camera on an Android phone and an iPhone, with and without the logo. Also check:
  - on Android and iOS, Download PNG / PDF opens the share sheet and "Save to Files" / "Save image" works;
  - on desktop Chrome, Safari and Firefox, the PNG and PDF download with the right names.
- **AC-014 needs the deployed menu:** WhatsApp opens with the message and the link (mobile app and WhatsApp Web), and the link shows the preview (name, description, cover). WhatsApp caches previews, so test with a newly published menu.
- **PDF look:** the templates are tested structurally (page size, embedded QR, fonts) but were not rendered here. Open both PDFs once and check the spacing, then print the A6 card at 100 % (no "fit to page").
- **Names in non-Latin scripts** (Tamil, Hindi, Arabic) have no glyphs in Poppins, so the PDF header would show empty boxes. The app UI and the menu page are fine. Fix: bundle Noto Sans fonts for the scripts in use as `fontFallback` (about 100–300 KB each). Decide which scripts to support first.
- **Web: the logo comes from Storage**, so the bucket's CORS policy (`storage.cors.json`, M02) must be applied, or the logo switch falls back to the plain code with "We couldn't load your logo".
- **Web Share on desktop:** Chrome on Windows and macOS has it, Firefox doesn't. Without it, "Share…" copies the link and says so.

## Change log

- 2026-11-14: Plan created.
- 2026-11-15: Done. QR & share screen at 3 widths: a ≥ 1024 px PNG of the `/q/` URL with a 4-module quiet zone, an optional logo (level H, 18 % area) offered only after a zxing2 decode at full size and 360 px (else plain, with the reason), A4 poster and A6 table card PDFs (Poppins, theme colour, short URL) with a preview, browser download on web and the share sheet on mobile, copy / WhatsApp / native share of the slug link. Core's `image` constraint lowered to ^4.5.0 for `pdf` 3.11. Open: scanning on real phones (AC-010), WhatsApp preview on the deployed site (AC-014).
