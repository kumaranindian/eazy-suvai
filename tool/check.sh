#!/usr/bin/env bash
# Runs every check CI runs. Usage: tool/check.sh [flutter|functions|rules|emulators|lighthouse|all]
# rules and emulators need Java 21+ (the Firebase emulators) and firebase-tools.
# The owner app end-to-end test (Chrome) is separate: tool/integration.sh.
set -euo pipefail
cd "$(dirname "$0")/.."

PACKAGES=(packages/core apps/owner_app apps/admin_app)

flutter_checks() {
  flutter pub get
  # Generated code must be committed and up to date.
  for p in "${PACKAGES[@]}"; do (cd "$p" && flutter gen-l10n); done
  for p in apps/owner_app apps/admin_app; do
    (cd "$p" && dart run build_runner build --delete-conflicting-outputs)
  done
  # Formatting is part of the check; generated files are formatted too.
  dart format apps packages
  if [ -d .git ] && ! git diff --quiet -- '*.dart'; then
    echo "Dart files are unformatted or generated code is stale. Run tool/check.sh flutter and commit." >&2
    git --no-pager diff --stat -- '*.dart'
    exit 1
  fi
  flutter analyze
  for p in "${PACKAGES[@]}"; do (cd "$p" && flutter test); done
}

functions_checks() {
  (cd functions && npm ci && npm run lint && npm run build && npm test)
}

rules_checks() {
  (cd firestore-tests && npm ci && npm test)
}

# Functions tests that need the Auth, Firestore and Functions emulators.
functions_emulator_checks() {
  (cd functions && npm ci && npm run test:emulators)
}

# Public menu Lighthouse budget and layout checks (M07; needs Chrome and network for Google Fonts).
lighthouse_checks() {
  (cd functions && npm ci && npm run test:lighthouse)
}

case "${1:-all}" in
  flutter) flutter_checks ;;
  functions) functions_checks ;;
  rules) rules_checks ;;
  emulators) functions_emulator_checks ;;
  lighthouse) lighthouse_checks ;;
  all) flutter_checks; functions_checks; rules_checks; functions_emulator_checks; lighthouse_checks ;;
  *) echo "Usage: $0 [flutter|functions|rules|emulators|lighthouse|all]" >&2; exit 2 ;;
esac
