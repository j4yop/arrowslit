import AppKit
import CryptoKit
import Foundation
import Security
import Observation

/// Checks GitHub for a newer release and downloads the DMG. Installing is deliberately manual:
/// the DMG opens, and the user drags Arrowslit into Applications.
@MainActor
@Observable
public final class UpdateService {
    public enum State: Equatable {
        case idle
        case checking
        case upToDate
        case available(ReleaseInfo)
        case downloading(Double)
        case downloaded(URL)
        case installing
        case failed(String)
    }

    public private(set) var state: State = .idle
    public private(set) var availableRelease: ReleaseInfo?
    @ObservationIgnored public var onAvailable: ((ReleaseInfo) -> Bool)?

    public var currentVersion: SemanticVersion? {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String).flatMap(SemanticVersion.init)
    }

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let session: URLSession
    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var task: Task<Void, Never>?

    private nonisolated static let latestRelease = URL(string: "https://api.github.com/repos/j4yop/arrowslit/releases/latest")!
    private static let checkInterval: TimeInterval = 24 * 3600
    nonisolated static let maximumDiskImageBytes = 100 * 1024 * 1024
    nonisolated static let maximumManifestBytes = 16 * 1024
    private static let maximumChecksumBytes = 4 * 1024

    public init(defaults: UserDefaults = .standard, session: URLSession = .shared) {
        self.defaults = defaults
        self.session = session
    }

    public func startAutomaticChecks() {
        guard timer == nil else { return }
        // A launch check makes a new release visible without waiting for the daily window.
        check(userInitiated: false)
        let timer = Timer(timeInterval: 3 * 3600, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.checkIfDue() }
        }
        timer.tolerance = 600
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    public func stop() {
        timer?.invalidate()
        timer = nil
        task?.cancel()
        task = nil
        if case .checking = state {
            state = .idle
        }
    }

    /// Runs at most once a day. A manual check always runs.
    public func checkIfDue() {
        let last = defaults.object(forKey: Key.lastCheck) as? Date ?? .distantPast
        guard Date().timeIntervalSince(last) >= Self.checkInterval else { return }
        check(userInitiated: false)
    }

    public func check(userInitiated: Bool = true) {
        if case .checking = state { return }
        if case .downloading = state { return }
        state = .checking
        task?.cancel()
        task = Task { [weak self] in
            guard let self else { return }
            do {
                let release = try await Self.fetchLatest(session: session, userAgent: "Arrowslit/\(currentVersion?.description ?? "0.0.0")")
                defaults.set(Date(), forKey: Key.lastCheck)
                if let current = currentVersion, release.version > current {
                    availableRelease = release
                    state = .available(release)
                    if !userInitiated {
                        notifyIfNeeded(release)
                    }
                } else {
                    availableRelease = nil
                    state = .upToDate
                }
            } catch {
                state = userInitiated
                    ? .failed("Couldn't reach GitHub. Check your connection and try again.")
                    : .idle
            }
        }
    }

    /// Automatic checks announce a version once. Manual checks only update the Settings row.
    func notifyIfNeeded(_ release: ReleaseInfo) {
        guard let onAvailable else { return }
        let version = release.version.description
        guard defaults.string(forKey: Key.lastNotifiedVersion) != version else { return }
        guard onAvailable(release) else { return }
        defaults.set(version, forKey: Key.lastNotifiedVersion)
    }

    /// Downloads, verifies and installs the release, then relaunches. Falls back to opening the
    /// DMG when this copy cannot replace itself or the release has no trusted manifest.
    public func install(_ release: ReleaseInfo) {
        guard canInstallInPlace(release) else {
            downloadAndOpen(release)
            return
        }
        if case .installing = state { return }
        availableRelease = release
        state = .installing
        task?.cancel()
        task = Task { [weak self] in
            guard let self else { return }
            do {
                guard let publicKey = Bundle.main.object(forInfoDictionaryKey: "ASUpdatePublicKey") as? String,
                      let identifier = Bundle.main.bundleIdentifier,
                      let current = currentVersion, release.version > current else {
                    throw UpdateError.unreadable
                }
                let staged = try await Self.download(release, publicKey: publicKey, bundleIdentifier: identifier)
                try Self.relaunch(replacing: Bundle.main.bundleURL, with: staged)
            } catch {
                state = .failed("The update couldn't be installed. You can download it from GitHub instead.")
            }
        }
    }

    /// Whether this copy can swap itself in place. A translocated or read-only copy, a missing
    /// public key, or a release without a signed manifest falls back to the DMG.
    public func canInstallInPlace(_ release: ReleaseInfo) -> Bool {
        Self.canInstallInPlace(
            release,
            app: Bundle.main.bundleURL,
            key: Bundle.main.object(forInfoDictionaryKey: "ASUpdatePublicKey") as? String
        )
    }

    nonisolated static func canInstallInPlace(_ release: ReleaseInfo, app: URL, key: String?) -> Bool {
        canReplace(app) && isUsableKey(key) && release.signedManifest != nil
    }

    nonisolated static func isUsableKey(_ key: String?) -> Bool {
        guard let key, let data = Data(base64Encoded: key) else { return false }
        return data.count == 32
    }

    nonisolated static func canReplace(_ app: URL) -> Bool {
        let path = app.path
        guard !path.contains("/AppTranslocation/"), !path.hasPrefix("/Volumes/") else { return false }
        return FileManager.default.isWritableFile(atPath: app.deletingLastPathComponent().path)
    }

    /// Downloads and verifies the manifest and disk image, then stages the app for the swap.
    nonisolated static func download(_ release: ReleaseInfo, publicKey: String, bundleIdentifier: String) async throws -> URL {
        guard let manifestURL = release.signedManifest,
              manifestURL.scheme == "https", release.diskImage.scheme == "https" else {
            throw UpdateError.unreadable
        }
        let (manifestData, manifestResponse) = try await boundedData(from: manifestURL, maximumBytes: maximumManifestBytes)
        guard (manifestResponse as? HTTPURLResponse)?.statusCode == 200,
              manifestResponse.url.map({ ReleaseInfo.isAllowedURL($0, forAsset: true) }) == true else {
            throw UpdateError.unreadable
        }
        let manifest = try UpdateVerification.manifest(
            manifestData,
            publicKey: publicKey,
            version: release.version,
            bundleIdentifier: bundleIdentifier,
            fileName: ReleaseInfo.diskImageName(for: release.version)
        )
        guard manifest.size <= maximumDiskImageBytes else { throw UpdateError.unreadable }
        let (image, response) = try await boundedData(from: release.diskImage, maximumBytes: manifest.size)
        guard (response as? HTTPURLResponse)?.statusCode == 200, response.url?.scheme == "https",
              response.url.map({ ReleaseInfo.isAllowedURL($0, forAsset: true) }) == true else {
            throw UpdateError.unreadable
        }
        try UpdateVerification.verify(image, manifest: manifest)

        let work = FileManager.default.temporaryDirectory.appendingPathComponent("ArrowslitUpdate-\(UUID().uuidString)")
        let mount = work.appendingPathComponent("mount")
        let staged = work.appendingPathComponent("staged")
        var keepStaged = false
        defer { if !keepStaged { try? FileManager.default.removeItem(at: work) } }
        try FileManager.default.createDirectory(at: work, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        let diskImage = work.appendingPathComponent(manifest.fileName)
        try image.write(to: diskImage, options: .atomic)
        try FileManager.default.createDirectory(at: mount, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: staged, withIntermediateDirectories: true)
        try run("/usr/bin/hdiutil", ["attach", diskImage.path, "-nobrowse", "-readonly", "-noautoopen", "-mountpoint", mount.path])
        defer { _ = try? run("/usr/bin/hdiutil", ["detach", mount.path, "-force"]) }
        guard let app = try FileManager.default.contentsOfDirectory(at: mount, includingPropertiesForKeys: nil)
            .first(where: { $0.pathExtension == "app" }) else { throw UpdateError.unreadable }
        let copy = staged.appendingPathComponent(app.lastPathComponent)
        try run("/usr/bin/ditto", [app.path, copy.path])
        try validateApp(copy, version: release.version, bundleIdentifier: bundleIdentifier)
        keepStaged = true
        return copy
    }

    nonisolated static func boundedData(from url: URL, maximumBytes: Int) async throws -> (Data, URLResponse) {
        let (bytes, response) = try await URLSession.shared.bytes(from: url)
        guard response.expectedContentLength <= Int64(maximumBytes) || response.expectedContentLength < 0 else {
            throw UpdateError.unreadable
        }
        var data = Data()
        if response.expectedContentLength > 0 {
            data.reserveCapacity(Int(response.expectedContentLength))
        }
        for try await byte in bytes {
            guard data.count < maximumBytes else { throw UpdateError.unreadable }
            data.append(byte)
        }
        return (data, response)
    }

    nonisolated static func validateApp(_ app: URL, version: SemanticVersion, bundleIdentifier: String) throws {
        guard let bundle = Bundle(url: app), bundle.bundleIdentifier == bundleIdentifier,
              bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String == version.description else {
            throw UpdateError.unreadable
        }
        var currentCode: SecStaticCode?
        guard SecStaticCodeCreateWithPath(Bundle.main.bundleURL as CFURL, [], &currentCode) == errSecSuccess,
              let currentCode else { throw UpdateError.unreadable }
        var information: CFDictionary?
        guard SecCodeCopySigningInformation(currentCode, SecCSFlags(rawValue: kSecCSSigningInformation), &information) == errSecSuccess else {
            throw UpdateError.unreadable
        }
        let team = (information as? [String: Any])?[kSecCodeInfoTeamIdentifier as String] as? String
        guard let team else { return }
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: ".-"))
        guard team.unicodeScalars.allSatisfy(allowed.contains),
              bundleIdentifier.unicodeScalars.allSatisfy(allowed.contains) else { throw UpdateError.unreadable }
        let expression = "anchor apple generic and certificate leaf[subject.OU] = \"\(team)\" and identifier \"\(bundleIdentifier)\""
        var requirement: SecRequirement?
        var candidate: SecStaticCode?
        guard SecRequirementCreateWithString(expression as CFString, [], &requirement) == errSecSuccess,
              SecStaticCodeCreateWithPath(app as CFURL, [], &candidate) == errSecSuccess,
              let candidate, let requirement,
              SecStaticCodeCheckValidity(candidate, SecCSFlags(rawValue: kSecCSCheckAllArchitectures | kSecCSCheckNestedCode | kSecCSStrictValidate), requirement) == errSecSuccess else {
            throw UpdateError.unreadable
        }
    }

    static func relaunch(replacing destination: URL, with staged: URL) throws {
        let script = """
        while kill -0 "$1" 2>/dev/null; do sleep 0.2; done
        rm -rf "$2.old" && mv "$2" "$2.old" && /usr/bin/ditto "$3" "$2" && rm -rf "$2.old" || { rm -rf "$2"; mv "$2.old" "$2"; }
        /usr/bin/open "$2"
        """
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", script, "sh", String(ProcessInfo.processInfo.processIdentifier), destination.path, staged.path]
        try process.run()
        NSApp.terminate(nil)
    }

    @discardableResult
    nonisolated static func run(_ tool: String, _ arguments: [String]) throws -> Int32 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: tool)
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { throw UpdateError.unreadable }
        return process.terminationStatus
    }

    /// Downloads the DMG, verifies the published checksum when available, then opens the image.
    public func downloadAndOpen(_ release: ReleaseInfo) {
        if case .downloading = state { return }
        availableRelease = release
        state = .downloading(0)
        task?.cancel()
        task = Task { [weak self] in
            guard let self else { return }
            do {
                let (bytes, response) = try await session.bytes(from: release.diskImage)
                guard let http = response as? HTTPURLResponse, http.statusCode == 200,
                      http.expectedContentLength <= Int64(Self.maximumDiskImageBytes) || http.expectedContentLength < 0,
                      ReleaseInfo.isAllowedURL(response.url ?? release.diskImage, forAsset: true) else {
                    throw UpdateError.unreadable
                }

                var image = Data()
                if http.expectedContentLength > 0 {
                    image.reserveCapacity(Int(http.expectedContentLength))
                }
                var lastProgress = 0.0
                for try await byte in bytes {
                    guard image.count < Self.maximumDiskImageBytes else { throw UpdateError.unreadable }
                    image.append(byte)
                    if http.expectedContentLength > 0 {
                        let progress = min(1, Double(image.count) / Double(http.expectedContentLength))
                        if progress - lastProgress >= 0.01 {
                            lastProgress = progress
                            state = .downloading(progress)
                        }
                    }
                }

                if let checksumURL = release.checksum {
                    let (checksumData, checksumResponse) = try await session.data(from: checksumURL)
                    guard (checksumResponse as? HTTPURLResponse)?.statusCode == 200,
                          checksumData.count <= Self.maximumChecksumBytes,
                          let expected = String(data: checksumData, encoding: .utf8)?
                            .split(whereSeparator: \.isWhitespace).first.map(String.init),
                          expected.count == 64 else {
                        throw UpdateError.unreadable
                    }
                    let actual = SHA256.hash(data: image).map { String(format: "%02x", $0) }.joined()
                    guard actual.caseInsensitiveCompare(expected) == .orderedSame else {
                        throw UpdateError.unreadable
                    }
                }

                let folder = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
                    ?? FileManager.default.temporaryDirectory
                let destination = folder.appendingPathComponent("Arrowslit-\(release.version).dmg")
                try image.write(to: destination, options: .atomic)
                state = .downloaded(destination)
                NSWorkspace.shared.open(destination)
            } catch {
                state = .failed("The update couldn't be downloaded. Try again, or download it from GitHub.")
            }
        }
    }

    nonisolated private static func fetchLatest(session: URLSession, userAgent: String) async throws -> ReleaseInfo {
        var request = URLRequest(url: URL(string: "https://github.com/j4yop/arrowslit/releases/latest")!, timeoutInterval: 20)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        if let (_, response) = try? await session.data(for: request),
           let http = response as? HTTPURLResponse, http.statusCode == 200,
           let finalURL = response.url,
           let release = ReleaseInfo.fromLatestRedirect(finalURL) {
            return release
        }

        // Fallback for networks where the redirect is unavailable.
        var api = URLRequest(url: latestRelease, timeoutInterval: 20)
        api.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        api.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        let (data, response) = try await session.data(for: api)
        guard (response as? HTTPURLResponse)?.statusCode == 200,
              let release = ReleaseInfo.parse(data) else {
            throw UpdateError.unreadable
        }
        return release
    }

    #if DEBUG
    /// Debug builds only: show the available-update row without contacting GitHub.
    public func showDemo(version: String = "0.4.5") {
        guard let version = SemanticVersion(version) else { return }
        let release = ReleaseInfo(
            version: version,
            page: URL(string: "https://github.com/j4yop/arrowslit/releases/tag/v\(version)")!,
            diskImage: URL(string: "https://github.com/j4yop/arrowslit/releases/download/v\(version)/Arrowslit-\(version).dmg")!,
            checksum: URL(string: "https://github.com/j4yop/arrowslit/releases/download/v\(version)/Arrowslit-\(version).dmg.sha256")!
        )
        availableRelease = release
        state = .available(release)
    }
    #endif

    private enum UpdateError: Error {
        case unreadable
    }

    private enum Key {
        static let lastCheck = "arrowslit.updates.lastCheck"
        static let lastNotifiedVersion = "arrowslit.updates.lastNotifiedVersion"
    }
}
