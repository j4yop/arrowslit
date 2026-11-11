#!/usr/bin/env bash
# Builds Arrowslit.app and packages build/Arrowslit.dmg.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="${APP_OUTPUT:-$ROOT/build/Arrowslit.app}"
DMG="$ROOT/build/Arrowslit.dmg"
STAGING="$(mktemp -d)"
RW="$(mktemp -u /tmp/Arrowslit-XXXXXX.dmg)"
MOUNT="$(mktemp -d)"
cleanup() {
    if mount | grep -q "on $MOUNT "; then
        hdiutil detach "$MOUNT" >/dev/null 2>&1 || true
    fi
    rm -rf "$STAGING" "$MOUNT" "$RW"
}
trap cleanup EXIT

if [[ "${SKIP_BUILD:-0}" != "1" ]]; then
    "$ROOT/Scripts/build-app.sh"
fi
mkdir -p "$ROOT/build"
VERSION="${VERSION:-$(plutil -extract CFBundleShortVersionString raw -o - "$APP/Contents/Info.plist" 2>/dev/null || echo 0.0.0)}"
VOLNAME="Arrowslit"
ditto "$APP" "$STAGING/Arrowslit.app"
ln -s /Applications "$STAGING/Applications"
cp "$ROOT/Support/Dmg/background.tiff" "$STAGING/.background.tiff"
cp "$ROOT/Support/Dmg/VolumeIcon.icns" "$STAGING/.VolumeIcon.icns"
cp "$ROOT/Support/Dmg/DS_Store" "$STAGING/.DS_Store"
rm -f "$DMG"
# Build a writable image first so the volume can carry Droppy-style Finder
# metadata: the background alias, icon positions and custom volume icon.
hdiutil create -volname "$VOLNAME" -srcfolder "$STAGING" -fs HFS+ -format UDRW -ov -quiet "$RW"
hdiutil attach -readwrite -nobrowse -noautoopen -mountpoint "$MOUNT" "$RW" >/dev/null
SetFile -a C "$MOUNT"
hdiutil detach "$MOUNT" >/dev/null
hdiutil convert "$RW" -format UDZO -imagekey zlib-level=9 -o "$DMG" >/dev/null
hdiutil verify "$DMG" >/dev/null
# Keep the checksum portable: `shasum -a 256 -c` must work on a user's machine.
( cd "$ROOT/build" && shasum -a 256 "$(basename "$DMG")" > "$(basename "$DMG").sha256" )
echo "✓ $DMG"
