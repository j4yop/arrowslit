import Foundation
import Observation

@MainActor
@Observable
public final class SettingsStore {
    public var showMenuBarIcon: Bool { didSet { defaults.set(showMenuBarIcon, forKey: Key.menuBar) } }
    public var clipboardEnabled: Bool { didSet { defaults.set(clipboardEnabled, forKey: Key.clipboard) } }
    public var statsEnabled: Bool { didSet { defaults.set(statsEnabled, forKey: Key.stats) } }
    public var notesEnabled: Bool { didSet { defaults.set(notesEnabled, forKey: Key.notes) } }

    @ObservationIgnored private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        showMenuBarIcon = defaults.object(forKey: Key.menuBar) as? Bool ?? true
        clipboardEnabled = defaults.object(forKey: Key.clipboard) as? Bool ?? true
        statsEnabled = defaults.object(forKey: Key.stats) as? Bool ?? true
        notesEnabled = defaults.object(forKey: Key.notes) as? Bool ?? true
    }

    private enum Key {
        static let menuBar = "arrowslit.showMenuBarIcon"
        static let clipboard = "arrowslit.clipboardEnabled"
        static let stats = "arrowslit.statsEnabled"
        static let notes = "arrowslit.notesEnabled"
    }
}
