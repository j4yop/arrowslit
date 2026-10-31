#!/usr/bin/env bash
# Builds Arrowslit.app into ./build.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG="${CONFIG:-release}"
VERSION="${VERSION:-0.5.1}"
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
UNIVERSAL="${UNIVERSAL:-0}"
if [[ "$UNIVERSAL" == "1" ]]; then
    mkdir -p "$ROOT/build"
    for arch in arm64 x86_64; do
        echo "› Building ${arch}..."
        swift build --build-system native -c "$CONFIG" \
            --triple "${arch}-apple-macosx14.0" \
            --scratch-path "$ROOT/.build-$arch"
        BIN_DIR="$(swift build --build-system native -c "$CONFIG" \
            --triple "${arch}-apple-macosx14.0" \
            --scratch-path "$ROOT/.build-$arch" \
            --show-bin-path)"
        cp "$BIN_DIR/Arrowslit" "$ROOT/build/Arrowslit-$arch"
        cp "$BIN_DIR/libArrowslitMedia.dylib" "$ROOT/build/libArrowslitMedia-$arch.dylib"
    done
else
    swift build --build-system native -c "$CONFIG"
    BIN_DIR="$(swift build --build-system native -c "$CONFIG" --show-bin-path)"
fi

echo "› Assembling app bundle…"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$APP/Contents/Frameworks"
if [[ "$UNIVERSAL" == "1" ]]; then
    lipo -create "$ROOT/build/Arrowslit-arm64" "$ROOT/build/Arrowslit-x86_64" \
        -output "$APP/Contents/MacOS/Arrowslit"
    lipo -create "$ROOT/build/libArrowslitMedia-arm64.dylib" "$ROOT/build/libArrowslitMedia-x86_64.dylib" \
        -output "$APP/Contents/Frameworks/libArrowslitMedia.dylib"
    lipo -info "$APP/Contents/MacOS/Arrowslit"
    lipo -info "$APP/Contents/Frameworks/libArrowslitMedia.dylib"
else
    cp "$BIN_DIR/Arrowslit" "$APP/Contents/MacOS/Arrowslit"
    cp "$BIN_DIR/libArrowslitMedia.dylib" "$APP/Contents/Frameworks/libArrowslitMedia.dylib"
fi
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
codesign --force --options runtime --timestamp=none --entitlements "$ROOT/Support/Arrowslit.entitlements" --sign - "$APP"
codesign --verify --deep --strict "$APP"
echo "✓ Built $APP ($VERSION, build $BUILD_NUMBER)"
