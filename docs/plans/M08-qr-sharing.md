# M08 – QR codes and sharing

Status: Not started
Started:
Completed:

## Goal

Owners preview and download their permanent QR code as PNG or a print-ready PDF poster or table card, optionally with their logo, and share the menu link on WhatsApp or any app.

## FRD coverage

FR-047 to FR-054, FR-067 to FR-070, BR-006, §5.1 steps 13–15, AC-010, AC-011, AC-014.

## Depends on

M07.

## Inputs from other modules

- M01: `qrCode` on the restaurant (never changes).
- M03 (done 2026-11-14): the dashboard's QR card links to `Routes.share` and shows `menuUrl(slug)` (`features/restaurant/presentation/menu_link_page.dart`, built on `AppEnv.menuBaseUrl`). The menu link page explains that the QR code keeps working after a slug change.
- M07: `/q/{code}` redirect and link previews.
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

- [ ] QR widget and image export.
- [ ] Logo overlay with decode check and fallback.
- [ ] A4 and A6 PDF templates using brand fonts and the restaurant's theme colour.
- [ ] Download on web (browser download), save/share on Android and iOS.
- [ ] Copy, WhatsApp and native share actions.
- [ ] Dashboard shortcut card to this screen.

## Acceptance checks

- [ ] AC-010: PNG and both PDFs download and scan correctly on Android and iPhone camera apps.
- [ ] AC-011: the same printed code still works after content changes, a publish and a slug change.
- [ ] AC-014: WhatsApp share opens with the link; the link shows a rich preview.
- [ ] A logo QR that fails to decode is never offered.

## Tests

Unit test: encoded URL is the `/q/` URL. Test that generated PNGs decode back to that URL (with and without logo). Widget tests of the screen at 3 widths.

## Completion notes

_Fill in when done._

## Open items

## Change log

- 2026-11-14: Plan created.
