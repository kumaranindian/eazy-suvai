# M13 – Hardening, acceptance and launch

Status: Not started
Started:
Completed:

## Goal

Prove the MVP meets the FRD: all 30 acceptance criteria pass, performance and security targets are met, monitoring and backups are on, and the apps are live.

## FRD coverage

§7 (all non-functional requirements), §10 (AC-001 to AC-030), §13 (success metrics).

## Depends on

All other modules marked Done.

## Inputs from other modules

Every module's Completion notes and Open items.

## Tasks

### Quality

- [ ] Run every acceptance criterion AC-001 to AC-030 and record the result and evidence in the table below.
- [ ] Integration test suite covering: sign-up → profile → menu → publish → scan → analytics; downgrade and upgrade; suspension.
- [ ] Responsive pass: every owner screen at 360, 768 and 1280 px on web, plus one Android phone, one iPhone and one tablet.
- [ ] Accessibility pass: screen reader labels, contrast, keyboard use on web, text scaling to 200%.
- [ ] Localization readiness: no hard-coded strings; a pseudo-locale and an RTL test locale render without layout breaks.

### Security

- [ ] Rules tests for every collection, including cross-tenant attempts (AC-017).
- [ ] App Check enabled for Firestore, Storage and Functions (Play Integrity, App Attest, reCAPTCHA Enterprise on web).
- [ ] Review callable input validation and error messages for information leaks.
- [ ] Dependency audit (`flutter pub outdated`, `npm audit`).

### Performance and reliability

- [ ] Lighthouse on 3 real restaurant menus: LCP ≤ 2.5 s (4G), payload ≤ 150 KB, accessibility ≥ 95.
- [ ] Load test the public menu (for example k6) at 200 requests/s mostly served from the CDN.
- [ ] Firestore point-in-time recovery and daily exports to a Cloud Storage bucket; one test restore.
- [ ] Cloud Monitoring alerts: function error rate, `renderMenu` 5xx rate and latency, uptime check on a sample menu.
- [ ] Crashlytics in the owner app.

### Launch

- [ ] Production Firebase project configured: domains, Hosting sites, email templates (verification, reset) with the brand, Identity Platform MFA.
- [ ] Seed production plans, labels, tags, themes and config.
- [ ] Privacy policy and terms pages linked from sign-up and the public footer.
- [ ] Play Store and App Store listings (owner app), with screenshots at phone and tablet sizes.
- [ ] Success-metric counters (FRD §13) visible on the admin dashboard.

## Acceptance results

| AC | Result | Evidence / notes |
| --- | --- | --- |
| AC-001 | | |
| AC-002 | | |
| AC-003 | | |
| AC-004 | | |
| AC-005 | | |
| AC-006 | | |
| AC-007 | | |
| AC-008 | | |
| AC-009 | | |
| AC-010 | | |
| AC-011 | | |
| AC-012 | | |
| AC-013 | | |
| AC-014 | | |
| AC-015 | | |
| AC-016 | | |
| AC-017 | | |
| AC-018 | | |
| AC-019 | | |
| AC-020 | | |
| AC-021 | | |
| AC-022 | | |
| AC-023 | | |
| AC-024 | | |
| AC-025 | | |
| AC-026 | | |
| AC-027 | | |
| AC-028 | | |
| AC-029 | | |
| AC-030 | | |

## Completion notes

_Fill in when done._

## Open items

## Change log

- 2026-11-14: Plan created.
