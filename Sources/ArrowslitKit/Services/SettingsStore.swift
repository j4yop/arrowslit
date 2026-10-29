import Foundation
import Observation

@MainActor
@Observable
public final class SettingsStore {
    public var showMenuBarIcon: Bool { didSet { defaults.set(showMenuBarIcon, forKey: Key.menuBar) } }
    public var clipboardEnabled: Bool { didSet { defaults.set(clipboardEnabled, forKey: Key.clipboard) } }
    public var statsEnabled: Bool { didSet { defaults.set(statsEnabled, forKey: Key.stats) } }
    public var notesEnabled: Bool { didSet { defaults.set(notesEnabled, forKey: Key.notes) } }
    public var enabledTabs: Set<String> { didSet { defaults.set(Array(enabledTabs).sorted(), forKey: Key.tabs) } }

    @ObservationIgnored private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        showMenuBarIcon = defaults.object(forKey: Key.menuBar) as? Bool ?? true
        clipboardEnabled = defaults.object(forKey: Key.clipboard) as? Bool ?? true
        statsEnabled = defaults.object(forKey: Key.stats) as? Bool ?? true
        notesEnabled = defaults.object(forKey: Key.notes) as? Bool ?? true
        enabledTabs = Set(defaults.stringArray(forKey: Key.tabs) ?? WorkbenchTab.allCases.map(\.rawValue))
        if !clipboardEnabled { enabledTabs.remove(WorkbenchTab.clipboard.rawValue) }
        if !notesEnabled { enabledTabs.remove(WorkbenchTab.notes.rawValue) }
        if !statsEnabled { enabledTabs.remove(WorkbenchTab.stats.rawValue) }
    }

    public func isTabEnabled(_ tab: WorkbenchTab) -> Bool {
        tab == .home || tab == .launcher || enabledTabs.contains(tab.rawValue)
    }

    public func setTabEnabled(_ tab: WorkbenchTab, _ enabled: Bool) {
        guard tab != .home, tab != .launcher else { return }
        if enabled {
            enabledTabs.insert(tab.rawValue)
        } else {
            enabledTabs.remove(tab.rawValue)
        }
    }

    private enum Key {
        static let menuBar = "arrowslit.showMenuBarIcon"
        static let clipboard = "arrowslit.clipboardEnabled"
        static let stats = "arrowslit.statsEnabled"
        static let notes = "arrowslit.notesEnabled"
        static let tabs = "arrowslit.enabledTabs"
    }
}
