import AppKit
import CryptoKit
import Foundation
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
    private static let maximumDiskImageBytes = 50 * 1024 * 1024
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
