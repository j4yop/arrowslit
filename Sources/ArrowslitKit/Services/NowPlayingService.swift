import AppKit
import Foundation
import Observation

public struct NowPlayingTrack: Equatable, Sendable {
    public var title: String
    public var artist: String
    public var album: String
    public var duration: TimeInterval?
    public var elapsed: TimeInterval?
    public var sampledAt: Date?
    public var rate: Double
    public var isPlaying: Bool
    public var bundleIdentifier: String?
    public var artworkKey: String?

    public var hasContent: Bool { !title.isEmpty || !artist.isEmpty }

    public func elapsed(at date: Date) -> TimeInterval? {
        guard let elapsed else { return nil }
        var value = elapsed
        if isPlaying, let sampledAt {
            value += max(0, date.timeIntervalSince(sampledAt)) * (rate > 0 ? rate : 1)
        }
        if let duration, duration > 0 { value = min(value, duration) }
        return max(0, value)
    }

    public func progress(at date: Date) -> Double? {
        guard let duration, duration > 0, let elapsed = elapsed(at: date) else { return nil }
        return min(max(elapsed / duration, 0), 1)
    }
}

@MainActor
@Observable
public final class NowPlayingService {
    public private(set) var track: NowPlayingTrack?
    public private(set) var artwork: NSImage?
    public private(set) var accent: ArtworkAccent = .white
    public private(set) var isAvailable = true

    @ObservationIgnored private let reader = MediaLineReader()
    @ObservationIgnored private var process: Process?
    @ObservationIgnored private var input: FileHandle?
    @ObservationIgnored private var isStopping = false
    @ObservationIgnored private var launches: [Date] = []

    public init() {}

    public var isVisible: Bool {
        track?.hasContent == true && track?.isPlaying == true
    }

    public func start() {
        isStopping = false
        launch()
    }

    public func stop() {
        isStopping = true
        try? input?.close()
        input = nil
        if let process, process.isRunning { process.terminate() }
        process = nil
        reader.reset()
        track = nil
        artwork = nil
        accent = .white
    }

    public func toggle() {
        guard var current = track else { return }
        current.elapsed = current.elapsed(at: Date())
        current.sampledAt = Date()
        current.isPlaying.toggle()
        track = current
        send("toggle")
    }

    public func next() { send("next") }
    public func previous() { send("previous") }

    public func seek(to seconds: TimeInterval) {
        guard var current = track, let duration = current.duration else { return }
        let target = min(max(seconds, 0), duration)
        current.elapsed = target
        current.sampledAt = Date()
        track = current
        send("seek \(target)")
    }

    private func send(_ command: String) {
        guard let input else { return }
        do {
            try input.write(contentsOf: Data((command + "\n").utf8))
        } catch {
            // A dead helper is restarted by the termination handler.
        }
    }

    private func launch() {
        guard FileManager.default.isExecutableFile(atPath: "/usr/bin/perl") else {
            isAvailable = false
            return
        }
        guard let bundled = Self.locateLibrary() else {
            isAvailable = false
            return
        }
        let library = Self.unquarantinedCopy(of: bundled) ?? bundled

        let now = Date()
        launches = launches.filter { now.timeIntervalSince($0) < 300 } + [now]
        guard launches.count <= 5 else {
            isAvailable = false
            return
        }

        let script = """
        use strict; use warnings; use DynaLoader;
        my $lib = DynaLoader::dl_load_file($ARGV[0], 0) or die "load: " . DynaLoader::dl_error() . "\\n";
        my $sym = DynaLoader::dl_find_symbol($lib, "arrowslit_media_stream") or die "missing symbol\\n";
        DynaLoader::dl_install_xsub("main::arrowslit_media_stream", $sym)->();
        """
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/perl")
        process.arguments = ["-e", script, library.path]
        let output = Pipe()
        let input = Pipe()
        process.standardOutput = output
        process.standardInput = input
        process.standardError = FileHandle.nullDevice

        let reader = self.reader
        output.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            if data.isEmpty {
                handle.readabilityHandler = nil
                return
            }
            reader.append(data) { messages in
                DispatchQueue.main.async {
                    MainActor.assumeIsolated { self?.apply(messages) }
                }
            }
        }
        process.terminationHandler = { [weak self] finished in
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    guard let self, self.process === finished else { return }
                    self.process = nil
                    self.input = nil
                    guard !self.isStopping else { return }
                    self.isAvailable = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        MainActor.assumeIsolated {
                            guard !self.isStopping, self.process == nil else { return }
                            self.launch()
                        }
                    }
                }
            }
        }

        do {
            try process.run()
            self.process = process
            self.input = input.fileHandleForWriting
            isAvailable = true
            send("refresh")
        } catch {
            isAvailable = false
        }
    }

    private func apply(_ messages: [ParsedWireMessage]) {
        for parsed in messages {
            let message = parsed.message
            switch message.type {
            case "ready":
                isAvailable = true
            case "track":
                applyTrack(message, accent: parsed.accent)
            default:
                break
            }
        }
    }

    private func applyTrack(_ message: WireMessage, accent: ArtworkAccent?) {
        guard message.hasInfo == true else {
            track = nil
            artwork = nil
            self.accent = .white
            return
        }
        let title = message.title ?? ""
        let artist = message.artist ?? ""
        guard !title.isEmpty || !artist.isEmpty else {
            track = nil
            artwork = nil
            self.accent = .white
            return
        }
        let newTrack = NowPlayingTrack(
            title: title,
            artist: artist,
            album: message.album ?? "",
            duration: message.duration,
            elapsed: message.elapsed,
            sampledAt: message.timestamp.map(Date.init(timeIntervalSince1970:)),
            rate: message.rate ?? 0,
            isPlaying: message.playing ?? false,
            bundleIdentifier: message.bundleID,
            artworkKey: message.artworkKey
        )
        if let encoded = message.artwork, let data = Data(base64Encoded: encoded), let image = NSImage(data: data) {
            artwork = image
            self.accent = accent ?? .white
        } else if newTrack.artworkKey == nil || newTrack.artworkKey != track?.artworkKey || artwork == nil {
            artwork = nil
            self.accent = .white
        }
        track = newTrack
    }

    nonisolated private static func locateLibrary(bundle: Bundle = .main) -> URL? {
        [
            bundle.privateFrameworksURL?.appendingPathComponent("libArrowslitMedia.dylib"),
            bundle.resourceURL?.appendingPathComponent("libArrowslitMedia.dylib"),
            bundle.executableURL?.deletingLastPathComponent().appendingPathComponent("libArrowslitMedia.dylib"),
        ].compactMap { $0 }.first { FileManager.default.fileExists(atPath: $0.path) }
    }

    /// A copy written by the app has no quarantine flag, so Perl can load it from a downloaded app.
    nonisolated private static func unquarantinedCopy(of library: URL, fileManager: FileManager = .default) -> URL? {
        guard
            let folder = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
                .appendingPathComponent("Arrowslit", isDirectory: true),
            let bytes = try? Data(contentsOf: library)
        else { return nil }
        let copy = folder.appendingPathComponent("libArrowslitMedia.dylib")
        do {
            if (try? Data(contentsOf: copy)) != bytes {
                try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
                try bytes.write(to: copy, options: .atomic)
            }
            removexattr(copy.path, "com.apple.quarantine", 0)
            return copy
        } catch {
            return nil
        }
    }
}

private struct ParsedWireMessage: Sendable {
    let message: WireMessage
    let accent: ArtworkAccent?
}

private struct WireMessage: Decodable, Sendable {
    let type: String
    let hasInfo: Bool?
    let playing: Bool?
    let title: String?
    let artist: String?
    let album: String?
    let duration: Double?
    let elapsed: Double?
    let rate: Double?
    let timestamp: Double?
    let bundleID: String?
    let artworkKey: String?
    let artwork: String?
}

private final class MediaLineReader: @unchecked Sendable {
    private let queue = DispatchQueue(label: "com.j4yop.arrowslit.media.reader", qos: .utility)
    private var buffer = Data()
    private static let maximumBuffer = 8 * 1024 * 1024

    func reset() {
        queue.sync { buffer.removeAll() }
    }

    func append(_ data: Data, deliver: @escaping @Sendable ([ParsedWireMessage]) -> Void) {
        queue.async {
            self.buffer.append(data)
            var messages: [ParsedWireMessage] = []
            while let newline = self.buffer.firstIndex(of: 0x0A) {
                let line = Data(self.buffer[self.buffer.startIndex..<newline])
                self.buffer.removeSubrange(self.buffer.startIndex...newline)
                guard !line.isEmpty else { continue }
                if let message = try? JSONDecoder().decode(WireMessage.self, from: line) {
                    let accent = message.artwork
                        .flatMap { Data(base64Encoded: $0) }
                        .map { ArtworkAccentReader.accent(from: $0) }
                    messages.append(ParsedWireMessage(message: message, accent: accent))
                }
            }
            if self.buffer.count > Self.maximumBuffer {
                self.buffer.removeAll()
            }
            if !messages.isEmpty {
                deliver(messages)
            }
        }
    }
}
