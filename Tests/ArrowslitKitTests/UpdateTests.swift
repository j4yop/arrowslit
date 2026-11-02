import CryptoKit
import Foundation
import Testing
@testable import ArrowslitKit

@Suite("Signed updates")
struct SignedUpdateTests {
    private func makeManifest(
        key: Curve25519.Signing.PrivateKey,
        version: String = "0.10.0",
        bundleID: String = "com.j4yop.arrowslit",
        fileName: String = "Arrowslit-0.10.0.dmg",
        image: Data = Data(repeating: 0x41, count: 64)
    ) throws -> (Data, UpdateManifest) {
        let manifest = UpdateManifest(
            version: version,
            bundleIdentifier: bundleID,
            fileName: fileName,
            size: image.count,
            sha256: SHA256.hash(data: image).map { String(format: "%02x", $0) }.joined()
        )
        let payload = try JSONEncoder().encode(manifest)
        let envelope = SignedUpdateManifest(payload: payload, signature: try key.signature(for: payload))
        return (try JSONEncoder().encode(envelope), manifest)
    }

    @Test func verifiesASignedManifestAndImage() throws {
        let key = Curve25519.Signing.PrivateKey()
        let image = Data(repeating: 0x41, count: 64)
        let (data, manifest) = try makeManifest(key: key, image: image)
        let parsed = try UpdateVerification.manifest(
            data,
            publicKey: key.publicKey.rawRepresentation.base64EncodedString(),
            version: SemanticVersion("0.10.0")!,
            bundleIdentifier: "com.j4yop.arrowslit",
            fileName: "Arrowslit-0.10.0.dmg"
        )
        #expect(parsed.size == manifest.size)
        try UpdateVerification.verify(image, manifest: parsed)
    }

    @Test func rejectsATamperedImageOrWrongMetadata() throws {
        let key = Curve25519.Signing.PrivateKey()
        let image = Data(repeating: 0x41, count: 64)
        let (data, manifest) = try makeManifest(key: key, image: image)
        let keyString = key.publicKey.rawRepresentation.base64EncodedString()
        #expect(throws: Error.self) {
            try UpdateVerification.verify(Data(repeating: 0x42, count: 64), manifest: manifest)
        }
        #expect(throws: Error.self) {
            try UpdateVerification.manifest(
                data, publicKey: keyString, version: SemanticVersion("0.10.1")!,
                bundleIdentifier: "com.j4yop.arrowslit", fileName: "Arrowslit-0.10.0.dmg"
            )
        }
        #expect(throws: Error.self) {
            try UpdateVerification.manifest(
                data, publicKey: keyString, version: SemanticVersion("0.10.0")!,
                bundleIdentifier: "com.example.other", fileName: "Arrowslit-0.10.0.dmg"
            )
        }
    }

    @Test func parsesTheManifestAssetFromGitHub() throws {
        let json: [String: Any] = [
            "tag_name": "v0.10.0",
            "html_url": "https://github.com/j4yop/arrowslit/releases/tag/v0.10.0",
            "assets": [
                ["name": "Arrowslit-0.10.0.dmg", "browser_download_url": "https://github.com/j4yop/arrowslit/releases/download/v0.10.0/Arrowslit-0.10.0.dmg"],
                ["name": "Arrowslit-0.10.0.dmg.sha256", "browser_download_url": "https://github.com/j4yop/arrowslit/releases/download/v0.10.0/Arrowslit-0.10.0.dmg.sha256"],
                ["name": "Arrowslit-0.10.0.update.json", "browser_download_url": "https://github.com/j4yop/arrowslit/releases/download/v0.10.0/Arrowslit-0.10.0.update.json"],
            ],
        ]
        let data = try JSONSerialization.data(withJSONObject: json)
        let release = try #require(ReleaseInfo.parse(data))
        #expect(release.version.description == "0.10.0")
        #expect(release.signedManifest?.lastPathComponent == "Arrowslit-0.10.0.update.json")
    }

    @Test func validatesThePublicKeyShapeAndReplaceability() {
        let key = Curve25519.Signing.PrivateKey()
        #expect(UpdateService.isUsableKey(key.publicKey.rawRepresentation.base64EncodedString()))
        #expect(!UpdateService.isUsableKey(""))
        #expect(!UpdateService.isUsableKey("not base64"))
        #expect(UpdateService.canReplace(URL(fileURLWithPath: "/tmp/Arrowslit.app")))
        #expect(!UpdateService.canReplace(URL(fileURLWithPath: "/Volumes/Arrowslit/Arrowslit.app")))
    }
}
