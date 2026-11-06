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
VERSION="${VERSION:-$(plutil -extract CFBundleShortVersionString raw -o - "$APP/Contents/Info.plist" 2>/dev/null || echo 0.0.0)}"
VOLNAME="Arrowslit $VERSION"
ditto "$APP" "$STAGING/Arrowslit.app"
ln -s /Applications "$STAGING/Applications"
if [[ -f "$ROOT/Support/Install.txt" ]]; then
    sed "s/__VERSION__/$VERSION/g" "$ROOT/Support/Install.txt" > "$STAGING/Install.txt"
fi
rm -f "$DMG"
hdiutil create -volname "$VOLNAME" -srcfolder "$STAGING" -ov -format UDZO -quiet "$DMG"
hdiutil verify "$DMG" >/dev/null
# Keep the checksum portable: `shasum -a 256 -c` must work on a user's machine.
( cd "$ROOT/build" && shasum -a 256 "$(basename "$DMG")" > "$(basename "$DMG").sha256" )
echo "✓ $DMG"
