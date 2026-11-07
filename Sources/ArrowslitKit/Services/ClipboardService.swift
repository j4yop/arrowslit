import AppKit
import Foundation
import Observation

/// The history entry type used by the views. Pinned entries are the only ones written to disk.
public typealias ClipboardEntry = ClipboardHistory.Entry

@MainActor
@Observable
public final class ClipboardService {
    public private(set) var history = ClipboardHistory()
    public private(set) var lastCopiedID: UUID?
    public private(set) var isWatching = false

    public var entries: [ClipboardEntry] { history.entries }
    public var pinnedCount: Int { history.pinnedCount }
    public var canPin: Bool { history.canPin }

    @ObservationIgnored public var onCaptured: ((String) -> Void)?
    @ObservationIgnored private let pasteboard: NSPasteboard
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private var lastChangeCount: Int
    @ObservationIgnored private var pollTimer: Timer?
    @ObservationIgnored private var feedbackTask: Task<Void, Never>?
    @ObservationIgnored private var ignoreConfidential: Bool

    private static let pinsKey = "arrowslit.clipboard.pins"
    private static let capacityKey = "arrowslit.clipboard.capacity"
    private static let confidentialKey = "arrowslit.clipboard.ignoreConfidential"

    public init(pasteboard: NSPasteboard = .general, defaults: UserDefaults = .standard) {
        self.pasteboard = pasteboard
        self.defaults = defaults
        let capacity = defaults.object(forKey: Self.capacityKey) as? Int ?? ClipboardHistory.capacity
        self.ignoreConfidential = defaults.object(forKey: Self.confidentialKey) as? Bool ?? true
        lastChangeCount = pasteboard.changeCount
        history = ClipboardHistory(capacity: capacity)
        loadPins()
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
        history.removeAll(includingPinned: true)
    }

    /// Clears the history. Pinned clips stay.
    public func clear() {
        history.removeAll()
        savePins()
    }

    public func setCapacity(_ value: Int) {
        history.setCapacity(value)
        defaults.set(history.capacity, forKey: Self.capacityKey)
        savePins()
    }

    public func setIgnoreConfidential(_ value: Bool) {
        ignoreConfidential = value
        defaults.set(value, forKey: Self.confidentialKey)
    }

    public func togglePin(_ entry: ClipboardEntry) {
        if history.togglePin(entry.id) {
            savePins()
        }
    }

    public func matching(_ query: String) -> [ClipboardEntry] {
        history.matching(query)
    }

    public func remove(_ id: UUID) {
        history.remove(id)
        savePins()
    }

    public func copy(_ entry: ClipboardEntry) {
        pasteboard.clearContents()
        pasteboard.setString(entry.text, forType: .string)
        lastChangeCount = pasteboard.changeCount
        promote(entry.text, appName: entry.appName)
        lastCopiedID = entries.first(where: { $0.text == entry.text })?.id
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
        guard (!ignoreConfidential || ClipboardRules.isRecordable(types: types)),
              let text = pasteboard.string(forType: .string) else { return }
        promote(text, appName: NSWorkspace.shared.frontmostApplication?.localizedName)
    }

    /// Internal so the history/pin rules can be tested without a real pasteboard.
    func promote(_ text: String, appName: String?) {
        if history.add(text, appName: appName) {
            savePins()
            onCaptured?(text)
        }
    }

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
}
