# EazySuvai

Multi-tenant SaaS for restaurant digital menus with QR codes, by AVAIL404 (OPC) Private Limited.

| Part | Folder | Tech |
| --- | --- | --- |
| Owner app (web, Android, iOS) | `apps/owner_app` | Flutter |
| Admin app (web) | `apps/admin_app` | Flutter |
| Shared code: money, time, theme, layout, widgets, l10n, env | `packages/core` | Dart package |
| Backend functions | `functions` | Cloud Functions 2nd gen, TypeScript, Node 22 |
| Security rules tests | `firestore-tests` | `@firebase/rules-unit-testing` |
| Public menu placeholder (replaced in M07) | `hosting/menu` | static HTML |

Read `AGENTS.md` first. Requirements, architecture and module plans live in `docs/`.

## Prerequisites

- Flutter 3.32.8 stable (Dart 3.8)
- Node.js 22
- Java 21 or later (Firebase emulators). Android Studio's bundled JDK works:
  `export JAVA_HOME="/c/Program Files/Android/Android Studio/jbr"` (Git Bash on Windows).
- Firebase CLI 15: `npm install -g firebase-tools`

## First run

```bash
flutter pub get                               # resolves the whole Dart workspace
(cd functions && npm ci && npm run build)     # the functions emulator loads functions/lib
(cd firestore-tests && npm ci)
```

## Run against the emulators (no real Firebase project needed)

The apps use the demo project `demo-eazysuvai` when `USE_EMULATORS=true`. Nothing reaches Google services.

```bash
# Terminal 1: Emulator Suite (UI at http://localhost:4000)
firebase emulators:start --project demo-eazysuvai --only auth,firestore,storage,functions \
  --import=./emulator-data --export-on-exit

# Terminal 2: owner app
cd apps/owner_app
flutter run -d chrome --dart-define=ENV=dev --dart-define=USE_EMULATORS=true

# Terminal 3: admin app
cd apps/admin_app
flutter run -d chrome --dart-define=ENV=dev --dart-define=USE_EMULATORS=true
```

Build the functions first (`cd functions && npm run build`); the Functions emulator serves `functions/lib`.

### Trying the account flows (M01)

- **Owner sign-up:** open the owner app, choose *Create an account*. The verification email is not sent
  for real: the Auth emulator prints the link in Terminal 1 (and lists it in the Emulator UI → Authentication).
  Open the link, then sign in. Password reset links appear the same way.
- **First platform admin:** the emulator has no TOTP, so on the emulators the admin app and `assertAdmin`
  accept an admin without a second factor (Firestore rules still require it). Create one with:

  ```bash
  cd functions
  FIREBASE_AUTH_EMULATOR_HOST=localhost:9099 FIRESTORE_EMULATOR_HOST=localhost:8080 \
    node scripts/set-admin.mjs --project demo-eazysuvai --email admin@example.com --password 'Admin12345!'
  ```

  On a real project, run the same script without the emulator variables and with
  `--project eazysuvai-dev` after the person has signed up and verified their email. They enrol an
  authenticator app the first time they sign in to the admin app.

On the Android emulator the apps reach the host at `10.0.2.2` automatically. On a physical device add
`--dart-define=EMULATOR_HOST=<your computer's LAN IP>`.

| Emulator | Port |
| --- | --- |
| Auth | 9099 |
| Firestore | 8080 |
| Storage | 9199 |
| Functions | 5001 |
| Hosting | 5000 |
| Emulator UI | 4000 |

## Environments

| `--dart-define=ENV=` | Firebase project | Firebase CLI alias |
| --- | --- | --- |
| `dev` (default) | `eazysuvai-dev` | `firebase use dev` |
| `prod` | `eazysuvai-prod` | `firebase use prod` |

`USE_EMULATORS` is ignored for `prod`.

### Connecting the real projects (one-time)

The Firebase options files in each app are placeholders until the projects exist.

1. Create `eazysuvai-dev` and `eazysuvai-prod` in the Firebase console. Pick location `asia-south1` for Firestore and Storage.
2. Install the FlutterFire CLI: `dart pub global activate flutterfire_cli`.
3. Generate the options:

   ```bash
   cd apps/owner_app
   flutterfire configure --project=eazysuvai-dev  --out=lib/firebase_options_dev.dart  --platforms=web,android,ios
   flutterfire configure --project=eazysuvai-prod --out=lib/firebase_options_prod.dart --platforms=web,android,ios
   cd ../admin_app
   flutterfire configure --project=eazysuvai-dev  --out=lib/firebase_options_dev.dart  --platforms=web
   flutterfire configure --project=eazysuvai-prod --out=lib/firebase_options_prod.dart --platforms=web
   ```

   The apps pass these options to `Firebase.initializeApp` in code, so they don't rely on
   `google-services.json` or `GoogleService-Info.plist` to pick the environment.
4. Create the Hosting sites and link the targets (names match `.firebaserc`):

   ```bash
   firebase use dev
   firebase hosting:sites:create eazysuvai-dev-app
   firebase hosting:sites:create eazysuvai-dev-admin
   firebase hosting:sites:create eazysuvai-dev-menu
   # repeat with prod
   ```

5. Enable TTL policies on `auditLogs.expireAt` and `analyticsEvents.expireAt` (architecture §9).

## Checks

```bash
bash tool/check.sh            # everything CI runs
bash tool/check.sh flutter    # gen-l10n + build_runner + format + analyze + tests
bash tool/check.sh functions  # lint + build + jest
bash tool/check.sh rules      # rules tests on the Firestore and Storage emulators
bash tool/check.sh emulators  # functions tests on the Auth, Firestore and Functions emulators

# Owner app end-to-end in headless Chrome on the emulators (needs a chromedriver matching Chrome)
CHROMEDRIVER=/path/to/chromedriver bash tool/integration.sh
```

Generated files (`lib/**/l10n/generated/`, `*.g.dart`) are committed. `tool/check.sh flutter` regenerates
and formats them and fails if anything changed, so run it before committing.

## Building and deploying

```bash
(cd apps/owner_app && flutter build web --dart-define=ENV=dev)
(cd apps/admin_app && flutter build web --dart-define=ENV=dev)
firebase use dev
firebase deploy --only hosting,firestore,storage,functions
```

## Repository layout

```
apps/owner_app/lib
  main.dart                 env + Firebase bootstrap
  app.dart                  MaterialApp.router, theme, localization
  router/                   go_router routes and the auth guard hook (filled in M01)
  features/<feature>/{data,domain,presentation}
  l10n/arb/app_en.arb       app strings
apps/admin_app/lib          same shape
packages/core/lib/src
  money/                    Money (int minor units + ISO 4217), Currencies
  time/                     TimeService (UTC <-> IANA zone)
  layout/                   Breakpoint, ResponsiveScaffold
  theme/                    AppTheme (light/dark), BrandColors
  widgets/                  buttons, text field, loading/empty/error states, confirm dialog
  errors/                   AppErrorCode (shared with functions/src/lib/errors.ts)
  config/                   AppEnv, initFirebase
  l10n/arb/core_en.arb      shared strings
functions/src/lib           assertOwner, assertAdmin, writeAudit, parseInput, appError
```
