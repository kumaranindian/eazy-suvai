# EazySuvai – rules for AI coding agents

EazySuvai is a multi-tenant SaaS for restaurant digital menus with QR codes, built by AVAIL404 (OPC) Private Limited.
Read this file at the start of every session. It applies to every module.

## Source of truth

| What | Where |
| --- | --- |
| Requirements | `docs/FRD-v1.1.md` (FR-, BR-, AC- IDs) |
| Architecture, data model, conventions | `docs/architecture.md` |
| Build order and status of every module | `docs/plans/00-master-plan.md` |
| The plan for one module | `docs/plans/Mxx-*.md` |

If code and these documents disagree, stop and ask. Do not silently change a requirement.

## Stack

- **Owner app and admin app:** Flutter (stable), Dart 3, Riverpod, go_router, freezed. Targets: web, Android, iOS for the owner app; web for the admin app.
- **Backend:** Firebase: Authentication, Cloud Firestore, Cloud Storage, Cloud Functions (TypeScript, Node 22, 2nd gen), Hosting.
- **Public menu (what customers see after scanning):** server-rendered HTML from a Cloud Function behind Firebase Hosting. Not Flutter. See `docs/architecture.md` §3.
- **Region:** `asia-south1` for Firestore, Functions and Storage.

## How to work on a module

1. Open `docs/plans/00-master-plan.md`. Work only on the module you were asked to build. Check that its dependencies are marked Done.
2. Read the module's plan file in full, plus the FRD sections it lists.
3. Set the module's status to **In progress** in both the plan file and the master plan, with today's date.
4. Build in small steps. After each task, tick its checkbox in the plan file.
5. Write the tests the plan lists. Run them against the Firebase Emulator Suite. Never test against production.
6. Check every acceptance item in the plan. Tick only what you have actually verified.
7. **Update the plan before you finish** (see below). A module is not done until its plan is updated.

## Updating the plan when a module is done

In the module's plan file:

- Set `Status:` to **Done** and fill in `Completed:` with the date.
- Tick every finished task. Leave unfinished ones unticked and list them under **Open items**.
- Fill in **Completion notes**: what was built, the main files and folders, Firestore paths, functions and routes added, and any decision that differs from the plan, with the reason.
- Add a dated line to the module's **Change log**.

In `docs/plans/00-master-plan.md`:

- Update the module's row: status, completed date and a one-line note.
- If the work changed something another module relies on (a field name, a function signature, a route), add a line under **Cross-module notes** and update the affected plan file's **Inputs from other modules** section.

If you could not finish, set the status to **Blocked** or leave it **In progress**, and write what is left and why.

## Non-negotiable rules

- **Tenant isolation:** every restaurant-owned document lives under `restaurants/{restaurantId}`. Security rules must prove a user can only reach their own restaurant. Add a rules test for every new collection.
- **Server-side checks:** plan limits, publishing, account status, slug and QR changes, subscriptions and anything admin-only go through Cloud Functions, never client-only checks (BR-011).
- **Money:** prices are integers in minor units with an ISO 4217 currency code. Never use `double` for money (BR-019).
- **Time:** store UTC timestamps. Display in the restaurant's IANA time zone.
- **Responsive UI:** every screen must work at 360 px, 768 px and 1280 px wide. Use the breakpoints in `docs/architecture.md` §6.
- **Text:** all user-facing strings go through the localization files (`.arb`). No hard-coded strings in widgets. Use direction-neutral layout (`EdgeInsetsDirectional`, `AlignmentDirectional`) so Arabic RTL works later.
- **Accessibility:** WCAG 2.1 AA contrast, `Semantics` labels on icon-only buttons, touch targets at least 48 px.
- **Audit:** every sensitive admin action writes an `auditLogs` entry through the shared helper (BR-014).
- **Secrets:** never commit service-account keys or API secrets. Use Firebase environment config or Secret Manager.
- **No ordering, payments or customer accounts** in the MVP (FRD §11).

## Commands

```bash
# Everything CI runs (Flutter: gen-l10n, build_runner, format, analyze, tests; functions; rules)
bash tool/check.sh            # or: flutter | functions | rules

# Flutter (from repo root; tests run per package)
flutter pub get
flutter analyze
(cd packages/core && flutter test)   # same for apps/owner_app and apps/admin_app

# Functions
cd functions && npm ci && npm run lint && npm test

# Emulators (Java 21+; demo project, never a real one)
firebase emulators:start --project demo-eazysuvai --import=./emulator-data --export-on-exit

# Run an app against the emulators
cd apps/owner_app && flutter run -d chrome --dart-define=ENV=dev --dart-define=USE_EMULATORS=true
```
