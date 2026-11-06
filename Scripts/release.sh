#!/usr/bin/env bash
# Builds, signs and publishes an Arrowslit release.
#
# Required environment:
#   VERSION=0.10.1
#   UPDATE_SIGNING_KEY_FILE=$HOME/Library/Application Support/Arrowslit/update-signing-key
# Optional:
#   SIGN_IDENTITY="Arrowslit" (stable self-signed certificate; otherwise ad-hoc)
#   SIGN_KEYCHAIN=$HOME/Library/Keychains/arrowslit-signing.keychain-db
#   SIGN_PASSWORD_FILE=$HOME/Library/Application Support/Arrowslit/signing-keychain-password
#   BUILD_NUMBER=35
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

VERSION="${VERSION:?Set VERSION, e.g. VERSION=0.10.1}"
BUILD_NUMBER="${BUILD_NUMBER:-$(git rev-list --count HEAD)}"
TAG="v$VERSION"
DMG="$ROOT/build/Arrowslit-$VERSION.dmg"
UPDATE="$ROOT/build/Arrowslit-$VERSION.update.json"

[[ -s Support/UpdatePublicKey.txt ]] || { echo "✗ Support/UpdatePublicKey.txt is empty" >&2; exit 1; }
[[ -n "${UPDATE_SIGNING_KEY_FILE:-}" && -f "$UPDATE_SIGNING_KEY_FILE" ]] || {
    echo "✗ Set UPDATE_SIGNING_KEY_FILE to the private Ed25519 key" >&2
    exit 1
}
git diff --quiet && git diff --cached --quiet || { echo "✗ Commit your changes first" >&2; exit 1; }
git rev-parse -q --verify "refs/tags/$TAG" >/dev/null && { echo "✗ $TAG already exists" >&2; exit 1; }

SIGN_IDENTITY="${SIGN_IDENTITY:-Arrowslit}"
SIGN_KEYCHAIN="${SIGN_KEYCHAIN:-$HOME/Library/Keychains/arrowslit-signing.keychain-db}"
SIGN_PASSWORD_FILE="${SIGN_PASSWORD_FILE:-$HOME/Library/Application Support/Arrowslit/signing-keychain-password}"
UNIVERSAL="${UNIVERSAL:-1}"
NOTARY_PROFILE="${NOTARY_PROFILE:-}"
SIGN_TIMESTAMP="${SIGN_TIMESTAMP:-none}"
if [[ -n "$NOTARY_PROFILE" ]]; then
    if [[ "$SIGN_IDENTITY" != "Developer ID Application"* ]]; then
        echo "✗ NOTARY_PROFILE is set, but SIGN_IDENTITY is '$SIGN_IDENTITY'." >&2
        echo "  Notarization needs a Developer ID Application certificate." >&2
        exit 1
    fi
    SIGN_TIMESTAMP=timestamp
    echo "› Notarization enabled ($NOTARY_PROFILE)"
else
    echo "⚠ NOTARY_PROFILE is not set: this DMG will be signed but not notarized."
    echo "  Users will need Open Anyway or the Terminal xattr step in Install.txt."
fi
export SIGN_IDENTITY SIGN_KEYCHAIN SIGN_PASSWORD_FILE UNIVERSAL NOTARY_PROFILE SIGN_TIMESTAMP
if ! security find-identity -p codesigning "$SIGN_KEYCHAIN" 2>/dev/null | grep -q "\"$SIGN_IDENTITY\""; then
    echo "✗ $SIGN_IDENTITY is not in $SIGN_KEYCHAIN; run Scripts/setup-signing.sh first" >&2
    exit 1
fi

if [[ "${SKIP_BUILD:-0}" == "1" ]]; then
    [[ -f "$ROOT/build/Arrowslit.dmg" ]] || {
        echo "✗ SKIP_BUILD=1 but build/Arrowslit.dmg is missing" >&2
        exit 1
    }
    echo "› Reusing build/Arrowslit.dmg (SKIP_BUILD=1)"
else
    CONFIG=release VERSION="$VERSION" BUILD_NUMBER="$BUILD_NUMBER" UNIVERSAL="$UNIVERSAL" SIGN_TIMESTAMP="$SIGN_TIMESTAMP" ./Scripts/make-dmg.sh
fi
cp "$ROOT/build/Arrowslit.dmg" "$DMG"
( cd "$ROOT/build" && shasum -a 256 "$(basename "$DMG")" > "$(basename "$DMG").sha256" )
if [[ -n "$NOTARY_PROFILE" ]]; then
    echo "› Submitting $DMG for notarization…"
    xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
    xcrun stapler staple "$DMG"
    xcrun stapler validate "$DMG"
fi
swift Scripts/sign-update.swift sign "$UPDATE_SIGNING_KEY_FILE" "$DMG" "$VERSION" "com.j4yop.arrowslit" "$ROOT/build/Arrowslit.app/Contents/Info.plist"
[[ -s "$UPDATE" ]] || { echo "✗ Update manifest was not created" >&2; exit 1; }

NOTES="${RELEASE_NOTES:-Arrowslit $VERSION. Download the DMG or update from Settings › About.}"
git tag -a "$TAG" -m "Arrowslit $VERSION"
BRANCH="$(git branch --show-current)"
git push origin "$BRANCH" "$TAG"
gh release create "$TAG" "$DMG" "$DMG.sha256" "$UPDATE" \
  --title "Arrowslit $VERSION" \
  --notes "$NOTES"
echo "✓ Released $TAG"
