import AppKit
import Foundation
import Observation

public struct TrayItem: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let url: URL
    public let addedAt: Date
    public var isPinned: Bool

    public var name: String { url.lastPathComponent }

    public init(id: UUID, url: URL, addedAt: Date, isPinned: Bool = false) {
        self.id = id
        self.url = url
        self.addedAt = addedAt
        self.isPinned = isPinned
    }
}

@MainActor
@Observable
public final class TrayStore {
    public private(set) var items: [TrayItem] = []
    public static let capacity = 30

    @ObservationIgnored private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        loadPinned()
    }

    private func loadPinned() {
        let paths = defaults.stringArray(forKey: Key.pinned) ?? []
        let existing = Set(items.map(\.url.standardizedFileURL))
        var loaded: [TrayItem] = []
        for path in paths {
            let url = URL(fileURLWithPath: path).standardizedFileURL
            guard FileManager.default.fileExists(atPath: url.path),
                  !existing.contains(url),
                  loaded.count < Self.capacity else { continue }
            loaded.append(TrayItem(id: UUID(), url: url, addedAt: Date(), isPinned: true))
        }
        items = loaded
    }

    private func savePinned() {
        defaults.set(items.filter(\.isPinned).map(\.url.path), forKey: Key.pinned)
    }

    @discardableResult
    public func add(_ urls: [URL]) -> Int {
        pruneMissing()
        var existing = Set(items.map(\.url.standardizedFileURL))
        var added: [TrayItem] = []
        for url in urls {
            guard url.isFileURL else { continue }
            let standard = url.standardizedFileURL
            guard FileManager.default.fileExists(atPath: standard.path),
                  !existing.contains(standard),
                  items.count + added.count < Self.capacity else { continue }
            existing.insert(standard)
            added.append(TrayItem(id: UUID(), url: standard, addedAt: Date()))
        }
        guard !added.isEmpty else { return 0 }
        items = added.reversed() + items
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
        return added.count
    }

    public func remove(_ id: UUID) {
        items.removeAll { $0.id == id }
        savePinned()
    }

    public func clear() {
        items.removeAll()
        savePinned()
    }

    /// On quit, only the files the user pinned survive into the next launch.
    public func clearUnpinned() {
        items.removeAll { !$0.isPinned }
        savePinned()
    }

    public func togglePin(_ id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].isPinned.toggle()
        savePinned()
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
    }

    public func pruneMissing() {
        items.removeAll { !FileManager.default.fileExists(atPath: $0.url.path) }
        savePinned()
    }

    public func open(_ item: TrayItem) {
        NSWorkspace.shared.open(item.url)
    }

    public func reveal(_ item: TrayItem) {
        NSWorkspace.shared.activateFileViewerSelecting([item.url])
    }

    public func airDrop(_ items: [TrayItem]) {
        airDrop(items.map(\.url))
    }

    public func airDrop(_ urls: [URL]) {
        let files = urls.filter(\.isFileURL)
        guard !files.isEmpty else { return }
        NSApp.activate(ignoringOtherApps: true)
        NSSharingService(named: .sendViaAirDrop)?.perform(withItems: files)
    }

    public func icon(for item: TrayItem) -> NSImage {
        NSWorkspace.shared.icon(forFile: item.url.path)
    }

    private enum Key {
        static let pinned = "arrowslit.tray.pinned"
    }
}
