import Foundation
import Observation

@MainActor
@Observable
public final class NotesStore {
    public private(set) var text: String
    public private(set) var isSaved = true

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private var saveTask: Task<Void, Never>?
    private static let key = "arrowslit.notes.text"

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        text = defaults.string(forKey: Self.key) ?? ""
    }

    public var isEmpty: Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    public func setText(_ value: String) {
        guard value != text else { return }
        text = value
        isSaved = false
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            self?.save()
        }
    }

    public func save() {
        saveTask?.cancel()
        saveTask = nil
        defaults.set(text, forKey: Self.key)
        isSaved = true
    }

    public func clear() {
        text = ""
        save()
    }
}
