import AppKit
import CryptoKit
import Foundation
import Observation

/// The history entry type used by the views. Pinned entries are the only ones written to disk.
public typealias ClipboardEntry = ClipboardHistory.Entry

/// Images are kept next to the app's support files. The history only stores the file name, so
/// pinned JSON stays small.
enum ClipboardImageStore {
    static var directory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        return base
            .appendingPathComponent("Arrowslit", isDirectory: true)
            .appendingPathComponent("Clipboard", isDirectory: true)
            .appendingPathComponent("Images", isDirectory: true)
    }

    @discardableResult
    static func save(_ data: Data, id: UUID) -> String? {
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let name = "\(id.uuidString).png"
            try data.write(to: directory.appendingPathComponent(name), options: .atomic)
            return name
        } catch {
            return nil
        }
    }

    static func load(_ name: String) -> Data? {
        try? Data(contentsOf: directory.appendingPathComponent(name))
    }

    static func delete(_ name: String?) {
        guard let name, !name.isEmpty else { return }
        try? FileManager.default.removeItem(at: directory.appendingPathComponent(name))
    }

    static func cleanup(keeping names: Set<String>) {
        guard let files = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else { return }
        for file in files where !names.contains(file.lastPathComponent) {
            try? FileManager.default.removeItem(at: file)
        }
    }
}

@MainActor
@Observable
public final class ClipboardService {
    public private(set) var history = ClipboardHistory()
    public private(set) var lastCopiedID: UUID?
    public private(set) var isWatching = false
    public private(set) var capturesRichContent = true

    public var entries: [ClipboardEntry] { history.entries }
    public var pinnedCount: Int { history.pinnedCount }
    public var canPin: Bool { history.canPin }

    @ObservationIgnored public var onCaptured: ((ClipboardEntry.Kind) -> Void)?
    @ObservationIgnored private let pasteboard: NSPasteboard
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private var lastChangeCount: Int
    @ObservationIgnored private var pollTimer: Timer?
    @ObservationIgnored private var feedbackTask: Task<Void, Never>?
    @ObservationIgnored private var ignoreConfidential: Bool
    @ObservationIgnored private var silentNextChange = false

    private static let pinsKey = "arrowslit.clipboard.pins"
    private static let capacityKey = "arrowslit.clipboard.capacity"
    private static let confidentialKey = "arrowslit.clipboard.ignoreConfidential"
    private static let richContentKey = "arrowslit.clipboard.richContent"

    public init(pasteboard: NSPasteboard = .general, defaults: UserDefaults = .standard) {
        self.pasteboard = pasteboard
        self.defaults = defaults
        let capacity = defaults.object(forKey: Self.capacityKey) as? Int ?? ClipboardHistory.capacity
        self.ignoreConfidential = defaults.object(forKey: Self.confidentialKey) as? Bool ?? true
        self.capturesRichContent = defaults.object(forKey: Self.richContentKey) as? Bool ?? true
        lastChangeCount = pasteboard.changeCount
        history = ClipboardHistory(capacity: capacity)
        loadPins()
        cleanupImageFiles()
    }

    public func start() {
        guard pollTimer == nil else { return }
        lastChangeCount = pasteboard.changeCount
        let timer = Timer(timeInterval: 0.7, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.poll() }
        }
        timer.tolerance = 0.25
        RunLoop.main.add(timer, forMode: .common)
        pollTimer = timer
        isWatching = true
    }

    public func stop() {
        pollTimer?.invalidate()
        pollTimer = nil
        isWatching = false
        let images = history.entries.filter { !$0.isPinned }.compactMap(\.imageFilename)
        history.removeAll(includingPinned: true)
        images.forEach(ClipboardImageStore.delete)
    }

    /// Clears the history. Pinned clips stay.
    public func clear() {
        let images = history.entries.filter { !$0.isPinned }.compactMap(\.imageFilename)
        history.removeAll()
        images.forEach(ClipboardImageStore.delete)
        savePins()
    }

    /// Clears every clip, including pinned ones.
    public func clearIncludingPinned() {
        let images = history.entries.compactMap(\.imageFilename)
        history.removeAll(includingPinned: true)
        images.forEach(ClipboardImageStore.delete)
        savePins()
    }

    public func setCapacity(_ value: Int) {
        let before = Dictionary(uniqueKeysWithValues: history.entries.map { ($0.id, $0) })
        history.setCapacity(value)
        let after = Set(history.entries.map(\.id))
        for (id, entry) in before where !after.contains(id) {
            ClipboardImageStore.delete(entry.imageFilename)
        }
        defaults.set(history.capacity, forKey: Self.capacityKey)
        savePins()
    }

    public func setIgnoreConfidential(_ value: Bool) {
        ignoreConfidential = value
        defaults.set(value, forKey: Self.confidentialKey)
    }

    public func setCapturesRichContent(_ value: Bool) {
        capturesRichContent = value
        defaults.set(value, forKey: Self.richContentKey)
    }

    public func togglePin(_ entry: ClipboardEntry) {
        if history.togglePin(entry.id) {
            savePins()
        }
    }

    public func matching(_ query: String) -> [ClipboardEntry] {
        history.matching(query)
    }

    /// Arrowslit writes screenshots itself; keep them in history but skip the clipboard HUD.
    public func suppressNextAlert() {
        silentNextChange = true
    }

    public func remove(_ id: UUID) {
        if let entry = history.entries.first(where: { $0.id == id }) {
            ClipboardImageStore.delete(entry.imageFilename)
        }
        history.remove(id)
        savePins()
    }

    public func imageData(for entry: ClipboardEntry) -> Data? {
        guard entry.kind == .image, let name = entry.imageFilename else { return nil }
        return ClipboardImageStore.load(name)
    }

    public func image(for entry: ClipboardEntry) -> NSImage? {
        guard let data = imageData(for: entry) else { return nil }
        return NSImage(data: data)
    }

    public func copy(_ entry: ClipboardEntry) {
        pasteboard.clearContents()
        switch entry.kind {
        case .text, .clip:
            if !entry.text.isEmpty {
                pasteboard.setString(entry.text, forType: .string)
            }
        case .url:
            pasteboard.setString(entry.text, forType: .string)
            pasteboard.setString(entry.text, forType: .URL)
        case .file:
            if let path = entry.filePath {
                pasteboard.writeObjects([URL(fileURLWithPath: path) as NSURL])
            } else {
                pasteboard.setString(entry.text, forType: .string)
            }
        case .image:
            if let data = imageData(for: entry) {
                pasteboard.setData(data, forType: .png)
                if let image = NSImage(data: data), let tiff = image.tiffRepresentation {
                    pasteboard.setData(tiff, forType: .tiff)
                }
            } else {
                pasteboard.setString(entry.previewText, forType: .string)
            }
        }
        lastChangeCount = pasteboard.changeCount

        let promoted = history.addEntry(entry)
        savePins()
        lastCopiedID = promoted ?? entry.id
        feedbackTask?.cancel()
        feedbackTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1.2))
            guard !Task.isCancelled else { return }
            self?.lastCopiedID = nil
        }
    }

    // MARK: - Pasteboard

    private func poll() {
        let count = pasteboard.changeCount
        guard count != lastChangeCount else { return }
        lastChangeCount = count
        let types = (pasteboard.types ?? []).map(\.rawValue)
        guard !ignoreConfidential || ClipboardRules.isRecordable(types: types) else { return }
        let appName = NSWorkspace.shared.frontmostApplication?.localizedName
        let silent = silentNextChange
        silentNextChange = false

        if capturesRichContent {
            if let url = firstFileURL() {
                promoteFile(url, appName: appName, silent: silent)
                return
            }
            if let image = imagePayload() {
                promoteImage(image, appName: appName, silent: silent)
                return
            }
        }

        if let text = pasteboard.string(forType: .string) {
            promote(text, appName: appName, silent: silent)
            return
        }

        if capturesRichContent, !types.isEmpty {
            promoteClip(appName: appName, silent: silent)
        }
    }

    private func firstFileURL() -> URL? {
        let options: [NSPasteboard.ReadingOptionKey: Any] = [.urlReadingFileURLsOnly: true]
        let objects = pasteboard.readObjects(forClasses: [NSURL.self], options: options) as? [URL]
        guard let url = objects?.first, url.isFileURL else { return nil }
        return url
    }

    private struct ImagePayload {
        let data: Data
        let width: Int
        let height: Int
        let hash: String
    }

    private func imagePayload() -> ImagePayload? {
        var data = pasteboard.data(forType: .png)
        if data == nil, let tiff = pasteboard.data(forType: .tiff) {
            data = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) ?? tiff
        }
        guard let data else { return nil }

        let rep = NSBitmapImageRep(data: data)
        let width = rep?.pixelsWide ?? NSImage(data: data)?.size.width.intValue ?? 0
        let height = rep?.pixelsHigh ?? NSImage(data: data)?.size.height.intValue ?? 0
        guard width > 0, height > 0 else { return nil }
        let png = rep?.representation(using: .png, properties: [:]) ?? data
        let digest = SHA256.hash(data: png).map { String(format: "%02x", $0) }.joined()
        return ImagePayload(data: png, width: width, height: height, hash: String(digest.prefix(24)))
    }

    private func promoteImage(_ payload: ImagePayload, appName: String?, silent: Bool = false) {
        let id = UUID()
        guard let filename = ClipboardImageStore.save(payload.data, id: id) else { return }
        let entry = ClipboardEntry(
            id: id,
            kind: .image,
            text: "",
            appName: appName,
            imageFilename: filename,
            imageWidth: payload.width,
            imageHeight: payload.height,
            imageHash: payload.hash
        )
        if let storedID = promoteEntry(entry, silent: silent), storedID != id {
            ClipboardImageStore.delete(filename)
        }
    }

    private func promoteFile(_ url: URL, appName: String?, silent: Bool = false) {
        guard FileManager.default.fileExists(atPath: url.path) else {
            promote(url.absoluteString, appName: appName, silent: silent)
            return
        }
        let entry = ClipboardEntry(
            kind: .file,
            text: url.lastPathComponent,
            appName: appName,
            filePath: url.path
        )
        _ = promoteEntry(entry, silent: silent)
    }

    private func promoteClip(appName: String?, silent: Bool = false) {
        _ = promoteEntry(ClipboardEntry(kind: .clip, text: "", appName: appName), silent: silent)
    }

    @discardableResult
    private func promoteEntry(_ entry: ClipboardEntry, silent: Bool = false) -> UUID? {
        let before = Dictionary(uniqueKeysWithValues: history.entries.map { ($0.id, $0) })
        guard let id = history.addEntry(entry) else { return nil }
        let after = Set(history.entries.map(\.id))
        for (oldID, old) in before where !after.contains(oldID) {
            ClipboardImageStore.delete(old.imageFilename)
        }
        savePins()
        if !silent { onCaptured?(entry.kind) }
        return id
    }

    /// Internal so the history/pin rules can be tested without a real pasteboard.
    func promote(_ text: String, appName: String?, silent: Bool = false) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let kind: ClipboardEntry.Kind
        if let url = URL(string: trimmed),
           let scheme = url.scheme?.lowercased(),
           ["http", "https"].contains(scheme) {
            kind = .url
        } else {
            kind = .text
        }
        _ = promoteEntry(ClipboardEntry(kind: kind, text: trimmed, appName: appName), silent: silent)
    }

    // MARK: - Persistence

    private func loadPins() {
        guard let data = defaults.data(forKey: Self.pinsKey),
              let pinned = try? JSONDecoder().decode([ClipboardEntry].self, from: data) else {
            return
        }
        history = ClipboardHistory(pinned: pinned, capacity: history.capacity)
    }

    private func savePins() {
        guard let data = try? JSONEncoder().encode(history.pinned) else { return }
        defaults.set(data, forKey: Self.pinsKey)
    }

    private func cleanupImageFiles() {
        let kept = Set(history.pinned.compactMap(\.imageFilename))
        ClipboardImageStore.cleanup(keeping: kept)
    }
}

private extension CGFloat {
    var intValue: Int { Int(self.rounded()) }
}
