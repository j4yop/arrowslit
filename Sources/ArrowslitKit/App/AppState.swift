import AppKit
import Combine
import Foundation
import Observation

public enum WorkbenchTab: String, CaseIterable, Identifiable, Sendable {
    case home
    case call
    case nowPlaying
    case download
    case timer
    case calendar
    case tray
    case mirror
    case clipboard
    case notes
    case stats
    case sports
    case reminders
    case agents
    case stopwatch
    case keepAwake
    case launcher

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .home: "Home"
        case .call: "Call"
        case .nowPlaying: "Now Playing"
        case .download: "Downloads"
        case .timer: "Timer"
        case .calendar: "Calendar"
        case .tray: "Files"
        case .mirror: "Camera Mirror"
        case .clipboard: "Clipboard"
        case .notes: "Scratchpad"
        case .stats: "Stats"
        case .sports: "Sports"
        case .reminders: "Reminders"
        case .agents: "AI Agents"
        case .stopwatch: "Stopwatch"
        case .keepAwake: "Keep Awake"
        case .launcher: "All Features"
        }
    }

    public var symbol: String {
        switch self {
        case .home: "house"
        case .call: "phone"
        case .nowPlaying: "music.note"
        case .download: "arrow.down.circle"
        case .timer: "timer"
        case .calendar: "calendar"
        case .tray: "tray.full"
        case .mirror: "web.camera"
        case .clipboard: "doc.on.clipboard"
        case .notes: "note.text"
        case .stats: "gauge.with.dots.needle.33percent"
        case .sports: "soccerball"
        case .reminders: "checklist"
        case .agents: "sparkles"
        case .stopwatch: "stopwatch"
        case .keepAwake: "cup.and.saucer"
        case .launcher: "square.grid.2x2"
        }
    }

    /// The letter pressed with Control and Option for the launcher and Home shortcuts.
    /// Sports uses F (football); the rest follow DynamicLedge's chosen keys.
    public var shortcutKey: Character? {
        switch self {
        case .nowPlaying: "M"
        case .timer: "R"
        case .stopwatch: "S"
        case .calendar: "A"
        case .sports: "F"
        case .reminders: "O"
        case .agents: "G"
        case .clipboard: "B"
        case .tray: "L"
        case .notes: "N"
        case .mirror: "W"
        case .keepAwake: "Z"
        case .stats: "P"
        case .home, .launcher, .call, .download: nil
        }
    }

    public var shortcutLabel: String? {
        shortcutKey.map { "⌃⌥\($0)" }
    }

    /// Tabs that live in the top strip beside the camera.
    public var isPrimaryTab: Bool {
        self == .home || self == .tray || self == .clipboard
    }

    public var isSecondaryTab: Bool {
        self == .notes || self == .mirror
    }
}

@MainActor
@Observable
public final class AppState {
    public let settings: SettingsStore
    public let calls = CallMonitor()
    public let microphone = MicrophoneMute()
    public let downloads = DownloadsWatcher()
    public let downloadProgress = DownloadProgressMonitor()
    public let todos = TodoStore()
    public let shortcuts = ShortcutsService()
    public let agents = AgentBridge()
    @ObservationIgnored private var agentLiveObservation: AnyCancellable?
    /// Keeps the compact notch observing live agent sessions without making
    /// every caller subscribe to the reader's full snapshot.
    public private(set) var agentLiveCount = 0
    public let nowPlaying: NowPlayingService
    public let timer: TimerService
    public let calendar: CalendarService
    public let tray: TrayStore
    public let camera = CameraAccess()
    public let clipboard: ClipboardService
    public let notes: NotesStore
    public let stats: StatsService
    public let sports: SportsService
    public let reminders: RemindersService
    public let system: SystemMonitorService
    public let session = SessionLockService()
    public let lyrics = LyricsService()
    public let updater = UpdateService()
    public let stopwatch = StopwatchService()
    public let keepAwake = KeepAwakeService()
    public let hotKeys = HotKeys()

    public private(set) var activeTab: WorkbenchTab = .home
    public var clockMode: ClockMode = .timer
    public private(set) var isExpanded = false
    public private(set) var isHoveringNotch = false
    /// Clipboard's search field is open, so the notch takes the keyboard.
    public var isSearchingClipboard = false
    /// A text field in Notes or the elongated Home has the keyboard.
    public var isTypingInNook = false
    /// After a deliberate close, do not reopen from hover until the pointer leaves the notch.
    public private(set) var suppressHoverUntilLeave = false
    public private(set) var alerts = AlertQueue()
    public var isEditingShortcuts = false

    @ObservationIgnored public var onOpenSettings: (() -> Void)?
    @ObservationIgnored private var alertTask: Task<Void, Never>?

    public init(
        settings: SettingsStore = SettingsStore(),
        nowPlaying: NowPlayingService = NowPlayingService(),
        timer: TimerService = TimerService(),
        calendar: CalendarService = CalendarService(),
        tray: TrayStore = TrayStore(),
        clipboard: ClipboardService = ClipboardService(),
        notes: NotesStore = NotesStore(),
        stats: StatsService = StatsService(),
        sports: SportsService? = nil,
        reminders: RemindersService = RemindersService()
    ) {
        self.settings = settings
        self.nowPlaying = nowPlaying
        self.timer = timer
        self.calendar = calendar
        self.tray = tray
        self.clipboard = clipboard
        self.notes = notes
        self.stats = stats
        self.sports = sports ?? SportsService(settings: settings)
        self.reminders = reminders
        self.system = SystemMonitorService(settings: settings)
        self.timer.playsSound = settings.timerSound
        NookMotion.liquidAnimations = settings.liquidAnimations
        nowPlaying.appFilter = settings.mediaAppFilter
        nowPlaying.lingerDuration = settings.pausedMediaLinger
        nowPlaying.onAppSeen = { [weak settings] identifier in
            settings?.noteMediaApp(identifier)
        }

        calendar.onReminder = { [weak self] event in
            guard let self, self.settings.isTabEnabled(.calendar) else { return }
            self.receive(.upcomingEvent(
                title: event.title,
                startsAt: event.start,
                joinURL: event.joinURL,
                provider: event.joinProvider
            ))
        }
        self.sports.onGoal = { [weak self] goal in
            guard let self, self.settings.sportsGoalAlerts else { return }
            self.receive(.sportsGoal(goal))
        }
        calls.onChange = { [weak self] in
            guard let self else { return }
            if self.calls.session == nil, self.isExpanded, self.activeTab == .call {
                self.collapse()
            }
        }
        downloads.onFinished = { [weak self] url in
            guard let self, self.settings.downloadsEnabled else { return }
            self.receive(.download(name: url.lastPathComponent))
        }
        shortcuts.onFinish = { [weak self] name, succeeded in
            self?.receive(.shortcut(name: name, succeeded: succeeded))
        }
        agents.onChange = { [weak self] in self?.syncAgentAlert() }
        hotKeys.onPress = { [weak self] tab in self?.openShortcut(tab) }
    }

    public func start() {
        session.start()
        system.onAlert = { [weak self] alert in
            guard let self else { return }
            if self.session.isLocked, !self.settings.showOnLockScreen { return }
            if alert.isInstant, self.isExpanded { return }
            self.receive(alert)
        }
        system.start()
        if settings.statsEnabled { stats.start() }
        nowPlaying.start()
        if settings.callsEnabled {
            calls.start()
            microphone.start()
        }
        if settings.downloadsEnabled {
            downloads.start()
            downloadProgress.start()
        }
        if settings.keyboardShortcutsEnabled { hotKeys.register() }
        agents.enabledKinds = settings.agentApprovals
        if !settings.agentApprovals.isEmpty {
            agents.start()
        }
        calendar.start()
        sports.startAppAlerts()
        if settings.clipboardEnabled { clipboard.start() }
        updater.onAvailable = { [weak self] release in
            guard let self else { return false }
            return self.receive(.update(version: release.version.description))
        }
        if settings.checksForUpdates { updater.startAutomaticChecks() }
        AgentUsageService.shared.syncWithPreferences()
        agentLiveObservation = AgentUsageService.shared.$snapshot
            .map { $0.live.count }
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] count in self?.agentLiveCount = count }
    }

    public func stop() {
        agentLiveObservation?.cancel()
        agentLiveObservation = nil
        notes.save()
        tray.clearUnpinned()
        nowPlaying.stop()
        calls.stop()
        microphone.stop()
        downloads.stop()
        downloadProgress.stop()
        agents.stop()
        hotKeys.unregister()
        calendar.stop()
        clipboard.stop()
        stats.stop()
        sports.stop()
        timer.reset()
        updater.onAvailable = nil
        updater.stop()
        system.onAlert = nil
        system.stop()
        session.stop()
        alertTask?.cancel()
        alertTask = nil
        alerts = AlertQueue()
    }

    public func expand(_ tab: WorkbenchTab = .timer) {
        if isExpanded, activeTab == tab { return }
        alertTask?.cancel()
        alertTask = nil
        alerts.dismissCurrent()
        let wasCollapsed = !isExpanded
        isExpanded = true
        suppressHoverUntilLeave = false
        select(tab)
        if wasCollapsed, settings.hapticFeedback {
            NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
        }
    }

    public func collapse() {
        guard isExpanded else { return }
        isExpanded = false
        suppressHoverUntilLeave = true
        isEditingShortcuts = false
        if !settings.statsEnabled { stats.stop() }
        sports.closePane()
        notes.save()
        pumpAlerts()
    }

    /// A click outside the notch closes an alert first, then the workbench.
    public func outsideClick() {
        if alerts.current != nil {
            dismissAlert()
        } else {
            collapse()
        }
    }

    public func toggle() {
        if isExpanded { collapse() } else { expandDefault() }
    }

    /// What opening the notch should show when the user hasn't picked a tab.
    /// Media takes precedence; everything else falls back to Home.
    public var defaultTab: WorkbenchTab {
        if calls.session != nil { return .call }
        if timer.isActive { return .timer }
        if stopwatch.isActive { return .stopwatch }
        if settings.isTabEnabled(.nowPlaying), nowPlaying.isVisible {
            return .nowPlaying
        }
        if !downloadProgress.items.isEmpty {
            return .download
        }
        return .home
    }

    public func expandDefault() {
        expand(defaultTab)
    }

    /// A ⌃⌥ shortcut from the launcher. Keep Awake and Stats are switches, like their tiles;
    /// everything else opens the feature.
    public func openShortcut(_ tab: WorkbenchTab) {
        switch tab {
        case .nowPlaying:
            expand(nowPlaying.isVisible ? .nowPlaying : .home)
        case .keepAwake:
            keepAwake.toggle()
            NookHaptics.perform(enabled: settings.hapticFeedback)
        case .stats:
            settings.statsEnabled.toggle()
            if settings.statsEnabled { stats.start() } else { stats.stop() }
            NookHaptics.perform(enabled: settings.hapticFeedback)
        default:
            expand(tab)
        }
    }

    /// Installs or removes an assistant's hook, then updates the live bridge. Returns an error
    /// message for the Settings row, or nil on success.
    public func setAgentApproval(_ kind: AgentKind, enabled: Bool) -> String? {
        do {
            if enabled {
                if kind == .opencode {
                    try AgentHookSettings.installOpenCode(socket: agents.socketPath)
                } else {
                    guard let command = AgentHookSettings.currentCommand(socket: agents.socketPath, kind: kind) else {
                        return "Couldn't locate this copy of Arrowslit."
                    }
                    try AgentHookSettings.install(kind, command: command)
                }
                settings.agentApprovals.insert(kind)
                agents.enabledKinds = settings.agentApprovals
                agents.start()
            } else {
                try AgentHookSettings.uninstall(kind)
                settings.agentApprovals.remove(kind)
                agents.enabledKinds = settings.agentApprovals
                if settings.agentApprovals.isEmpty { agents.stop() }
            }
            return nil
        } catch AgentHookSettings.Failure.unreadable {
            return "Couldn't read \(AgentHookSettings.displayPath(for: kind)). Check that it's valid JSON."
        } catch {
            return "Couldn't save \(AgentHookSettings.displayPath(for: kind))."
        }
    }

    public func answerAgent(_ decision: AgentDecision) {
        guard case .agentRequest(let request) = currentAlert else { return }
        agents.answer(request.id, decision)
        syncAgentAlert()
    }

    private func syncAgentAlert() {
        if let request = agents.pending.first {
            if case .agentRequest(let current) = currentAlert, current.id == request.id { return }
            receive(.agentRequest(request))
        } else if case .agentRequest = currentAlert {
            dismissAlert()
        }
    }

    public func setMediaAppMode(_ mode: MediaAppFilter.Mode) {
        settings.nowPlayingAppMode = mode
        nowPlaying.appFilter = settings.mediaAppFilter
    }

    public func setMediaApp(_ identifier: String, allowed: Bool) {
        settings.setNowPlaying(identifier, allowed: allowed)
        nowPlaying.appFilter = settings.mediaAppFilter
    }

    public func forgetMediaApp(_ identifier: String) {
        settings.forgetMediaApp(identifier)
        nowPlaying.appFilter = settings.mediaAppFilter
    }

    public func setPausedMediaLinger(_ seconds: TimeInterval) {
        settings.pausedMediaLinger = seconds
        nowPlaying.lingerDuration = seconds
    }

    public func setDownloadsEnabled(_ enabled: Bool) {
        settings.downloadsEnabled = enabled
        if enabled {
            downloads.start()
            downloadProgress.start()
        } else {
            downloads.stop()
            downloadProgress.stop()
        }
    }

    public func setCallsEnabled(_ enabled: Bool) {
        settings.callsEnabled = enabled
        if enabled {
            calls.start()
            microphone.start()
        } else {
            calls.stop()
            microphone.stop()
        }
    }

    public func setClockMode(_ mode: ClockMode) {
        clockMode = mode
        select(mode == .stopwatch ? .stopwatch : .timer)
    }

    public func select(_ tab: WorkbenchTab) {
        activeTab = tab
        if tab != .launcher { isEditingShortcuts = false }
        if tab == .stats, isExpanded {
            stats.start()
        } else if !settings.statsEnabled {
            stats.stop()
        }
        if tab == .sports, isExpanded {
            sports.openPane()
        } else {
            sports.closePane()
        }
    }

    public func startTimer(minutes: Int) {
        clockMode = .timer
        timer.start(minutes: minutes)
        collapse()
    }

    public func startFocus() {
        clockMode = .focus
        timer.startFocus(minutes: timer.focusMinutes)
        collapse()
    }

    public func startBreak() {
        clockMode = .focus
        timer.startBreak(minutes: timer.breakMinutes)
        collapse()
    }

    public func toggleTimer() {
        timer.togglePause()
    }

    public func resetTimer() {
        timer.reset()
    }

    public func setClipboardEnabled(_ enabled: Bool) {
        setTabEnabled(.clipboard, enabled)
    }

    public func setStatsEnabled(_ enabled: Bool) {
        setTabEnabled(.stats, enabled)
    }

    public func setNotesEnabled(_ enabled: Bool) {
        setTabEnabled(.notes, enabled)
    }

    public func setMenuBarIconVisible(_ visible: Bool) {
        settings.showMenuBarIcon = visible
    }

    public func setChecksForUpdates(_ enabled: Bool) {
        settings.checksForUpdates = enabled
        if enabled { updater.startAutomaticChecks() } else { updater.stop() }
    }

    public func setKeyboardShortcuts(_ enabled: Bool) {
        settings.keyboardShortcutsEnabled = enabled
        if enabled { hotKeys.register() } else { hotKeys.unregister() }
    }

    public func setLiquidAnimations(_ enabled: Bool) {
        settings.liquidAnimations = enabled
        NookMotion.liquidAnimations = enabled
    }

    public func setTimerSound(_ enabled: Bool) {
        settings.timerSound = enabled
        timer.playsSound = enabled
    }

    public func setSportsGoalAlerts(_ enabled: Bool) {
        settings.sportsGoalAlerts = enabled
        sports.goalAlertsChanged()
    }

    @discardableResult
    public func toggleShortcut(_ tab: WorkbenchTab) -> Bool {
        settings.toggleShortcut(tab)
    }

    public func setTabEnabled(_ tab: WorkbenchTab, _ enabled: Bool) {
        settings.setTabEnabled(tab, enabled)
        switch tab {
        case .clipboard:
            settings.clipboardEnabled = enabled
            if enabled { clipboard.start() } else { clipboard.stop() }
        case .notes:
            settings.notesEnabled = enabled
        case .stats:
            settings.statsEnabled = enabled
            if enabled { stats.start() } else { stats.stop() }
        case .sports:
            if !enabled { sports.stop() }
            if enabled { sports.startAppAlerts() }
            if enabled, activeTab == .sports, isExpanded { sports.openPane() }
        default:
            break
        }
        if !enabled, activeTab == tab { select(.home) }
    }

    /// What the notch should show right now.
    public var presentation: NotchPresentation {
        PresentationResolver.resolve(PresentationInput(
            isExpanded: isExpanded,
            activeTab: activeTab,
            activeActivities: activeActivities,
            preferredPrimary: nil,
            alert: alerts.current,
            showWhenIdle: settings.showWhenIdle,
            isHoveringNotch: isHoveringNotch
        ))
    }

    /// What a mirror panel shows while content is open elsewhere. Alerts still appear on every
    /// screen; only opened content stays on the active one.
    public var mirrorPresentation: NotchPresentation {
        // Mirror exactly what the active panel is showing when it is an alert or HUD, so the
        // same alert appears on every screen. Opened content stays on the active screen.
        if case .alert = presentation { return presentation }
        if case .hud = presentation { return presentation }
        let ordered = PresentationResolver.ordered(activeActivities, preferred: nil)
        if let primary = ordered.first {
            return .compact(primary: primary, secondary: ordered.dropFirst().first)
        }
        return settings.showWhenIdle ? .idle : .hidden(peek: false)
    }

    /// Set by the panel's pointer poller. Only changes on a real transition, so the hidden
    /// notch does not redraw on every mouse move.
    public func setHoveringNotch(_ hovering: Bool) {
        guard isHoveringNotch != hovering else { return }
        isHoveringNotch = hovering
    }

    public func clearHoverSuppression() {
        guard suppressHoverUntilLeave else { return }
        suppressHoverUntilLeave = false
    }

    /// The window size for a presentation. The compact strip, the player and the launcher
    /// already use the DynamicLedge 1.4.2 size contract; the remaining panels keep their
    /// Arrowslit sizes until their views are ported in the Home/alert tickets.
    public func panelSize(for presentation: NotchPresentation) -> CGSize {
        panelSize(for: presentation, geometry: ScreenReader.current)
    }

    public func panelSize(for presentation: NotchPresentation, geometry: ScreenGeometry) -> CGSize {
        switch presentation {
        case .hidden:
            return ParityLayout.hiddenSize(settings.appearance, geometry: geometry)
        case .idle:
            return ParityLayout.compactSize(settings.appearance, geometry: geometry)
        case .compact(_, let secondary):
            return ParityLayout.compactSize(settings.appearance, geometry: geometry, hasSecondary: secondary != nil)
        case .expanded(let tab):
            return ParityLayout.expandedSize(
                for: tab,
                appearance: settings.appearance,
                geometry: geometry,
                clipboardSearching: tab == .clipboard && isSearchingClipboard,
                hasLyrics: tab == .nowPlaying && settings.lyricsEnabled && lyrics.current != nil,
                hasMediaSwitcher: tab == .nowPlaying && !nowPlaying.otherSources.isEmpty
            )
        case .clockRunning:
            return ParityLayout.clockSize(settings.appearance, geometry: geometry)
        case .alert(.agentRequest(let request)):
            let lines = request.reviewLineCount(charactersPerLine: 70)
            return CGSize(
                width: 560,
                height: 32 + 2 + IslandMetrics.ContentHeight.agentRequest(lines: lines) + 14
            )
        case .alert(let alert) where alert.usesCompactAlert:
            return ParityLayout.alertSize(for: alert, appearance: settings.appearance, geometry: geometry)
        default:
            return NotchPanelMetrics.size(for: presentation, geometry: geometry)
        }
    }

    /// The part of the panel that should stay centred on the camera. A secondary bubble
    /// stretches the panel to the right, so the compact shape itself remains the anchor.
    public func panelAnchorWidth(for presentation: NotchPresentation, geometry: ScreenGeometry) -> CGFloat {
        if case .compact = presentation {
            return ParityLayout.compactWidth(settings.appearance, geometry: geometry)
        }
        return panelSize(for: presentation, geometry: geometry).width
    }

    public var currentAlert: NotchAlert? { alerts.current }

    public var showsLyrics: Bool {
        settings.lyricsEnabled && lyrics.current != nil
    }

    public var activeActivities: Set<NotchActivity> {
        var active = Set<NotchActivity>()
        if calls.session != nil { active.insert(.call) }
        if !downloadProgress.items.isEmpty { active.insert(.download) }
        if timer.isActive { active.insert(.timer) }
        if stopwatch.isActive { active.insert(.stopwatch) }
        if nowPlaying.isVisible { active.insert(.nowPlaying) }
        if agentLiveCount > 0, settings.isTabEnabled(.agents) { active.insert(.agents) }
        if session.isLocked, settings.showOnLockScreen, system.isOnAC { active.insert(.charging) }
        // Stats is a page, not a resting activity. It stays in the menu, but
        // never takes over the closed notch when nothing else is happening.
        if sports.notchMatch != nil { active.insert(.sports) }
        return active
    }

    /// The lock screen has no media or timer to show, so lead with charging instead of the clock.
    public var compactCharging: Bool {
        session.isLocked
            && settings.showOnLockScreen
            && system.isOnAC
            && !timer.isActive
            && !timer.justFinished
            && !stopwatch.isActive
            && !nowPlaying.isVisible
    }

    /// Adds a heads-up. Non-urgent alerts wait while the workbench is open; urgent ones may
    /// interrupt it.
    @discardableResult
    public func receive(_ alert: NotchAlert) -> Bool {
        if session.isLocked, !settings.showOnLockScreen { return false }
        if alert.isInstant, isExpanded { return false }
        if case .sportsGoal = alert, settings.hapticFeedback {
            NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
        }
        alerts.enqueue(alert, now: Date())
        if alerts.current != nil {
            scheduleAlertExpiry()
        }
        pumpAlerts()
        return true
    }

    public func dismissAlert() {
        alertTask?.cancel()
        alertTask = nil
        alerts.dismissCurrent()
        pumpAlerts()
    }

    private func pumpAlerts() {
        guard !(session.isLocked && !settings.showOnLockScreen) else { return }
        guard alerts.present(now: Date(), allowNonUrgent: !isExpanded) else { return }
        scheduleAlertExpiry()
    }

    private func scheduleAlertExpiry() {
        alertTask?.cancel()
        alertTask = nil
        guard let expiry = alerts.expiry else { return }
        let delay = max(0, expiry.timeIntervalSinceNow)
        alertTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled, let self else { return }
            if self.alerts.expire(now: Date()) {
                self.pumpAlerts()
            }
            self.scheduleAlertExpiry()
        }
    }

    public var compactValue: String {
        if timer.isActive {
            return ClockFormat.clock(timer.remaining, roundingUp: true)
        }
        if timer.justFinished { return "Done" }
        if stopwatch.isActive { return ClockFormat.clock(stopwatch.elapsed, tenths: true) }
        if nowPlaying.isVisible, let title = nowPlaying.track?.title, !title.isEmpty {
            return String(title.prefix(28))
        }
        if compactCharging { return "\(system.batteryLevel)%" }
        return ClockFormat.wallClockShortIST()
    }

    public var compactLabel: String {
        if timer.isActive { return timer.isPaused ? "Paused" : (timer.lastWasFocus ? "Focus" : "Timer") }
        if timer.justFinished { return "Timer" }
        if stopwatch.isActive { return stopwatch.isRunning ? "Stopwatch" : "Stopwatch paused" }
        if nowPlaying.isVisible { return "Playing" }
        if compactCharging { return "Charging" }
        return "Ready"
    }
}
