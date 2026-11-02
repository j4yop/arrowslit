import Foundation
import Observation

@MainActor
@Observable
public final class SettingsStore {
    public var appearance: NotchAppearance {
        didSet {
            let clamped = appearance.clamped()
            if clamped != appearance {
                appearance = clamped
                return
            }
            defaults.set(clamped.width, forKey: Key.width)
            defaults.set(clamped.height, forKey: Key.height)
            defaults.set(clamped.pitchBlack, forKey: Key.pitchBlack)
            defaults.set(clamped.size.rawValue, forKey: Key.size)
            defaults.set(clamped.nookLayout.rawValue, forKey: Key.nookLayout)
            defaults.set(clamped.theme.rawValue, forKey: Key.theme)
            defaults.set(clamped.glassTint, forKey: Key.glassTint)
        }
    }
    public var showMenuBarIcon: Bool { didSet { defaults.set(showMenuBarIcon, forKey: Key.menuBar) } }
    public var displayChoice: DisplayChoice { didSet { defaults.set(displayChoice.rawValue, forKey: Key.display) } }
    public var openSettingsOnLaunch: Bool { didSet { defaults.set(openSettingsOnLaunch, forKey: Key.openSettingsOnLaunch) } }
    public var showWhenIdle: Bool { didSet { defaults.set(showWhenIdle, forKey: Key.showWhenIdle) } }
    public var openOnHover: Bool { didSet { defaults.set(openOnHover, forKey: Key.openOnHover) } }
    public var collapseOnLeave: Bool { didSet { defaults.set(collapseOnLeave, forKey: Key.collapseOnLeave) } }
    public var liquidAnimations: Bool { didSet { defaults.set(liquidAnimations, forKey: Key.liquidAnimations) } }
    public var hapticFeedback: Bool { didSet { defaults.set(hapticFeedback, forKey: Key.haptic) } }
    public var showOnLockScreen: Bool { didSet { defaults.set(showOnLockScreen, forKey: Key.showOnLockScreen) } }
    public var callsEnabled: Bool { didSet { defaults.set(callsEnabled, forKey: Key.calls) } }
    public var downloadsEnabled: Bool { didSet { defaults.set(downloadsEnabled, forKey: Key.downloads) } }
    public var nowPlayingAppMode: MediaAppFilter.Mode { didSet { defaults.set(nowPlayingAppMode.rawValue, forKey: Key.nowPlayingAppMode) } }
    public var nowPlayingApps: [String] { didSet { defaults.set(nowPlayingApps, forKey: Key.nowPlayingApps) } }
    public private(set) var recentMediaApps: RecentMediaApps { didSet { defaults.set(recentMediaApps.identifiers, forKey: Key.recentMediaApps) } }
    public var pausedMediaLinger: TimeInterval { didSet { defaults.set(pausedMediaLinger, forKey: Key.linger) } }
    public var shortcutsEnabled: Bool { didSet { defaults.set(shortcutsEnabled, forKey: Key.shortcutsEnabled) } }
    public var agentApprovals: Set<AgentKind> {
        didSet {
            defaults.set(AgentKind.allCases.filter(agentApprovals.contains).map(\.rawValue), forKey: Key.agentApprovals)
        }
    }
    public var favoriteShortcuts: [String] { didSet { defaults.set(favoriteShortcuts, forKey: Key.favoriteShortcuts) } }

    public var mediaAppFilter: MediaAppFilter {
        MediaAppFilter(mode: nowPlayingAppMode, allowed: Set(nowPlayingApps))
    }

    public static let lingerChoices: [TimeInterval] = [10, 30, 60, 300]
    public static let maximumFavoriteShortcuts = 4

    @discardableResult
    public func toggleFavorite(_ name: String) -> Bool {
        if let index = favoriteShortcuts.firstIndex(of: name) {
            favoriteShortcuts.remove(at: index)
            return true
        }
        guard favoriteShortcuts.count < Self.maximumFavoriteShortcuts else { return false }
        favoriteShortcuts.append(name)
        return true
    }

    public func noteMediaApp(_ identifier: String) {
        var recent = recentMediaApps
        if recent.note(identifier) { recentMediaApps = recent }
    }

    public func setNowPlaying(_ identifier: String, allowed: Bool) {
        if allowed {
            guard !identifier.isEmpty, !nowPlayingApps.contains(identifier) else { return }
            nowPlayingApps.append(identifier)
        } else {
            nowPlayingApps.removeAll { $0 == identifier }
        }
    }

    public func forgetMediaApp(_ identifier: String) {
        setNowPlaying(identifier, allowed: false)
        var recent = recentMediaApps
        recent.remove(identifier)
        if recent != recentMediaApps { recentMediaApps = recent }
    }
    public var alertCharging: Bool { didSet { defaults.set(alertCharging, forKey: Key.alertCharging) } }
    public var alertLowBattery: Bool { didSet { defaults.set(alertLowBattery, forKey: Key.alertLowBattery) } }
    public var alertHeadphones: Bool { didSet { defaults.set(alertHeadphones, forKey: Key.alertHeadphones) } }
    public var alertVolumeBrightness: Bool { didSet { defaults.set(alertVolumeBrightness, forKey: Key.alertVolumeBrightness) } }
    public var timerSound: Bool { didSet { defaults.set(timerSound, forKey: Key.timerSound) } }
    public var clipboardEnabled: Bool { didSet { defaults.set(clipboardEnabled, forKey: Key.clipboard) } }
    public var statsEnabled: Bool { didSet { defaults.set(statsEnabled, forKey: Key.stats) } }
    public var notesEnabled: Bool { didSet { defaults.set(notesEnabled, forKey: Key.notes) } }
    public var lyricsEnabled: Bool { didSet { defaults.set(lyricsEnabled, forKey: Key.lyrics) } }
    public var checksForUpdates: Bool { didSet { defaults.set(checksForUpdates, forKey: Key.checksForUpdates) } }
    public var sportsPreview: Bool { didSet { defaults.set(sportsPreview, forKey: Key.sportsPreview) } }
    public var sportsRefreshSeconds: Int { didSet { defaults.set(sportsRefreshSeconds, forKey: Key.sportsRefreshSeconds) } }
    public var sportsShowInNotch: Bool { didSet { defaults.set(sportsShowInNotch, forKey: Key.sportsShowInNotch) } }
    public var sportsGoalAlerts: Bool { didSet { defaults.set(sportsGoalAlerts, forKey: Key.sportsGoalAlerts) } }
    public var sportsCompetitionIDs: [String] { didSet { defaults.set(sportsCompetitionIDs, forKey: Key.sportsCompetitions) } }
    public var sportsFollowedTeams: [String] { didSet { defaults.set(sportsFollowedTeams, forKey: Key.sportsFollowedTeams) } }
    public var sportsPinnedMatchID: String? { didSet { defaults.set(sportsPinnedMatchID, forKey: Key.sportsPinnedMatch) } }
    public var enabledTabs: Set<String> { didSet { defaults.set(Array(enabledTabs).sorted(), forKey: Key.tabs) } }
    public var shortcutTabs: [String] { didSet { defaults.set(shortcutTabs, forKey: Key.shortcuts) } }
    public static let shortcutLimit = 3

    @ObservationIgnored private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        appearance = NotchAppearance(
            width: defaults.object(forKey: Key.width) as? Double ?? NotchAppearance.standard.width,
            height: defaults.object(forKey: Key.height) as? Double ?? NotchAppearance.standard.height,
            pitchBlack: defaults.object(forKey: Key.pitchBlack) as? Bool ?? NotchAppearance.standard.pitchBlack,
            size: defaults.string(forKey: Key.size).flatMap(NotchSize.init(rawValue:)) ?? NotchAppearance.standard.size,
            nookLayout: defaults.string(forKey: Key.nookLayout).flatMap(NookLayout.init(rawValue:)) ?? NotchAppearance.standard.nookLayout,
            theme: defaults.string(forKey: Key.theme).flatMap(NotchTheme.init(rawValue:)) ?? NotchAppearance.standard.theme,
            glassTint: defaults.object(forKey: Key.glassTint) as? Double ?? NotchAppearance.standard.glassTint
        ).clamped()
        showMenuBarIcon = defaults.object(forKey: Key.menuBar) as? Bool ?? true
        displayChoice = defaults.string(forKey: Key.display).flatMap(DisplayChoice.init(rawValue:)) ?? .automatic
        openSettingsOnLaunch = defaults.object(forKey: Key.openSettingsOnLaunch) as? Bool ?? true
        showWhenIdle = defaults.object(forKey: Key.showWhenIdle) as? Bool ?? false
        openOnHover = defaults.object(forKey: Key.openOnHover) as? Bool ?? true
        collapseOnLeave = defaults.object(forKey: Key.collapseOnLeave) as? Bool ?? true
        liquidAnimations = defaults.object(forKey: Key.liquidAnimations) as? Bool ?? true
        hapticFeedback = defaults.object(forKey: Key.haptic) as? Bool ?? true
        showOnLockScreen = defaults.object(forKey: Key.showOnLockScreen) as? Bool ?? false
        callsEnabled = defaults.object(forKey: Key.calls) as? Bool ?? true
        downloadsEnabled = defaults.object(forKey: Key.downloads) as? Bool ?? false
        nowPlayingAppMode = defaults.string(forKey: Key.nowPlayingAppMode).flatMap(MediaAppFilter.Mode.init(rawValue:)) ?? .all
        var seenApps = Set<String>()
        nowPlayingApps = (defaults.stringArray(forKey: Key.nowPlayingApps) ?? [])
            .filter { !$0.isEmpty && seenApps.insert($0).inserted }
        recentMediaApps = RecentMediaApps(defaults.stringArray(forKey: Key.recentMediaApps) ?? [])
        let linger = defaults.object(forKey: Key.linger) as? Double ?? 30
        pausedMediaLinger = Self.lingerChoices.contains(linger) ? linger : 30
        shortcutsEnabled = defaults.object(forKey: Key.shortcutsEnabled) as? Bool ?? true
        agentApprovals = Set((defaults.stringArray(forKey: Key.agentApprovals) ?? []).compactMap(AgentKind.init(rawValue:)))
        favoriteShortcuts = Array((defaults.stringArray(forKey: Key.favoriteShortcuts) ?? []).prefix(Self.maximumFavoriteShortcuts))
        alertCharging = defaults.object(forKey: Key.alertCharging) as? Bool ?? true
        alertLowBattery = defaults.object(forKey: Key.alertLowBattery) as? Bool ?? true
        alertHeadphones = defaults.object(forKey: Key.alertHeadphones) as? Bool ?? true
        alertVolumeBrightness = defaults.object(forKey: Key.alertVolumeBrightness) as? Bool ?? true
        timerSound = defaults.object(forKey: Key.timerSound) as? Bool ?? true
        clipboardEnabled = defaults.object(forKey: Key.clipboard) as? Bool ?? true
        statsEnabled = defaults.object(forKey: Key.stats) as? Bool ?? true
        notesEnabled = defaults.object(forKey: Key.notes) as? Bool ?? true
        lyricsEnabled = defaults.object(forKey: Key.lyrics) as? Bool ?? false
        checksForUpdates = defaults.object(forKey: Key.checksForUpdates) as? Bool ?? true
        sportsPreview = defaults.object(forKey: Key.sportsPreview) as? Bool ?? true
        sportsRefreshSeconds = defaults.object(forKey: Key.sportsRefreshSeconds) as? Int ?? 60
        sportsShowInNotch = defaults.object(forKey: Key.sportsShowInNotch) as? Bool ?? true
        sportsGoalAlerts = defaults.object(forKey: Key.sportsGoalAlerts) as? Bool ?? true
        let validCompetitions = Set(SportsCatalog.all.map(\.id))
        let savedCompetitions = (defaults.stringArray(forKey: Key.sportsCompetitions) ?? [])
            .filter { validCompetitions.contains($0) }
        sportsCompetitionIDs = savedCompetitions.isEmpty ? SportsCatalog.featuredIDs : savedCompetitions
        sportsFollowedTeams = defaults.stringArray(forKey: Key.sportsFollowedTeams) ?? []
        sportsPinnedMatchID = defaults.string(forKey: Key.sportsPinnedMatch)
        let defaultTabs = WorkbenchTab.allCases.filter { $0 != .sports }.map(\.rawValue)
        enabledTabs = Set(defaults.stringArray(forKey: Key.tabs) ?? defaultTabs)
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
        // Sports ships on so it is visible in the launcher, but it stays in
        // local preview mode until a BigBallsData key is connected.
        if !defaults.bool(forKey: Key.sportsDefaultAdded) {
            enabledTabs.insert(WorkbenchTab.sports.rawValue)
            defaults.set(true, forKey: Key.sportsDefaultAdded)
        }
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

    public func resetAppearance() {
        appearance = .standard
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
        static let width = "arrowslit.appearance.width"
        static let height = "arrowslit.appearance.height"
        static let pitchBlack = "arrowslit.appearance.pitchBlack"
        static let size = "arrowslit.appearance.size"
        static let nookLayout = "arrowslit.appearance.nookLayout"
        static let theme = "arrowslit.appearance.theme"
        static let glassTint = "arrowslit.appearance.glassTint"
        static let menuBar = "arrowslit.showMenuBarIcon"
        static let display = "arrowslit.display"
        static let openSettingsOnLaunch = "arrowslit.openSettingsOnLaunch"
        static let showWhenIdle = "arrowslit.showWhenIdle"
        static let openOnHover = "arrowslit.openOnHover"
        static let collapseOnLeave = "arrowslit.collapseOnLeave"
        static let liquidAnimations = "arrowslit.liquidAnimations"
        static let haptic = "arrowslit.hapticFeedback"
        static let showOnLockScreen = "arrowslit.showOnLockScreen"
        static let calls = "arrowslit.callsEnabled"
        static let downloads = "arrowslit.downloadsEnabled"
        static let nowPlayingAppMode = "arrowslit.nowPlaying.appMode"
        static let nowPlayingApps = "arrowslit.nowPlaying.apps"
        static let recentMediaApps = "arrowslit.nowPlaying.recentApps"
        static let linger = "arrowslit.nowPlaying.pausedLinger"
        static let shortcutsEnabled = "arrowslit.shortcutsEnabled"
        static let agentApprovals = "arrowslit.agentApprovals"
        static let favoriteShortcuts = "arrowslit.favoriteShortcuts"
        static let alertCharging = "arrowslit.alertCharging"
        static let alertLowBattery = "arrowslit.alertLowBattery"
        static let alertHeadphones = "arrowslit.alertHeadphones"
        static let alertVolumeBrightness = "arrowslit.alertVolumeBrightness"
        static let timerSound = "arrowslit.timerSound"
        static let clipboard = "arrowslit.clipboardEnabled"
        static let stats = "arrowslit.statsEnabled"
        static let notes = "arrowslit.notesEnabled"
        static let lyrics = "arrowslit.lyricsEnabled"
        static let checksForUpdates = "arrowslit.checksForUpdates"
        static let sportsDefaultAdded = "arrowslit.sports.defaultAdded"
        static let sportsPreview = "arrowslit.sports.preview"
        static let sportsRefreshSeconds = "arrowslit.sports.refreshSeconds"
        static let sportsShowInNotch = "arrowslit.sports.showInNotch"
        static let sportsGoalAlerts = "arrowslit.sports.goalAlerts"
        static let sportsCompetitions = "arrowslit.sports.competitions"
        static let sportsFollowedTeams = "arrowslit.sports.followedTeams"
        static let sportsPinnedMatch = "arrowslit.sports.pinnedMatch"
        static let tabs = "arrowslit.enabledTabs"
        static let shortcuts = "arrowslit.shortcutTabs"
    }
}
