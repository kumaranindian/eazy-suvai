#!/usr/bin/env bash
# Owner app end-to-end tests (integration_test) in headless Chrome against the
# Firebase Emulator Suite (Auth, Firestore, Functions, Storage; project
# demo-eazysuvai): the account flow (M01), the image flow (M02) and the
# onboarding and profile flow (M03), the menu flow (M04) and the theme flow
# (M05).
#
# Needs: Java 21+, firebase-tools, Chrome, and a chromedriver that matches the
# installed Chrome (CHROMEDRIVER=/path/to/chromedriver, or on PATH):
#   npx @puppeteer/browsers install chromedriver@<your Chrome version>
set -euo pipefail
cd "$(dirname "$0")/.."

(cd functions && npm run build)

DRIVER="${CHROMEDRIVER:-chromedriver}"
"$DRIVER" --port=4444 >/dev/null 2>&1 &
DRIVER_PID=$!
trap 'kill "$DRIVER_PID" 2>/dev/null || true' EXIT

firebase emulators:exec --project demo-eazysuvai --only auth,firestore,functions,storage \
  "bash tool/integration-drive.sh integration_test/sign_up_flow_test.dart integration_test/media_flow_test.dart integration_test/profile_flow_test.dart integration_test/menu_flow_test.dart integration_test/theme_flow_test.dart"
