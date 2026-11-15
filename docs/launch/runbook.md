# Launch runbook (M13)

What is left before launch, in order. Everything here touches real projects or the stores, so it was **prepared but not run**. Each step says who does it and how to check it.

The ops scripts in `ops/` print their commands by default and act only with `--apply`. Against `eazysuvai-prod` they also need `CONFIRM_PROD=yes`.

## 0. Decisions needed first

| Decision | Where it is used |
| --- | --- |
| Final domains: public menu (e.g. `eazysuvai.menu` or `menu.eazysuvai.com`), owner app (`app.`), admin (`admin.`) | `AppEnv.menuBaseUrl` (core), `MENU_BASE_URL` for Functions, Hosting custom domains, the QR code URL (printed codes depend on it: decide **before** any restaurant prints one) |
| Support and privacy mailboxes (`support@`, `privacy@`) | Email templates, legal pages, `config/platform.supportEmail` |
| Legal review of `hosting/menu/privacy.html` and `terms.html`, and of the retention periods (DPDP Act 2023, GCC) | Replace the drafts, then remove the "Draft" notice |

## 1. Production project (owner)

1. Upgrade `eazysuvai-prod` to the **Blaze** plan. Scheduled functions, Cloud Scheduler and backups need it.
2. **Identity Platform:** Authentication → Settings → upgrade. TOTP MFA and the password policy need it.
3. Create the three Hosting sites (`eazysuvai-prod-app`, `-admin`, `-menu`), then connect the custom domains. Hosting issues the certificates. HSTS is already in `firebase.json`.
4. Register the Android and iOS apps in **both** projects (`eazy-suvai-dev` first, then prod), from `apps/owner_app`:
   ```
   flutterfire configure --project=eazy-suvai-dev  --out=lib/firebase_options_dev.dart  --platforms=web,android,ios
   flutterfire configure --project=eazysuvai-prod --out=lib/firebase_options_prod.dart --platforms=web,android,ios
   ```
   This adds `google-services.json` and `GoogleService-Info.plist`. The Crashlytics Gradle plugin is already set up (M13).
5. Set the application id and the release signing config in `android/app/build.gradle.kts`. It still uses the Flutter template TODO. Then:
   - give the SHA-256 fingerprint of the upload key to Firebase, for Play Integrity;
   - give the Apple Team ID to Firebase, for App Attest.

## 2. App Check

1. Firebase console → App Check, register the apps:
   - Android: Play Integrity;
   - iOS: App Attest (DeviceCheck as fallback);
   - web (owner and admin): reCAPTCHA Enterprise. Create a key per domain.
2. Build the web apps with the key: `--dart-define=RECAPTCHA_ENTERPRISE_KEY=<key>`. Without the key, App Check stays off on web and the build logs a warning.
3. **Dev builds** use debug providers. Each developer registers their debug token under App Check → Manage debug tokens.
4. **Callables:** they enforce App Check through `functions/.env.eazysuvai-prod` (`ENFORCE_APP_CHECK=true`), applied on deploy. Dev keeps it `false` until the debug tokens are registered.
5. **Firestore and Storage:**
   1. Watch App Check → APIs for a week after launch, until verified requests are above 99 %.
   2. Then press **Enforce** for Cloud Firestore and Cloud Storage.

   Public menus don't use them directly; they're served by `renderMenu`.

## 3. Auth, backups and monitoring (scripts)

```
APP_DOMAIN=app.<domain> ADMIN_DOMAIN=admin.<domain> CONFIRM_PROD=yes ops/auth-config.sh eazysuvai-prod --apply
CONFIRM_PROD=yes ops/backups.sh eazysuvai-prod --apply
ALERT_EMAIL=ops@<domain> MENU_HOST=<menu domain> SAMPLE_SLUG=eazysuvai-demo CONFIRM_PROD=yes ops/monitoring.sh eazysuvai-prod --apply
```

Check afterwards:

- **Auth:**
  - Authentication → Templates shows the branded emails. Send yourself a verification and a reset email.
  - If the API refused the template body, paste `ops/auth/*.html` in the console.
- **MFA:** TOTP is enabled.
- **Backups:**
  - `gcloud firestore databases describe` shows point-in-time recovery enabled;
  - `gcloud firestore backups schedules list` shows a daily schedule with 5 weeks' retention.
- **Monitoring:** four alert policies and one uptime check exist. Trigger a test alert from the console to confirm the email arrives.

Run the same scripts on dev first, without `CONFIRM_PROD`.

## 4. Deploy (only after agreeing to it)

```
cd functions && npm ci && npm run lint && npm test
cd ..
bash tool/build-web.sh owner --dart-define=ENV=prod --dart-define=RECAPTCHA_ENTERPRISE_KEY=<owner key>
bash tool/build-web.sh admin --dart-define=ENV=prod --dart-define=RECAPTCHA_ENTERPRISE_KEY=<admin key>
firebase deploy --project prod --only firestore:rules,firestore:indexes,storage,functions,hosting
```

**First deploy of `storage.rules` to a project:** the rules call `firestore.get()` to check the owner, which needs the Storage service agent (`service-<project number>@gcp-sa-firebasestorage.iam.gserviceaccount.com`) to have **Firebase Rules Firestore Service Agent** (`roles/firebaserules.firestoreServiceAgent`). Run the deploy interactively and answer **yes** when it asks to allow cross-service rules. A `--non-interactive` deploy skips that, and then every image upload fails with `storage/unauthorized`.

Always build the web apps with `tool/build-web.sh`, not `flutter build web` directly: Flutter keeps an old plugin registrant in `.dart_tool/flutter_build`, and a build from it lacks plugins (image picking, links, sharing and App Check fail). The script clears it and checks the registrant.

After the deploy:

- Firestore → Indexes: every index is **Enabled**.
- Firestore → TTL: `analyticsEvents.expireAt` and `auditLogs.expireAt` are **Serving**.
- Functions: `purgeDaily` (02:30 IST) and `subscriptionDaily` show their next run in Cloud Scheduler.

## 5. Seed production

```
cd functions
node scripts/seed-platform.mjs --project eazysuvai-prod --confirm-prod   # plans, labels, tags, themes, config
node scripts/set-admin.mjs --project eazysuvai-prod --email <admin email>   # first platform admin; then enrol TOTP on first sign-in
```

Then, in the admin app:

- check Plans, Labels, Tags, Themes and Settings, including the support email and grace days;
- create the `eazysuvai-demo` restaurant used by the uptime check, and publish it.

## 6. Smoke test on production (30 minutes)

On a phone, a tablet and a desktop browser, go through every step:

1. **Account:** sign up, receive and follow the verification email, sign in, then reset the password (AC-001).
2. **Menu:** add a photo, 3 categories and 30 items, check the timing against FRD §7.5 (under 20 minutes), then publish.
3. **Scan:** print the QR PDF and scan it with an Android camera and an iPhone camera (AC-010). Then share it to WhatsApp (AC-014).
4. **Analytics:** the analytics page shows the scan the next minute (AC-015).
5. **Upgrade:** request an upgrade. As admin, record a test payment and check the audit log (AC-030).
6. **Crashlytics:** on a release build, force a test crash (`FirebaseCrashlytics.instance.crash()` from a debug menu or a temporary button) and confirm it appears in Crashlytics.

## 7. After launch

- **Restore test:** after the first daily backup, run `ops/restore-test.sh eazysuvai-prod --apply` with `CONFIRM_PROD=yes`. It restores into a new database, compares counts, then deletes the copy. Write the date and timings below, and repeat every quarter.
- **Load test through the CDN:** run `k6 run -e BASE=https://<dev menu domain> -e SLUGS=... functions/scripts/load/menu.k6.js` against **dev** (200 requests/s for 5 minutes). Production only by agreement.
- **App Check:** enforce Firestore and Storage (step 2.5).

| Restore test | Backup used | Restore time | Counts match | By |
| --- | --- | --- | --- | --- |
| | | | | |

## 8. Stores

See `docs/launch/store-listing.md`. Submit only after steps 1–6 pass, and after agreeing to it.
