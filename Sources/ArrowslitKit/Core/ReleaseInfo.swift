import Foundation

/// The parts of GitHub's latest-release response the updater needs.
public struct ReleaseInfo: Equatable, Sendable {
    public var version: SemanticVersion
    public var page: URL
    public var diskImage: URL
    public var checksum: URL?

    public init(version: SemanticVersion, page: URL, diskImage: URL, checksum: URL? = nil) {
        self.version = version
        self.page = page
        self.diskImage = diskImage
        self.checksum = checksum
    }

    public static func parse(_ data: Data) -> ReleaseInfo? {
        guard
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let tag = json["tag_name"] as? String,
            let version = SemanticVersion(tag),
            let pageString = json["html_url"] as? String,
            let page = URL(string: pageString),
            isAllowedURL(page, forAsset: false),
            let assets = json["assets"] as? [[String: Any]]
        else { return nil }

        func asset(named name: String) -> URL? {
            assets.first { $0["name"] as? String == name }
                .flatMap { $0["browser_download_url"] as? String }
                .flatMap(URL.init(string:))
                .flatMap { isAllowedURL($0, forAsset: true) ? $0 : nil }
        }

        guard let diskImage = asset(named: "Arrowslit-\(version).dmg") else { return nil }
        return ReleaseInfo(
            version: version,
            page: page,
            diskImage: diskImage,
            checksum: asset(named: "Arrowslit-\(version).dmg.sha256")
        )
    }

    /// Release URLs are metadata, not a trust anchor. Keep them on GitHub.
    public static func isAllowedURL(_ url: URL, forAsset: Bool) -> Bool {
        guard url.scheme?.lowercased() == "https", let host = url.host?.lowercased() else { return false }
        let assetHosts: Set<String> = [
            "github.com",
            "objects.githubusercontent.com",
            "release-assets.githubusercontent.com",
        ]
        return forAsset ? assetHosts.contains(host) : host == "github.com"
    }
}
