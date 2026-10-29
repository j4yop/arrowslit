import Foundation
import Observation

@MainActor
@Observable
public final class SettingsStore {
    public var showMenuBarIcon: Bool { didSet { defaults.set(showMenuBarIcon, forKey: Key.menuBar) } }
    public var openOnHover: Bool { didSet { defaults.set(openOnHover, forKey: Key.openOnHover) } }
    public var collapseOnLeave: Bool { didSet { defaults.set(collapseOnLeave, forKey: Key.collapseOnLeave) } }
    public var hapticFeedback: Bool { didSet { defaults.set(hapticFeedback, forKey: Key.haptic) } }
    public var clipboardEnabled: Bool { didSet { defaults.set(clipboardEnabled, forKey: Key.clipboard) } }
    public var statsEnabled: Bool { didSet { defaults.set(statsEnabled, forKey: Key.stats) } }
    public var notesEnabled: Bool { didSet { defaults.set(notesEnabled, forKey: Key.notes) } }
    public var enabledTabs: Set<String> { didSet { defaults.set(Array(enabledTabs).sorted(), forKey: Key.tabs) } }
    public var shortcutTabs: [String] { didSet { defaults.set(shortcutTabs, forKey: Key.shortcuts) } }
    public static let shortcutLimit = 3

    @ObservationIgnored private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        showMenuBarIcon = defaults.object(forKey: Key.menuBar) as? Bool ?? true
        openOnHover = defaults.object(forKey: Key.openOnHover) as? Bool ?? true
        collapseOnLeave = defaults.object(forKey: Key.collapseOnLeave) as? Bool ?? true
        hapticFeedback = defaults.object(forKey: Key.haptic) as? Bool ?? true
        clipboardEnabled = defaults.object(forKey: Key.clipboard) as? Bool ?? true
        statsEnabled = defaults.object(forKey: Key.stats) as? Bool ?? true
        notesEnabled = defaults.object(forKey: Key.notes) as? Bool ?? true
        enabledTabs = Set(defaults.stringArray(forKey: Key.tabs) ?? WorkbenchTab.allCases.map(\.rawValue))
        let defaultsShortcuts = [WorkbenchTab.tray.rawValue, WorkbenchTab.clipboard.rawValue]
        let valid = Set(WorkbenchTab.allCases.map(\.rawValue))
        var seen = Set<String>()
        shortcutTabs = Array(
            (defaults.stringArray(forKey: Key.shortcuts) ?? defaultsShortcuts)
                .filter { valid.contains($0) && $0 != WorkbenchTab.home.rawValue && $0 != WorkbenchTab.launcher.rawValue }
                .filter { seen.insert($0).inserted }
                .prefix(Self.shortcutLimit)
        )
        if !clipboardEnabled { enabledTabs.remove(WorkbenchTab.clipboard.rawValue) }
        if !notesEnabled { enabledTabs.remove(WorkbenchTab.notes.rawValue) }
        if !statsEnabled { enabledTabs.remove(WorkbenchTab.stats.rawValue) }
    }

    public func isTabEnabled(_ tab: WorkbenchTab) -> Bool {
        tab == .home || tab == .launcher || enabledTabs.contains(tab.rawValue)
    }

    public func isShortcut(_ tab: WorkbenchTab) -> Bool {
        shortcutTabs.contains(tab.rawValue)
    }

    @discardableResult
    public func toggleShortcut(_ tab: WorkbenchTab) -> Bool {
        guard tab != .home, tab != .launcher else { return false }
        if let index = shortcutTabs.firstIndex(of: tab.rawValue) {
            shortcutTabs.remove(at: index)
            return true
        }
        guard shortcutTabs.count < Self.shortcutLimit else { return false }
        shortcutTabs.append(tab.rawValue)
        return true
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
        static let openOnHover = "arrowslit.openOnHover"
        static let collapseOnLeave = "arrowslit.collapseOnLeave"
        static let haptic = "arrowslit.hapticFeedback"
        static let clipboard = "arrowslit.clipboardEnabled"
        static let stats = "arrowslit.statsEnabled"
        static let notes = "arrowslit.notesEnabled"
        static let tabs = "arrowslit.enabledTabs"
        static let shortcuts = "arrowslit.shortcutTabs"
    }
}
