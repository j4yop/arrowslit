#!/usr/bin/env bash
# Builds Arrowslit.app into ./build.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG="${CONFIG:-release}"
VERSION="${VERSION:-$(git -C "$ROOT" describe --tags --abbrev=0 2>/dev/null | sed 's/^v//' || true)}"
VERSION="${VERSION:-0.0.0}"
BUILD_NUMBER="${BUILD_NUMBER:-$(git -C "$ROOT" rev-list --count HEAD 2>/dev/null || echo 1)}"
BUNDLE_ID="${BUNDLE_ID:-com.j4yop.arrowslit}"
APP="${APP_OUTPUT:-$ROOT/build/Arrowslit.app}"
UPDATE_PUBLIC_KEY="${UPDATE_PUBLIC_KEY:-$(cat "$ROOT/Support/UpdatePublicKey.txt" 2>/dev/null || true)}"

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
sed -e "s/__VERSION__/$VERSION/" -e "s/__BUILD__/$BUILD_NUMBER/" \
    -e "s/__BUNDLE_ID__/$BUNDLE_ID/" -e "s|__UPDATE_PUBLIC_KEY__|$UPDATE_PUBLIC_KEY|" \
    "$ROOT/Support/Info.plist" > "$APP/Contents/Info.plist"
plutil -lint "$APP/Contents/Info.plist" > /dev/null
printf 'APPL????' > "$APP/Contents/PkgInfo"
if [[ -f "$ROOT/Support/AppIcon.icns" ]]; then
    cp "$ROOT/Support/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
fi
# SwiftPM's generated resource accessor asserts when its bundle is absent.
# Ship the price list in the app's own Resources and read it there.
if [[ -f "$ROOT/Sources/ArrowslitKit/Resources/agent-prices.json" ]]; then
    cp "$ROOT/Sources/ArrowslitKit/Resources/agent-prices.json" "$APP/Contents/Resources/agent-prices.json"
fi
if [[ "$CONFIG" == "release" ]]; then
    strip -x "$APP/Contents/MacOS/Arrowslit"
    strip -x "$APP/Contents/Frameworks/libArrowslitMedia.dylib"
fi

xattr -dr com.apple.FinderInfo "$APP" 2>/dev/null || true
xattr -dr com.apple.ResourceFork "$APP" 2>/dev/null || true
TIMESTAMP_ARG="--timestamp=none"
if [[ "${SIGN_TIMESTAMP:-none}" == "timestamp" ]]; then
    TIMESTAMP_ARG="--timestamp"
fi
SIGN_ARGS=(--force --options runtime "$TIMESTAMP_ARG")
if [[ -n "${SIGN_IDENTITY:-}" ]]; then
    SIGN_ARGS+=(--sign "$SIGN_IDENTITY")
else
    SIGN_ARGS+=(--sign -)
fi

# A stable self-signed identity lets macOS keep TCC/Keychain permissions across builds. The
# dedicated keychain is only in the search list while codesigning, then the user's list is
# restored exactly as it was.
SIGN_KEYCHAIN="${SIGN_KEYCHAIN:-$HOME/Library/Keychains/arrowslit-signing.keychain-db}"
SIGN_PASSWORD_FILE="${SIGN_PASSWORD_FILE:-$HOME/Library/Application Support/Arrowslit/signing-keychain-password}"
SAVED_KEYCHAINS=()
ADDED_KEYCHAIN=0
restore_keychains() {
    if [[ "$ADDED_KEYCHAIN" == "1" ]]; then
        security list-keychains -d user -s "${SAVED_KEYCHAINS[@]}" >/dev/null 2>&1 || true
        ADDED_KEYCHAIN=0
    fi
}
if [[ -n "${SIGN_IDENTITY:-}" && -f "$SIGN_KEYCHAIN" ]]; then
    if [[ -f "$SIGN_PASSWORD_FILE" ]]; then
        security unlock-keychain -p "$(cat "$SIGN_PASSWORD_FILE")" "$SIGN_KEYCHAIN" >/dev/null
    fi
    while IFS= read -r keychain; do
        SAVED_KEYCHAINS+=("$keychain")
    done < <(security list-keychains -d user | sed -e 's/^[[:space:]]*"//' -e 's/"$//')
    security list-keychains -d user -s "$SIGN_KEYCHAIN" "${SAVED_KEYCHAINS[@]}" >/dev/null
    ADDED_KEYCHAIN=1
    trap restore_keychains EXIT
fi

codesign "${SIGN_ARGS[@]}" "$APP/Contents/Frameworks/libArrowslitMedia.dylib"
codesign "${SIGN_ARGS[@]}" --entitlements "$ROOT/Support/Arrowslit.entitlements" "$APP"
restore_keychains
trap - EXIT
codesign --verify --deep --strict "$APP"
echo "✓ Built $APP ($VERSION, build $BUILD_NUMBER)"
