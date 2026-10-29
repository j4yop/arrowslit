#!/usr/bin/env bash
# Builds Arrowslit.app and packages build/Arrowslit.dmg.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="${APP_OUTPUT:-$ROOT/build/Arrowslit.app}"
DMG="$ROOT/build/Arrowslit.dmg"
STAGING="$(mktemp -d)"
trap 'rm -rf "$STAGING"' EXIT

if [[ "${SKIP_BUILD:-0}" != "1" ]]; then
    "$ROOT/Scripts/build-app.sh"
fi
mkdir -p "$ROOT/build"
ditto "$APP" "$STAGING/Arrowslit.app"
ln -s /Applications "$STAGING/Applications"
if [[ -f "$ROOT/Support/Install.txt" ]]; then
    cp "$ROOT/Support/Install.txt" "$STAGING/Install.txt"
fi
rm -f "$DMG"
hdiutil create -volname "Arrowslit" -srcfolder "$STAGING" -ov -format UDZO -quiet "$DMG"
hdiutil verify "$DMG" >/dev/null
shasum -a 256 "$DMG" > "$DMG.sha256"
echo "✓ $DMG"
