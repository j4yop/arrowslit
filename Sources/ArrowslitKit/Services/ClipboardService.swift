import AppKit
import Foundation
import Observation

public struct ClipboardEntry: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let text: String
    public let appName: String?
    public let copiedAt: Date

    public init(id: UUID = UUID(), text: String, appName: String?, copiedAt: Date = Date()) {
        self.id = id
        self.text = text
        self.appName = appName
        self.copiedAt = copiedAt
    }
}

@MainActor
@Observable
public final class ClipboardService {
    public private(set) var entries: [ClipboardEntry] = []
    public private(set) var lastCopiedID: UUID?
    public private(set) var isWatching = false

    @ObservationIgnored private let pasteboard: NSPasteboard
    @ObservationIgnored private var lastChangeCount: Int
    @ObservationIgnored private var pollTimer: Timer?
    @ObservationIgnored private var feedbackTask: Task<Void, Never>?

    public init(pasteboard: NSPasteboard = .general) {
        self.pasteboard = pasteboard
        lastChangeCount = pasteboard.changeCount
    }

    public func start() {
        guard pollTimer == nil else { return }
        lastChangeCount = pasteboard.changeCount
        let timer = Timer(timeInterval: 0.7, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.poll() }
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
        entries.removeAll()
    }

    public func clear() {
        entries.removeAll()
    }

    public func copy(_ entry: ClipboardEntry) {
        pasteboard.clearContents()
        pasteboard.setString(entry.text, forType: .string)
        lastChangeCount = pasteboard.changeCount
        promote(entry.text, appName: entry.appName)
        lastCopiedID = entries.first?.id
        feedbackTask?.cancel()
        feedbackTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1.2))
            guard !Task.isCancelled else { return }
            self?.lastCopiedID = nil
        }
    }

    private func poll() {
        let count = pasteboard.changeCount
        guard count != lastChangeCount else { return }
        lastChangeCount = count
        let types = (pasteboard.types ?? []).map(\.rawValue)
        guard ClipboardRules.isRecordable(types: types),
              let text = pasteboard.string(forType: .string) else { return }
        promote(text, appName: NSWorkspace.shared.frontmostApplication?.localizedName)
    }

    private func promote(_ text: String, appName: String?) {
        let kept = text.count > ClipboardRules.maximumCharacters
            ? String(text.prefix(ClipboardRules.maximumCharacters))
            : text
        guard !kept.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        entries.removeAll { $0.text == kept }
        entries.insert(ClipboardEntry(text: kept, appName: appName), at: 0)
        if entries.count > ClipboardRules.capacity {
            entries.removeLast(entries.count - ClipboardRules.capacity)
        }
    }
}
