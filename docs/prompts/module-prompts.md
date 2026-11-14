# EazySuvai – Implementation prompts

One prompt per module. Use them with an AI coding agent (Claude Code, Cursor or similar) opened at the repository root.

## How to use

1. Put `AGENTS.md`, `CLAUDE.md` and the `docs/` folder at the root of the repository and commit them.
2. Build the modules in order (see `docs/plans/00-master-plan.md`). Start a **new agent session for each module**, so its context stays small.
3. Paste the module's prompt. Let the agent work, answer its questions, and review its changes.
4. When the agent says the module is done, run the **Review prompt** at the end of this file in a fresh session. It checks the work against the plan and makes sure the plan was updated.
5. Commit the code and the updated plan files together.

Every prompt below ends with the same **Definition of done**, so each one can be pasted on its own.

---

## M00 – Foundation and project setup

```text
You are building EazySuvai, a multi-tenant SaaS for restaurant digital menus with QR codes.

Read these files first, in full: AGENTS.md, docs/architecture.md, docs/plans/00-master-plan.md, docs/plans/M00-foundation.md. Skim docs/FRD-v1.1.md sections 6, 7 and 12.

Implement module M00 – Foundation and project setup, exactly as its plan describes:
- A Dart pub workspace with apps/owner_app (web, Android, iOS), apps/admin_app (web) and packages/core.
- Firebase configuration for two projects (eazysuvai-dev, eazysuvai-prod) selected with --dart-define=ENV, firebase.json with Firestore, Storage, Functions in asia-south1, Hosting sites app/admin/menu, and the Emulator Suite.
- Deny-all firestore.rules and storage.rules with a rules-test project.
- A TypeScript functions project (Node 20, ESLint, Jest, zod) with the shared helpers writeAudit, assertAdmin, assertOwner.
- In packages/core: Money (integer minor units + ISO 4217 code, correct decimals per currency, KWD = 3), TimeService, Breakpoint + ResponsiveScaffold (bottom bar < 600 px, navigation rail 600–1023 px, side menu ≥ 1024 px), AppTheme from the brand colours in docs/architecture.md, and shared state widgets.
- Localization with .arb files and direction-neutral layout only.
- CI that runs analyze, tests, functions tests and rules tests.

Before writing code, give me a short plan of the files you will create and any choice you need from me. Then build it.

Definition of done:
1. Every task and acceptance check in docs/plans/M00-foundation.md is done and ticked, or listed under Open items with the reason.
2. All tests pass; screens work at 360, 768 and 1280 px.
3. Update docs/plans/M00-foundation.md: Status Done, Completed date, Completion notes (what you built, key files, decisions that differ from the plan), Change log line.
4. Update the M00 row in docs/plans/00-master-plan.md and add Cross-module notes for anything later modules must know.
5. Finish with a short summary for me: what works, how to run it, and what I should check by hand.
```

---

## M01 – Authentication and accounts

```text
Continue building EazySuvai. Read AGENTS.md, docs/architecture.md (sections 4, 5, 7), docs/plans/00-master-plan.md and docs/plans/M01-authentication.md in full, plus FRD sections 4.1 and 5.1 in docs/FRD-v1.1.md. Check that M00 is Done and read its Completion notes.

Implement module M01 – Authentication and accounts:
- Owner sign-up collecting the FR-002 fields with validation (email, mobile by country).
- The completeRegistration callable that, in one transaction, creates users/{uid} and restaurants/{rid} on the Free plan, reserves a slug (FR-092 rules, reserved words from config/platform, city then number suffix on collision) and a permanent 8-character QR code, sets custom claims {role: 'owner', restaurantId}, and sends the verification email.
- Email verification is required before login (FR-091): unverified users are signed out and offered a resend. Firestore rules must also deny unverified tokens.
- Login, logout, password reset, router guards, Firebase error codes mapped to localized messages.
- cleanupUnverifiedUsers: delete accounts unverified for 7 days with their restaurant, slug and QR code.
- Admin app login with TOTP multi-factor authentication (Identity Platform).
- Responsive layouts as described in the plan (brand panel + form on wide screens).

Ask me before enabling any paid Firebase feature. Show me your file plan first, then build.

Definition of done:
1. Every task and acceptance check in docs/plans/M01-authentication.md is done and ticked, or listed under Open items with the reason.
2. All tests pass (functions, rules, widget, integration on emulators); screens work at 360, 768 and 1280 px.
3. Update docs/plans/M01-authentication.md: Status Done, Completed date, Completion notes, Change log line.
4. Update the M01 row in docs/plans/00-master-plan.md and add Cross-module notes (for example the exact claim names and the restaurant fields you created).
5. Finish with a short summary: what works, how to test it, what I should check by hand.
```

---

## M02 – Media management

```text
Continue building EazySuvai. Read AGENTS.md, docs/architecture.md (sections 4.4 and 5), docs/plans/00-master-plan.md and docs/plans/M02-media.md in full, plus FR-031, FR-032 and FR-102 in docs/FRD-v1.1.md. Check the Completion notes of M00 and M01.

Implement module M02 – Media management:
- A reusable ImagePickerField (pick, crop to a given aspect ratio, preview, replace, remove) that works on web, Android and iOS, and a ResponsiveImage widget that picks the right rendition.
- An upload service with progress and cancel; client-side downscale of very large images.
- Storage rules: owner-only paths under restaurants/{rid}/images, JPEG/PNG/WebP only, 5 MB max; with rules tests.
- The processImage Storage trigger using sharp: check real file type by magic bytes, minimum dimensions by purpose (logo 256×256, cover 1200×400, item/category 400×400), strip EXIF, write WebP renditions at 320/640/1280 px, and update the target document's image object (ready or rejected with a reason code). The target document must be inside the same restaurant.

Show me your file plan first, then build.

Definition of done:
1. Every task and acceptance check in docs/plans/M02-media.md is done and ticked, or listed under Open items with the reason.
2. All tests pass; the widgets work at 360, 768 and 1280 px.
3. Update docs/plans/M02-media.md: Status Done, Completed date, Completion notes, Change log line.
4. Update the M02 row in docs/plans/00-master-plan.md and add Cross-module notes (widget APIs, image object shape).
5. Finish with a short summary: what works, how to test it, what I should check by hand.
```

---

## M03 – Restaurant onboarding and profile

```text
Continue building EazySuvai. Read AGENTS.md, docs/architecture.md (sections 4.2 and 5), docs/plans/00-master-plan.md and docs/plans/M03-restaurant-profile.md in full, plus FRD sections 4.1, 4.2, 5.1 and 6 in docs/FRD-v1.1.md. Check the Completion notes of M01 and M02.

Implement module M03 – Restaurant onboarding and profile:
- A first-run setup wizard and a dashboard home with a setup checklist.
- The profile editor with every FR-011 field, validation by country, autosave to the draft with a "Saved" indicator, visibility toggles (FR-013), opening hours (up to 3 slots per day or closed), logo and cover via M02's ImagePickerField.
- Currency and time zone settings with the FR-103 warning; the onRestaurantUpdated trigger sets pricesNeedReview when currency changes after a publish, and keeps nameLower in sync.
- Menu URL editor and the changeSlug callable (FR-092 format, reserved words, availability, old slug kept with current: false for 301 redirects, audit entry).
- Rules tests proving owners cannot change status, planId, slug, counts, qrCode or publishedVersion.
- Responsive layouts from the plan (stepper on the left and live header preview on wide screens).

Show me your file plan first, then build.

Definition of done:
1. Every task and acceptance check in docs/plans/M03-restaurant-profile.md is done and ticked, or listed under Open items with the reason.
2. All tests pass; screens work at 360, 768 and 1280 px.
3. Update docs/plans/M03-restaurant-profile.md: Status Done, Completed date, Completion notes, Change log line.
4. Update the M03 row in docs/plans/00-master-plan.md and add Cross-module notes.
5. Finish with a short summary: what works, how to test it, what I should check by hand.
```

---

## M04 – Menu management

```text
Continue building EazySuvai. Read AGENTS.md, docs/architecture.md (sections 4.2, 4.3 and 5), docs/plans/00-master-plan.md and docs/plans/M04-menu-management.md in full, plus FRD sections 4.3, 4.4, 4.8 (FR-095) and 5.3–5.4 in docs/FRD-v1.1.md. Check the Completion notes of M02 and M03.

Implement module M04 – Menu management:
- Categories and items with every FR-016 and FR-022 field, field length limits, dietary labels (Vegetarian, Non-vegetarian, Vegan, Contains egg; icon + text) and tags seeded from platform collections.
- Callables createCategory and createItem that check plan limits inside a transaction; deleteCategory with move or delete-all (typed confirmation); moveItems; restoreDeleted. Clients may only update whitelisted fields; they cannot create or hard-delete.
- Triggers that keep counts, draftUpdatedAt and the live/availability overlay.
- Price input that accepts exactly the currency's decimals and stores integer minor units (KWD 1.250 → 1250).
- Availability switch on each item row with optimistic UI; "Sold out" filter; bulk availability and bulk move on wide screens.
- Drag-and-drop reorder with keyboard alternatives; Recently deleted screen with 30-day restore.
- Layout: single column on phones, two panes on tablets, three panes (categories, items, editor) on desktop.

Show me your file plan first, then build.

Definition of done:
1. Every task and acceptance check in docs/plans/M04-menu-management.md is done and ticked, or listed under Open items with the reason.
2. All tests pass, including concurrent creates at the plan limit; screens work at 360, 768 and 1280 px.
3. Update docs/plans/M04-menu-management.md: Status Done, Completed date, Completion notes, Change log line.
4. Update the M04 row in docs/plans/00-master-plan.md and add Cross-module notes (callable names and signatures for M06 and M10).
5. Finish with a short summary: what works, how to test it, what I should check by hand.
```

---

## M05 – Menu customization

```text
Continue building EazySuvai. Read AGENTS.md, docs/architecture.md, docs/plans/00-master-plan.md and docs/plans/M05-customization.md in full, plus FRD section 4.7 in docs/FRD-v1.1.md. Check the Completion notes of M03.

Implement module M05 – Menu customization:
- Theme model and at least 6 seeded themes (2 non-premium for the Free plan).
- Theme gallery and theme editor: primary, secondary and background colours with hex input, font from the curated list, menu layout, card layout, light/dark mode.
- A WCAG contrast utility shared by Dart and the functions code; low contrast shows a warning and the text colour is adjusted automatically.
- A live preview widget using real menu data, phone and desktop sizes on wide screens, full-screen on phones.
- Autosave to the draft.

Show me your file plan first, then build.

Definition of done:
1. Every task and acceptance check in docs/plans/M05-customization.md is done and ticked, or listed under Open items with the reason.
2. All tests pass; screens work at 360, 768 and 1280 px.
3. Update docs/plans/M05-customization.md: Status Done, Completed date, Completion notes, Change log line.
4. Update the M05 row in docs/plans/00-master-plan.md and add Cross-module notes (theme token names that M07 must use).
5. Finish with a short summary: what works, how to test it, what I should check by hand.
```

---

## M06 – Preview, publishing and versions

```text
Continue building EazySuvai. Read AGENTS.md, docs/architecture.md (sections 3 and 4.2), docs/plans/00-master-plan.md and docs/plans/M06-publishing.md in full, plus FRD section 4.8, BR-003 and section 7.4 in docs/FRD-v1.1.md. Check the Completion notes of M03, M04 and M05.

Implement module M06 – Preview, publishing and versions:
- A pure, unit-tested snapshot builder (public profile fields respecting visibility, contrast-fixed theme tokens, active categories and visible items in sequence order, image rendition URLs, currency and locale).
- publishMenu with a dry-run mode returning the change summary and every validation problem with stable codes (empty menu, missing fields, plan limits, unverified email, unreviewed prices). A real publish writes versions/{n+1}, sets publishedVersion and resets live/availability in one transaction, prunes to the last 10 versions, and writes an audit entry.
- rollbackMenu and discardDraft.
- A persistent "Unpublished changes · Preview · Publish" bar, a publish dialog with the change summary and "Fix" links, a draft preview (noindex) and a version history screen.

Show me your file plan first, then build.

Definition of done:
1. Every task and acceptance check in docs/plans/M06-publishing.md is done and ticked, or listed under Open items with the reason.
2. All tests pass; screens work at 360, 768 and 1280 px.
3. Update docs/plans/M06-publishing.md: Status Done, Completed date, Completion notes, Change log line.
4. Update the M06 row in docs/plans/00-master-plan.md and add Cross-module notes (the exact snapshot JSON shape for M07).
5. Finish with a short summary: what works, how to test it, what I should check by hand.
```

---

## M07 – Public digital menu

```text
Continue building EazySuvai. Read AGENTS.md, docs/architecture.md (sections 2 and 3), docs/plans/00-master-plan.md and docs/plans/M07-public-menu.md in full, plus FRD sections 4.5, 4.13 (FR-099), 7.1 and 7.6 in docs/FRD-v1.1.md. Read the Completion notes of M06 for the snapshot shape.

Implement module M07 – the public menu. It is NOT Flutter: it is server-rendered HTML from the renderMenu Cloud Function behind the Firebase Hosting "menu" site.
- Routes: /{slug} (old slugs answer 301), /q/{code} (302 to /{slug}?src=qr), /sitemap.xml, /robots.txt.
- Data: slug → restaurant (status) → current version → live availability overlay.
- Page: header (cover, logo, name, description, visible contacts, "Open now" in the restaurant's time zone), sticky category bar (sidebar on desktop), featured section, items in the theme's layout with lazy srcset images, prices formatted with the restaurant's currency and locale, dietary icon + text, tags, unavailable items dimmed and labelled, image lightbox, footer.
- All FR-099 states with the right HTTP code and noindex.
- SEO: title, meta description, canonical, Open Graph/Twitter, JSON-LD Restaurant → Menu → MenuSection → MenuItem, sitemap of active published menus.
- Cache-Control: public, max-age=0, s-maxage=60. Escape every value. Inline critical CSS; JavaScript under 10 KB; the page must work without JavaScript.
- Lighthouse CI budget: LCP ≤ 2.5 s on simulated 4G, initial payload ≤ 150 KB, accessibility ≥ 95.

Show me your file plan first, then build.

Definition of done:
1. Every task and acceptance check in docs/plans/M07-public-menu.md is done and ticked, or listed under Open items with the reason.
2. All tests pass, including template snapshot tests for each state and the Lighthouse budget; the page works at 360, 768 and 1280 px.
3. Update docs/plans/M07-public-menu.md: Status Done, Completed date, Completion notes, Change log line.
4. Update the M07 row in docs/plans/00-master-plan.md and add Cross-module notes (where M09's beacon hooks in).
5. Finish with a short summary: what works, how to test it, what I should check by hand on real phones.
```

---

## M08 – QR codes and sharing

```text
Continue building EazySuvai. Read AGENTS.md, docs/plans/00-master-plan.md and docs/plans/M08-qr-sharing.md in full, plus FRD sections 4.6 and 4.9 in docs/FRD-v1.1.md. Check the Completion notes of M01 and M07.

Implement module M08 – QR codes and sharing in the owner app:
- The QR always encodes https://menu.eazysuvai.com/q/{code} (from the restaurant's permanent qrCode), never the slug.
- Preview; PNG download at least 1024×1024 px with a proper quiet zone; print-ready PDFs (A4 poster and A6 table card) with the restaurant name, logo, "Scan to view our menu" and the short URL.
- Optional logo in the centre: error correction H, logo at most 20% of the area. Decode the rendered image before offering it; if decoding fails, fall back to the plain code and tell the owner.
- Copy link, WhatsApp share with a localized prefilled message, and the native share sheet (Web Share on web).
- Downloads work on web, Android and iOS.

Show me your file plan first, then build.

Definition of done:
1. Every task and acceptance check in docs/plans/M08-qr-sharing.md is done and ticked, or listed under Open items with the reason.
2. All tests pass, including decoding generated PNGs back to the /q/ URL; screens work at 360, 768 and 1280 px.
3. Update docs/plans/M08-qr-sharing.md: Status Done, Completed date, Completion notes, Change log line.
4. Update the M08 row in docs/plans/00-master-plan.md and add Cross-module notes.
5. Finish with a short summary: what works, how to test it, and which phones I should scan with.
```

---

## M09 – Analytics

```text
Continue building EazySuvai. Read AGENTS.md, docs/architecture.md (section 4), docs/plans/00-master-plan.md and docs/plans/M09-analytics.md in full, plus FRD section 4.10 in docs/FRD-v1.1.md. Check the Completion notes of M07.

Implement module M09 – Analytics:
- A beacon script (under 1 KB, no cookies, no third-party scripts) in the public menu template: view (with src qr/direct, once per session per 30 minutes using sessionStorage), category taps, item opens; sent with navigator.sendBeacon to POST /e.
- The collectEvent function: validate, drop bots, rate-limit, increment restaurants/{rid}/analyticsDaily/{date} using the restaurant's time zone for the date, write raw events with expireAt (90-day TTL), increment platform menu views. Never store IP addresses or user agents.
- The owner analytics screen: 7-day, 30-day and custom ranges (limited by the plan's analyticsDays), summary tiles, daily chart (fl_chart), top categories and items, empty states, upgrade prompt for longer ranges.
- Rules: only the owner and admins can read analytics; clients cannot write.

Show me your file plan first, then build.

Definition of done:
1. Every task and acceptance check in docs/plans/M09-analytics.md is done and ticked, or listed under Open items with the reason.
2. All tests pass; screens work at 360, 768 and 1280 px.
3. Update docs/plans/M09-analytics.md: Status Done, Completed date, Completion notes, Change log line.
4. Update the M09 row in docs/plans/00-master-plan.md and add Cross-module notes.
5. Finish with a short summary: what works, how to test it, what I should check by hand.
```

---

## M10 – Subscriptions and plan limits

```text
Continue building EazySuvai. Read AGENTS.md, docs/architecture.md, docs/plans/00-master-plan.md and docs/plans/M10-subscriptions.md in full, plus FRD sections 4.11 and 5.5 in docs/FRD-v1.1.md. Check the Completion notes of M04, M05, M07, M08, M09 and (if done) M11.

Implement module M10 – Subscriptions and plan limits:
- Seed the Free and Pro plans from the table in the plan file. Add a shared getPlanLimits() and switch M04's create callables to it. Gate premium themes, QR logo, analytics range and the Free-plan footer by plan flags.
- requestUpgrade (owner), recordPaymentAndActivate and changeSubscription (admin, audit-logged).
- subscriptionDaily: reminder emails 14, 7 and 1 days before expiry; grace period (config/platform.graceDays, default 14); automatic downgrade to Free when grace ends.
- applyPlanLimits: hide over-limit items and categories (last in display order first) without deleting them, revert premium themes, publish a new version, notify the owner. Upgrades clear the hidden flags and prompt a publish.
- Owner plan screen with usage bars, plan comparison, banners and an over-limit manager; admin upgrade-request queue and record-payment form in the admin app.
- No online payments in the MVP.

Show me your file plan first, then build.

Definition of done:
1. Every task and acceptance check in docs/plans/M10-subscriptions.md is done and ticked, or listed under Open items with the reason.
2. All tests pass, including scheduled transitions with fake clocks; screens work at 360, 768 and 1280 px.
3. Update docs/plans/M10-subscriptions.md: Status Done, Completed date, Completion notes, Change log line.
4. Update the M10 row in docs/plans/00-master-plan.md and add Cross-module notes.
5. Finish with a short summary: what works, how to test it, what I should check by hand.
```

---

## M11 – Platform administration

```text
Continue building EazySuvai. Read AGENTS.md, docs/architecture.md, docs/plans/00-master-plan.md and docs/plans/M11-platform-admin.md in full, plus FRD sections 3.1, 3.5, 4.12 and 4.13 in docs/FRD-v1.1.md. Check the Completion notes of M01 and M03.

Implement module M11 – Platform administration in apps/admin_app (web-first, usable on a 768 px tablet, read-only below 600 px):
- Guards: platformAdmin role and completed MFA required.
- A bootstrap script for the first admin, then setAdminRole.
- Dashboard with the FR-085 counts from stats/platform (kept by triggers), pending upgrade requests and recent sign-ups.
- Restaurant table with search (name, slug, email, mobile), filters (status, plan, country, date) and pagination, with the needed composite indexes.
- Restaurant detail with subscription, payments, activity and status actions; setRestaurantStatus with valid transitions, a required reason, token revocation on suspend/deactivate, and an audit entry.
- Editors for plans, dietary labels, tags, themes and platform settings (reserved slugs, grace days, fonts, currencies, announcement banner shown in the owner app). Every change goes through an audit-logged callable.
- Admins never edit restaurant menus.

Show me your file plan first, then build.

Definition of done:
1. Every task and acceptance check in docs/plans/M11-platform-admin.md is done and ticked, or listed under Open items with the reason.
2. All tests pass; screens work at 768 and 1280 px and show the read-only notice at 360 px.
3. Update docs/plans/M11-platform-admin.md: Status Done, Completed date, Completion notes, Change log line.
4. Update the M11 row in docs/plans/00-master-plan.md and add Cross-module notes.
5. Finish with a short summary: what works, how to test it, what I should check by hand.
```

---

## M12 – Audit, account lifecycle and data retention

```text
Continue building EazySuvai. Read AGENTS.md, docs/architecture.md, docs/plans/00-master-plan.md and docs/plans/M12-lifecycle.md in full, plus FRD section 7.7, FR-105, BR-013 and BR-014 in docs/FRD-v1.1.md. Check the Completion notes of every earlier module.

Implement module M12 – Audit, account lifecycle and data retention:
- Check that every sensitive action across all modules writes an audit entry; add any that are missing and list them in the Completion notes.
- Audit log viewer in the admin app (filters by actor, action, restaurant, date range; detail drawer) and an activity timeline on the restaurant detail page.
- exportMenu (JSON and CSV) and the download/share flow in the owner app.
- The owner delete-account flow (offer export, type the restaurant name, confirm) and requestAccountDeletion.
- purgeDaily implementing every row of the retention table in the plan, batched and idempotent; Firestore TTL policies for analyticsEvents and auditLogs; slug release after 12 months; personal data removed from audit entries of deleted accounts.

Show me your file plan first, then build.

Definition of done:
1. Every task and acceptance check in docs/plans/M12-lifecycle.md is done and ticked, or listed under Open items with the reason.
2. All tests pass, including each purge rule with fixed dates; screens work at 360, 768 and 1280 px.
3. Update docs/plans/M12-lifecycle.md: Status Done, Completed date, Completion notes, Change log line.
4. Update the M12 row in docs/plans/00-master-plan.md and add Cross-module notes.
5. Finish with a short summary: what works, how to test it, what I should check by hand.
```

---

## M13 – Hardening, acceptance and launch

```text
Continue building EazySuvai. Read AGENTS.md, docs/architecture.md, docs/plans/00-master-plan.md (all modules should be Done) and docs/plans/M13-launch.md in full, plus FRD sections 7, 10 and 13 in docs/FRD-v1.1.md. Read the Completion notes and Open items of every module.

Carry out module M13 – Hardening, acceptance and launch:
- Run every acceptance criterion AC-001 to AC-030 and fill in the Acceptance results table in docs/plans/M13-launch.md with the result and evidence. Fix failures, or list them clearly if they need my decision.
- Add the end-to-end integration tests listed in the plan.
- Do the responsive, accessibility and localization passes; enable App Check; complete the rules coverage; run dependency audits.
- Run Lighthouse on the public menu and a load test; set up backups, a test restore, monitoring alerts and Crashlytics.
- Prepare production: Firebase project settings, branded email templates, seeded data, privacy and terms links, store listing checklist.
Do not deploy to production or submit to the stores without asking me first.

Definition of done:
1. Every task in docs/plans/M13-launch.md is done and ticked, or listed under Open items with the reason; the Acceptance results table is complete.
2. Update docs/plans/M13-launch.md: Status Done, Completed date, Completion notes, Change log line.
3. Update the M13 row in docs/plans/00-master-plan.md.
4. Finish with a launch-readiness summary: what passed, what is open, and the exact steps left for me.
```

---

## Review prompt (run after each module, in a fresh session)

```text
Review module <Mxx> of EazySuvai. Read AGENTS.md, docs/architecture.md, docs/plans/00-master-plan.md and docs/plans/<Mxx-file>.md.

1. Check every ticked task and acceptance check against the code. Untick anything that is not really done, and say why.
2. Run the tests the plan lists and report the results.
3. Check the non-negotiable rules in AGENTS.md: tenant isolation and rules tests, server-side checks, money as integer minor units, no hard-coded strings, layouts at 360/768/1280 px, audit entries.
4. Check that the plan file's Completion notes, Open items and Change log, and the master plan row, are accurate. Correct them if not.
Do not add new features. Report findings as a short list with file paths, most serious first, then fix the ones that are clearly bugs.
```

## Resume prompt (if a session stopped half-way)

```text
Resume module <Mxx> of EazySuvai. Read AGENTS.md and docs/plans/<Mxx-file>.md. Look at the ticked tasks, the code and git status to see what is already done. Tell me in a few lines what is left, then continue from there. Follow the plan's Definition of done, including updating the plan files at the end.
```

## Change-request prompt (when a requirement changes)

```text
A requirement for EazySuvai has changed: <describe the change>.
Read AGENTS.md, docs/FRD-v1.1.md, docs/architecture.md and docs/plans/00-master-plan.md.
1. List which modules, plan files, architecture sections and code are affected.
2. Update docs/architecture.md and every affected plan file (tasks, acceptance checks, Change log). If a module is already Done, add new unticked tasks and set its status back to In progress in both the plan and the master plan.
3. Add a dated line to Cross-module notes in the master plan.
Show me the list and the doc changes before changing any code.
```
