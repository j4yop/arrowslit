import AppKit
import Foundation
import Observation

public struct TrayItem: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let url: URL
    public let addedAt: Date

    public var name: String { url.lastPathComponent }
}

@MainActor
@Observable
public final class TrayStore {
    public private(set) var items: [TrayItem] = []
    public static let capacity = 30

    public init() {}

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
    }

    public func clear() {
        items.removeAll()
    }

    public func pruneMissing() {
        items.removeAll { !FileManager.default.fileExists(atPath: $0.url.path) }
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
}
