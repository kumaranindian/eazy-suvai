#!/usr/bin/env bash
# Owner app end-to-end test (integration_test) in headless Chrome against the
# Firebase Emulator Suite (Auth, Firestore, Functions; project demo-eazysuvai).
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

firebase emulators:exec --project demo-eazysuvai --only auth,firestore,functions \
  "cd apps/owner_app && flutter drive --no-pub \
     --driver=test_driver/integration_test.dart \
     --target=integration_test/sign_up_flow_test.dart \
     -d web-server --browser-name=chrome --headless"
