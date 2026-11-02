# Release signing

## Update manifest (implemented)

Arrowslit verifies a base64 Ed25519 signature over the exact manifest bytes before installing an update.

- Private key: `~/Library/Application Support/Arrowslit/update-signing-key` (mode `0600`, never commit it)
- Public key: `Support/UpdatePublicKey.txt`, embedded as `ASUpdatePublicKey` in `Info.plist`
- Manifest: `Arrowslit-<version>.update.json`, containing `payload` and `signature`
- Payload: version, bundle identifier, DMG file name, byte size and SHA-256
- Verification: signature first, then version/bundle/file-name, size cap, SHA-256 and the staged app's bundle ID/version
- Failure: no install; the UI falls back to the DMG or an error

Build the manifest for a local release:

```bash
VERSION=0.10.0 BUILD_NUMBER=35 CONFIG=release ./Scripts/make-dmg.sh
cp build/Arrowslit.dmg build/Arrowslit-0.10.0.dmg
swift Scripts/sign-update.swift sign \
  "$HOME/Library/Application Support/Arrowslit/update-signing-key" \
  build/Arrowslit-0.10.0.dmg 0.10.0 com.j4yop.arrowslit \
  build/Arrowslit.app/Contents/Info.plist
```

The public key and the signing key must match, or the signer refuses to create the manifest.

## Stable code-signing identity (implemented)

macOS ties Accessibility, Camera, Calendar and Keychain access to the code signature. Every build
must use the same identity or those permissions reset. Arrowslit uses a dedicated self-signed
**Code Signing** certificate named `Arrowslit` in its own keychain:

- Keychain: `~/Library/Keychains/arrowslit-signing.keychain-db`
- Password file: `~/Library/Application Support/Arrowslit/signing-keychain-password` (mode `0600`)
- Identity: `Arrowslit`
- Designated requirement: `identifier "com.j4yop.arrowslit" and certificate leaf = H"27de8f…"`

Create it once (idempotent):

```bash
./Scripts/setup-signing.sh
security find-identity -p codesigning "$HOME/Library/Keychains/arrowslit-signing.keychain-db"
```

Build and release with it:

```bash
SIGN_IDENTITY="Arrowslit" VERSION=0.10.0 BUILD_NUMBER=35 \
  UPDATE_SIGNING_KEY_FILE="$HOME/Library/Application Support/Arrowslit/update-signing-key" \
  ./Scripts/release.sh
```

`Scripts/build-app.sh` unlocks the dedicated keychain for the two `codesign` calls, then restores the
user's search list exactly as it was. It falls back to ad-hoc signing when `SIGN_IDENTITY` is unset.
Keep the keychain, its password file and the Ed25519 private key backed up; losing the certificate
breaks permission continuity, and losing the update key makes future updates unverifiable.

This is a **self-signed** identity, not an Apple Developer ID. It gives local builds a stable
permission identity but does not remove Gatekeeper's “unidentified developer” warning for downloads.
A Developer ID certificate plus notarization is still required for a fully trusted public release.

## Release checks

- [x] Create the stable `Arrowslit` code-signing identity.
- [x] Sign a release build with it and verify `codesign --verify --deep --strict`.
- [x] Confirm the designated requirement is pinned to the certificate.
- [x] Run a real 0.9.2 → 0.10.0 upgrade and a second same-certificate upgrade; Accessibility, Camera and Calendar survived.
- [ ] Grant the existing Sports Keychain item its one-time “Always Allow” after the ad-hoc → stable-certificate migration.
- [x] Publish the DMG, `.sha256` and `.update.json` together.
- [x] Update the Homebrew cask to the same signed build and verify `brew fetch`.
- [ ] Test a failed signature, wrong bundle ID and oversized manifest before release.
- [ ] Decide whether to obtain a Developer ID certificate and notarize.
