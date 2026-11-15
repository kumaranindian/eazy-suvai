#!/usr/bin/env bash
# Release web build of the owner or admin app, with a fresh plugin registrant.
#
#   bash tool/build-web.sh owner --dart-define=ENV=dev
#   bash tool/build-web.sh admin --dart-define=ENV=prod --dart-define=RECAPTCHA_ENTERPRISE_KEY=<key>
#
# Why: `flutter build web` writes web_plugin_registrant.dart once per build
# configuration (.dart_tool/flutter_build/<hash>) and never regenerates it
# when a plugin is added; the target's only input is flutter_tools itself
# (Flutter 3.32). An old cache gave web builds without image_picker,
# url_launcher, share_plus, printing and App Check, so "Add image" failed with
# MissingPluginException. Removing the cache makes the build regenerate it.
set -euo pipefail
cd "$(dirname "$0")/.."

app="${1:?usage: tool/build-web.sh owner|admin [flutter build args...]}"
shift
case "$app" in
  owner) dir=apps/owner_app ;;
  admin) dir=apps/admin_app ;;
  *) echo "unknown app: $app (owner or admin)" >&2; exit 2 ;;
esac

cd "$dir"
rm -rf .dart_tool/flutter_build
flutter build web --release "$@"

# Every web plugin the app depends on must be registered.
registrant=$(ls -t .dart_tool/flutter_build/*/web_plugin_registrant.dart | head -1)
expected=$(node -e '
  const d = JSON.parse(require("fs").readFileSync(".flutter-plugins-dependencies", "utf8"));
  console.log(d.plugins.web.filter((p) => !p.dev_dependency).length);
')
found=$(grep -c "registerWith(registrar)" "$registrant")
if [ "$found" -lt "$expected" ]; then
  echo "web_plugin_registrant.dart registers $found plugins, expected $expected" >&2
  exit 1
fi
echo "OK: $found web plugins registered ($registrant)"
