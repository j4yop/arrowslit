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
    /// Sports uses F (football); the rest follow standard shortcut keys.
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

private struct AgentLiveUpdate: Equatable {
    let providers: [AgentProvider]
    let session: AgentLiveSession?
    let openCode: AgentLiveSession?
}

@MainActor
@Observable
public final class AppState {
    public let settings: SettingsStore
    /// The closed notch's live feedback and activity catalogue.
    public let live = NotchLiveSettings()
    public let calls = CallMonitor()
    public let microphone = MicrophoneMute()
    public let inputSource = InputSourceMonitor()
    public private(set) var downloads: DownloadsWatcher
    public private(set) var downloadProgress: DownloadProgressMonitor
    public let todos = TodoStore()
    public let shortcuts = ShortcutsService()
    public let agents = AgentBridge()
    @ObservationIgnored private var agentLiveObservation: AnyCancellable?
    @ObservationIgnored private var agentEventObservation: AnyCancellable?
    /// Keeps the compact notch observing live agent sessions without making
    /// every caller subscribe to the reader's full snapshot.
    public private(set) var agentLiveCount = 0
    /// The session the closed notch is showing. OpenCode falls back to its
    /// waiting session when no turn is active, so the reading lasts for the
    /// session rather than an arbitrary retention window.
    private(set) var liveAgentSession: AgentLiveSession?
    private(set) var openCodeAgentSession: AgentLiveSession?
    private(set) var liveAgentProviders: [AgentProvider] = []

    var agentNotchSession: AgentLiveSession? { liveAgentSession ?? openCodeAgentSession }
    var agentNotchProviders: [AgentProvider] {
        liveAgentProviders.isEmpty
            ? (openCodeAgentSession.map { [$0.provider] } ?? [])
            : liveAgentProviders
    }
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
    public let systemAppearance = AppearanceService()
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
    @ObservationIgnored public var onOpenTour: (() -> Void)?
    @ObservationIgnored public var onOpenCommandCenter: (() -> Void)?
    @ObservationIgnored var onOpenCommandCenterTab: ((CommandCenterTab) -> Void)?
    @ObservationIgnored public var onOpenClipboardShelf: (() -> Void)?
    @ObservationIgnored public var onCapture: ((CaptureMode) -> Void)?
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
        self.downloads = DownloadsWatcher(folder: settings.downloadsFolderURL)
        self.downloadProgress = DownloadProgressMonitor(folder: settings.downloadsFolderURL)
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
        alerts.durationScale = settings.hudDurationScale
        self.calendar.configure(leadMinutes: settings.calendarLeadMinutes,
                                excludedIDs: settings.calendarExcludedIDs)
        self.reminders.configure(showCompleted: settings.remindersShowCompleted,
                                 excludedIDs: settings.remindersExcludedIDs)
        self.stats.refreshInterval = settings.statsRefreshSeconds
        NookMotion.liquidAnimations = settings.liquidAnimations
        nowPlaying.appFilter = settings.mediaAppFilter
        nowPlaying.lingerDuration = settings.pausedMediaLinger
        nowPlaying.onAppSeen = { [weak settings] identifier in
            settings?.noteMediaApp(identifier)
        }
        nowPlaying.onTrackChanged = { [weak self] track in
            guard let self, track.isPlaying, !track.title.isEmpty else { return }
            self.receive(.track(title: track.title, artist: track.artist))
        }
        system.live = live
        microphone.onMuteChanged = { [weak self] muted in
            self?.receive(.microphone(muted: muted))
        }
        clipboard.onCaptured = { [weak self] kind in
            self?.receive(.clipboard(kind: kind.title))
        }
        inputSource.onChange = { [weak self] code, name in
            self?.receive(.inputSource(code: code, name: name))
        }
        agentEventObservation = AgentUsageService.shared.events
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in self?.receiveAgentEvent(event) }

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
        inputSource.start()
        system.onAlert = { [weak self] alert in
            guard let self else { return }
            if self.session.isLocked, !self.settings.showOnLockScreen { return }
            if alert.isInstant, self.isExpanded { return }
            self.receive(alert)
        }
        system.start()
        if settings.statsEnabled { stats.start() }
        nowPlaying.start()
        if settings.callsEnabled { calls.start() }
        if settings.callsEnabled || live.isOn(NotchLiveSettings.Event.microphone) {
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
            .map { snapshot -> AgentLiveUpdate in
                let live = snapshot.live.sorted { $0.started < $1.started }
                let openCode = live.first { $0.provider == .opencode }
                    ?? snapshot.waiting.last { $0.provider == .opencode }
                return AgentLiveUpdate(
                    providers: live.map(\.provider),
                    session: live.first,
                    openCode: openCode
                )
            }
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] update in
                self?.applyAgentSnapshot(update)
            }
    }

    /// Publishes the agent sessions the notch should consider. OpenCode's
    /// waiting session counts as present, so a goal or other alert can take
    /// the strip for a moment and then hand it back for the rest of the
    /// OpenCode session.
    private func applyAgentSnapshot(_ update: AgentLiveUpdate) {
        liveAgentProviders = update.providers
        liveAgentSession = update.session
        openCodeAgentSession = update.openCode
        agentLiveCount = update.providers.count
    }

    public func stop() {
        agentLiveObservation?.cancel()
        agentLiveObservation = nil
        agentEventObservation?.cancel()
        agentEventObservation = nil
        notes.save()
        tray.clearUnpinned()
        nowPlaying.stop()
        calls.stop()
        microphone.stop()
        downloads.stop()
        downloadProgress.stop()
        agents.stop()
        hotKeys.unregister()
        inputSource.stop()
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

    public func setCalendarLeadMinutes(_ minutes: Int) {
        settings.calendarLeadMinutes = min(60, max(0, minutes))
        calendar.configure(leadMinutes: settings.calendarLeadMinutes,
                           excludedIDs: settings.calendarExcludedIDs)
    }

    public func setCalendarExcluded(_ ids: [String]) {
        settings.calendarExcludedIDs = ids
        calendar.configure(leadMinutes: settings.calendarLeadMinutes,
                           excludedIDs: settings.calendarExcludedIDs)
    }

    public func setHudDurationScale(_ value: Double) {
        settings.hudDurationScale = value
        alerts.durationScale = value
    }

    public func setStatsRefreshSeconds(_ value: Double) {
        settings.statsRefreshSeconds = value
        stats.setRefreshInterval(value)
    }

    public func setStatsMetrics(_ values: [String]) {
        settings.statsMetrics = values
    }

    public func setClipboardCapacity(_ value: Int) {
        settings.clipboardCapacity = max(1, value)
        clipboard.setCapacity(settings.clipboardCapacity)
    }

    public func setClipboardIgnoreConfidential(_ value: Bool) {
        settings.clipboardIgnoreConfidential = value
        clipboard.setIgnoreConfidential(value)
    }

    public func setRemindersShowCompleted(_ value: Bool) {
        settings.remindersShowCompleted = value
        reminders.configure(showCompleted: settings.remindersShowCompleted,
                            excludedIDs: settings.remindersExcludedIDs)
    }

    public func setRemindersExcluded(_ ids: [String]) {
        settings.remindersExcludedIDs = ids
        reminders.configure(showCompleted: settings.remindersShowCompleted,
                            excludedIDs: settings.remindersExcludedIDs)
    }

    public func setDownloadsFolder(_ path: String?) {
        let wasRunning = settings.downloadsEnabled
        downloads.stop()
        downloadProgress.stop()
        settings.downloadsFolderPath = path
        downloads = DownloadsWatcher(folder: settings.downloadsFolderURL)
        downloadProgress = DownloadProgressMonitor(folder: settings.downloadsFolderURL)
        downloads.onFinished = { [weak self] url in
            guard let self, self.settings.downloadsEnabled else { return }
            self.receive(.download(name: url.lastPathComponent))
        }
        if wasRunning {
            downloads.start()
            downloadProgress.start()
        }
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
            activeActivities: compactActivities,
            preferredPrimary: nil,
            alert: alerts.current,
            showWhenIdle: settings.showWhenIdle,
            isHoveringNotch: isHoveringNotch
        ))
    }

    /// Expanded pages keep their own clock behaviour even when the person has
    /// turned the matching closed strip off.
    private var compactActivities: Set<NotchActivity> {
        isExpanded ? activeActivities : activeActivities.filter { live.showsStrip($0) }
    }

    /// What a mirror panel shows while content is open elsewhere. Alerts still appear on every
    /// screen; only opened content stays on the active one.
    public var mirrorPresentation: NotchPresentation {
        // Mirror exactly what the active panel is showing when it is an alert or HUD, so the
        // same alert appears on every screen. Opened content stays on the active screen.
        if case .alert = presentation { return presentation }
        if case .hud = presentation { return presentation }
        let ordered = PresentationResolver.ordered(compactActivities, preferred: nil)
        if let primary = ordered.first {
            return .compact(primary: primary)
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
    /// already use the standard size contract; the remaining panels keep their
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
        case .compact(let activity):
            return ParityLayout.compactActivitySize(
                activity,
                appearance: settings.appearance,
                geometry: geometry,
                downloadName: activity == .download ? downloadProgress.items.first?.name : nil
            )
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
        case .hud(let alert):
            return ParityLayout.alertSize(for: alert, appearance: settings.appearance,
                                          geometry: geometry, timerWasFocus: timer.lastWasFocus)
        case .alert(let alert):
            return ParityLayout.alertSize(for: alert, appearance: settings.appearance,
                                          geometry: geometry, timerWasFocus: timer.lastWasFocus)
        default:
            return NotchPanelMetrics.size(for: presentation, geometry: geometry)
        }
    }

    /// The part of the panel that should stay centred on the camera. A notice
    /// reaches further toward its wider wing, so its camera gap, not the whole
    /// island, is what stays over the housing.
    public func panelAnchorWidth(for presentation: NotchPresentation, geometry: ScreenGeometry) -> CGFloat {
        let alert: NotchAlert?
        switch presentation {
        case .hud(let value): alert = value
        case .alert(let value): alert = value
        default: alert = nil
        }
        guard let alert, !isAgentRequest(alert) else {
            return panelSize(for: presentation, geometry: geometry).width
        }
        let notch = ParityLayout.notch(in: geometry).width
        let wings = ParityLayout.alertWings(for: alert, timerWasFocus: timer.lastWasFocus)
        let maximum = max(0, (geometry.size.width - 24 - notch) / 2)
        return notch + 2 * min(wings.leading, maximum)
    }

    private func isAgentRequest(_ alert: NotchAlert) -> Bool {
        if case .agentRequest = alert { return true }
        return false
    }

    public var currentAlert: NotchAlert? { alerts.current }

    public var showsLyrics: Bool {
        settings.lyricsEnabled && lyrics.current != nil
    }

    public var activeActivities: Set<NotchActivity> {
        var active = Set<NotchActivity>()
        if calls.session != nil, settings.callStripEnabled { active.insert(.call) }
        if !downloadProgress.items.isEmpty { active.insert(.download) }
        if timer.isActive { active.insert(.timer) }
        if stopwatch.isActive { active.insert(.stopwatch) }
        if nowPlaying.isVisible { active.insert(.nowPlaying) }
        if !agentNotchProviders.isEmpty, settings.isTabEnabled(.agents) { active.insert(.agents) }
        if !calendarYieldsToLiveActivity, settings.isTabEnabled(.calendar), let event = calendar.nextEvent,
           event.isHappening(at: Date()) || event.start.timeIntervalSinceNow <= 30 * 60 {
            active.insert(.calendar)
        }
        if settings.isTabEnabled(.keepAwake), keepAwake.isOn { active.insert(.keepAwake) }
        if session.isLocked, settings.showOnLockScreen, system.isOnAC { active.insert(.charging) }
        // Stats is a page, not a resting activity. It stays in the menu, but
        // never takes over the closed notch when nothing else is happening.
        if sports.notchMatch != nil { active.insert(.sports) }
        return active
    }

    /// A calendar reminder must never cover a live call, a playing song or
    /// video, or the sports feed. The calendar page stays available.
    private var calendarYieldsToLiveActivity: Bool {
        calls.session != nil || nowPlaying.isVisible || sports.notchMatch != nil
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

    private func receiveAgentEvent(_ event: AgentUsageEvent) {
        switch event {
        case .finished(let provider, let duration, let cost, _, _):
            let detail = [AgentFormat.duration(duration, locale: .current),
                          cost > 0 ? AgentFormat.cost(cost) : ""]
                .filter { !$0.isEmpty }.joined(separator: " · ")
            receive(.agentEvent(provider: provider.displayName, title: "Finished", detail: detail))
        case .limitWarning(let provider, let window):
            receive(.agentEvent(provider: provider.displayName, title: limitWindowName(window),
                                detail: AgentFormat.percent(window.usedFraction) + " used"))
        case .limitReset(let provider, let window):
            receive(.agentEvent(provider: provider.displayName, title: limitWindowName(window),
                                detail: "Renewed"))
        case .budgetReached(let spent, _):
            receive(.agentEvent(provider: "AI Agents", title: "Budget", detail: AgentFormat.cost(spent)))
        }
    }

    /// The window named in an agent's limit notice.
    private func limitWindowName(_ window: AgentLimitWindow) -> String {
        switch window.kind {
        case .session: return "Session"
        case .weekly: return window.scope.map { "Weekly · \($0)" } ?? "Weekly"
        case .other: return "Limit"
        }
    }

    /// Whether the person has left this feedback event on in the Notch tab.
    private func shows(_ alert: NotchAlert) -> Bool {
        switch alert {
        case .level(let kind, _, _):
            switch kind {
            case .volume: return live.isOn(NotchLiveSettings.Event.volume)
            case .brightness: return live.isOn(NotchLiveSettings.Event.brightness)
            case .keyboardLight: return live.isOn(NotchLiveSettings.Event.keyboardLight)
            }
        case .charging, .lowBattery: return live.isOn(NotchLiveSettings.Event.battery)
        case .headphones: return live.isOn(NotchLiveSettings.Event.accessory)
        case .clipboard: return live.isOn(NotchLiveSettings.Event.clipboard)
        case .download: return live.isOn(NotchLiveSettings.Event.download)
        case .agentEvent: return live.isOn(NotchLiveSettings.Event.agents)
        case .track: return live.isOn(NotchLiveSettings.Event.track)
        case .microphone: return live.isOn(NotchLiveSettings.Event.microphone)
        case .inputSource: return live.isOn(NotchLiveSettings.Event.inputSource)
        case .timerFinished: return live.isOn(NotchLiveSettings.Event.timer)
        case .systemNotification: return live.isOn(NotchLiveSettings.Event.systemNotification)
        case .capture: return live.isOn(NotchLiveSettings.Event.capture)
        case .watch: return live.isOn(NotchLiveSettings.Event.watch)
        case .upcomingEvent: return settings.isTabEnabled(.calendar) && !calendarYieldsToLiveActivity
        default: return true
        }
    }

    /// Adds a heads-up. Non-urgent alerts wait while the workbench is open; urgent ones may
    /// interrupt it.
    @discardableResult
    public func receive(_ alert: NotchAlert) -> Bool {
        guard shows(alert) else { return false }
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
