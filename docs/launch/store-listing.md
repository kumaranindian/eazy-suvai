# Store listing checklist: owner app (M13)

The owner app ships to Google Play and the App Store. Customers never need the app: menus open in the browser. Nothing here has been submitted.

## Both stores

| Item | Value or source | Done |
| --- | --- | --- |
| App name | EazySuvai: Digital Menu (30 characters at most) | [ ] |
| Short description (Play, 80 characters) | "Create a QR menu for your restaurant, update it any time, see who views it." | [ ] |
| Full description | What the app does (menu, photos, themes, QR, sharing, analytics, plans), who it is for, and that customers don't need an app | [ ] |
| Category | Business (Play) / Business (App Store); secondary: Food & Drink | [ ] |
| Privacy policy URL | `https://<menu domain>/privacy` (after legal review) | [ ] |
| Terms URL | `https://<menu domain>/terms` | [ ] |
| Support email and website | `support@<domain>` | [ ] |
| App icon | 512 × 512 (Play), 1024 × 1024 without transparency (App Store); `apps/owner_app/web/icons` has the source | [ ] |
| Reviewer account | A verified owner on prod with a published sample menu; put the credentials in the review notes | [ ] |
| Version and build | `pubspec.yaml` `version:` is `0.1.0+1`; set `1.0.0+1` for the first release | [ ] |
| Release signing | Upload key (Play App Signing), Apple distribution certificate and provisioning profile | [ ] |

## Screenshots

Take them from a release build with the sample menu (`Spice Garden`). Use the same 5 screens at each size:

1. home;
2. menu editor;
3. item editor with a photo;
4. theme gallery;
5. QR and share.

| Store | Size | Done |
| --- | --- | --- |
| Play: phone | 1080 × 1920 or larger, 16:9 or 9:16 | [ ] |
| Play: 7-inch tablet | 1200 × 1920 | [ ] |
| Play: 10-inch tablet | 1600 × 2560 | [ ] |
| Play: feature graphic | 1024 × 500 | [ ] |
| App Store: iPhone 6.9-inch | 1320 × 2868 | [ ] |
| App Store: iPad 13-inch | 2064 × 2752 | [ ] |

The layouts are already checked at 360, 768 and 1280 px by `apps/owner_app/test/route_sweep_test.dart`, including at 200 % text. The screenshots are for marketing only.

## Google Play

| Item | Answer | Done |
| --- | --- | --- |
| Target API level | Flutter 3.32 default (API 35); meet Play's yearly requirement at submission | [ ] |
| Data safety: collected | Name, email, phone (account); photos (menu content); app interactions are not collected in the app; crash logs (Crashlytics) | [ ] |
| Data safety: shared | None. Processors (Google Cloud and Firebase) don't count as sharing | [ ] |
| Data safety: security | Encrypted in transit; the user can request deletion (in-app: Settings → Account → Delete my account) | [ ] |
| Account deletion URL (required) | `https://<menu domain>/privacy`, which has a "Your choices" section, plus the in-app path | [ ] |
| Content rating | Questionnaire: no objectionable content → Everyone | [ ] |
| Ads | No | [ ] |
| App access | Restricted: give the reviewer account | [ ] |
| Testing | Internal testing track first, then a closed test (Play requires 12 testers for 14 days for new personal accounts) | [ ] |

## App Store

| Item | Answer | Done |
| --- | --- | --- |
| Privacy nutrition label | Contact info (name, email, phone) and user content (photos), both linked to the user and used for app functionality; diagnostics (crash data), not linked | [ ] |
| Account deletion in the app (guideline 5.1.1(v)) | Settings → Account → Delete my account (M12) | [ ] |
| Sign in with Apple | Not needed: only email and password sign-in | [ ] |
| Export compliance | Uses only standard encryption (HTTPS) → exempt; add `ITSAppUsesNonExemptEncryption = NO` to `Info.plist` (not there yet) | [ ] |
| Photo permission | `NSPhotoLibraryUsageDescription` is set in `ios/Runner/Info.plist`. The app never uses the camera, so it needs no camera string | [x] |
| TestFlight | Internal testers first | [ ] |
