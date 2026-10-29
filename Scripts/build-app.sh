#!/usr/bin/env bash
# Builds Arrowslit.app into ./build.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG="${CONFIG:-release}"
VERSION="${VERSION:-0.1.0}"
BUILD_NUMBER="${BUILD_NUMBER:-$(git -C "$ROOT" rev-list --count HEAD 2>/dev/null || echo 1)}"
BUNDLE_ID="${BUNDLE_ID:-com.j4yop.arrowslit}"
APP="${APP_OUTPUT:-$ROOT/build/Arrowslit.app}"

DEVELOPER_DIR="${DEVELOPER_DIR:-$(xcode-select -p)}"
export DEVELOPER_DIR
XCODE_SDK="$DEVELOPER_DIR/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk"
if [[ -z "${SDKROOT:-}" && -d "$XCODE_SDK" ]]; then
    export SDKROOT="$XCODE_SDK"
fi

cd "$ROOT"
echo "› Building ($CONFIG)…"
swift build --build-system native -c "$CONFIG"
BIN_DIR="$(swift build --build-system native -c "$CONFIG" --show-bin-path)"

echo "› Assembling app bundle…"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$APP/Contents/Frameworks"
cp "$BIN_DIR/Arrowslit" "$APP/Contents/MacOS/Arrowslit"
sed -e "s/__VERSION__/$VERSION/" -e "s/__BUILD__/$BUILD_NUMBER/" -e "s/__BUNDLE_ID__/$BUNDLE_ID/" \
    "$ROOT/Support/Info.plist" > "$APP/Contents/Info.plist"
plutil -lint "$APP/Contents/Info.plist" > /dev/null
printf 'APPL????' > "$APP/Contents/PkgInfo"
if [[ -f "$ROOT/Support/AppIcon.icns" ]]; then
    cp "$ROOT/Support/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
fi
if [[ "$CONFIG" == "release" ]]; then
    strip -x "$APP/Contents/MacOS/Arrowslit"
    strip -x "$APP/Contents/Frameworks/libArrowslitMedia.dylib"
fi

xattr -dr com.apple.FinderInfo "$APP" 2>/dev/null || true
xattr -dr com.apple.ResourceFork "$APP" 2>/dev/null || true
codesign --force --options runtime --timestamp=none --sign - "$APP/Contents/Frameworks/libArrowslitMedia.dylib"
codesign --force --options runtime --timestamp=none --sign - "$APP"
codesign --verify --deep --strict "$APP"
echo "✓ Built $APP ($VERSION, build $BUILD_NUMBER)"
