#!/usr/bin/env bash
# Creates a stable, self-signed Arrowslit code-signing identity in a dedicated keychain.
# The identity is what macOS uses to keep Accessibility/Camera/Calendar/Keychain permissions
# across updates. It is not a Developer ID and does not replace notarization.
set -euo pipefail

KEYCHAIN="${SIGN_KEYCHAIN:-$HOME/Library/Keychains/arrowslit-signing.keychain-db}"
PASSWORD_FILE="${SIGN_PASSWORD_FILE:-$HOME/Library/Application Support/Arrowslit/signing-keychain-password}"
IDENTITY="${SIGN_IDENTITY:-Arrowslit}"
DAYS="${SIGN_DAYS:-3650}"

mkdir -p "$(dirname "$PASSWORD_FILE")"
chmod 700 "$(dirname "$PASSWORD_FILE")"

if security find-identity -p codesigning "$KEYCHAIN" 2>/dev/null | grep -q "\"$IDENTITY\""; then
    echo "✓ $IDENTITY already exists in $KEYCHAIN"
    exit 0
fi

if [[ -f "$PASSWORD_FILE" ]]; then
    PASSWORD="$(cat "$PASSWORD_FILE")"
else
    PASSWORD="$(openssl rand -base64 32 | tr -d '\n')"
    printf '%s' "$PASSWORD" > "$PASSWORD_FILE"
    chmod 600 "$PASSWORD_FILE"
fi

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

security create-keychain -p "$PASSWORD" "$KEYCHAIN"
security set-keychain-settings -lut 21600 "$KEYCHAIN"
security unlock-keychain -p "$PASSWORD" "$KEYCHAIN"

openssl req -x509 -newkey rsa:2048 -nodes \
    -keyout "$WORK/key.pem" -out "$WORK/cert.pem" -days "$DAYS" \
    -subj "/CN=$IDENTITY" \
    -addext "extendedKeyUsage=codeSigning" \
    -addext "keyUsage=digitalSignature" \
    -addext "basicConstraints=critical,CA:false" >/dev/null 2>&1

openssl pkcs12 -export -legacy -out "$WORK/identity.p12" \
    -inkey "$WORK/key.pem" -in "$WORK/cert.pem" -passout "pass:$PASSWORD" >/dev/null 2>&1

security import "$WORK/identity.p12" -k "$KEYCHAIN" -P "$PASSWORD" -T /usr/bin/codesign -A >/dev/null
security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$PASSWORD" "$KEYCHAIN" >/dev/null 2>&1 || true

security find-identity -p codesigning "$KEYCHAIN" | grep "\"$IDENTITY\""
echo "✓ Created $IDENTITY in $KEYCHAIN"
echo "  Password file: $PASSWORD_FILE (mode 600; back it up with the keychain)"
