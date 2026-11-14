#!/usr/bin/env bash
# Runs each owner app integration test with flutter drive. Called by
# tool/integration.sh inside `firebase emulators:exec`, which runs its script
# with cmd.exe on Windows, so the loop lives here.
set -euo pipefail
cd "$(dirname "$0")/../apps/owner_app"
for target in "$@"; do
  flutter drive --no-pub \
    --driver=test_driver/integration_test.dart --target="$target" \
    -d web-server --browser-name=chrome --headless
done
