import AppKit
import Foundation
import Observation

public enum WorkbenchTab: String, CaseIterable, Identifiable, Sendable {
    case home
    case nowPlaying
    case timer
    case calendar
    case tray
    case mirror
    case clipboard
    case notes
    case stats
    case reminders
    case stopwatch
    case keepAwake
    case launcher

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .home: "Home"
        case .nowPlaying: "Now Playing"
        case .timer: "Timer"
        case .calendar: "Calendar"
        case .tray: "Files"
        case .mirror: "Mirror"
        case .clipboard: "Clipboard"
        case .notes: "Scratchpad"
        case .stats: "System"
        case .reminders: "Reminders"
        case .stopwatch: "Stopwatch"
        case .keepAwake: "Keep Awake"
        case .launcher: "All Features"
        }
    }

    public var symbol: String {
        switch self {
        case .home: "house"
        case .nowPlaying: "music.note"
        case .timer: "timer"
        case .calendar: "calendar"
        case .tray: "tray.full"
        case .mirror: "web.camera"
        case .clipboard: "doc.on.clipboard"
        case .notes: "square.and.pencil"
        case .stats: "gauge.with.dots.needle.33percent"
        case .reminders: "checklist"
        case .stopwatch: "stopwatch"
        case .keepAwake: "cup.and.saucer.fill"
        case .launcher: "square.grid.2x2"
        }
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
    public let nowPlaying: NowPlayingService
    public let timer: TimerService
    public let calendar: CalendarService
    public let tray: TrayStore
    public let camera = CameraAccess()
    public let clipboard: ClipboardService
    public let notes: NotesStore
    public let stats: StatsService
    public let reminders: RemindersService
    public let stopwatch = StopwatchService()
    public let keepAwake = KeepAwakeService()

    public private(set) var activeTab: WorkbenchTab = .home
    public private(set) var isExpanded = false
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
        self.reminders = reminders

        calendar.onReminder = { [weak self] event in
            guard let self, self.settings.isTabEnabled(.calendar) else { return }
            self.receive(.upcomingEvent(
                title: event.title,
                startsAt: event.start,
                joinURL: event.joinURL,
                provider: event.joinProvider
            ))
        }
    }

    public func start() {
        nowPlaying.start()
        calendar.start()
        if settings.clipboardEnabled { clipboard.start() }
    }

    public func stop() {
        notes.save()
        tray.clear()
        nowPlaying.stop()
        calendar.stop()
        clipboard.stop()
        stats.stop()
        timer.reset()
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
        select(tab)
        if wasCollapsed, settings.hapticFeedback {
            NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
        }
    }

    public func collapse() {
        guard isExpanded else { return }
        isExpanded = false
        isEditingShortcuts = false
        stats.stop()
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
        if isExpanded { collapse() } else { expand(.timer) }
    }

    public func select(_ tab: WorkbenchTab) {
        activeTab = tab
        if tab != .launcher { isEditingShortcuts = false }
        if tab == .stats, isExpanded {
            stats.start()
        } else {
            stats.stop()
        }
    }

    public func startTimer(minutes: Int) {
        timer.start(minutes: minutes)
        collapse()
    }

    public func startFocus() {
        timer.startFocus()
        collapse()
    }

    public func startBreak() {
        timer.startBreak()
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

    public func toggleShortcut(_ tab: WorkbenchTab) {
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
            if !enabled { stats.stop() }
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
            alert: alerts.current
        ))
    }

    public var currentAlert: NotchAlert? { alerts.current }

    public var activeActivities: Set<NotchActivity> {
        var active = Set<NotchActivity>()
        if timer.isActive { active.insert(.timer) }
        if stopwatch.isRunning { active.insert(.stopwatch) }
        if nowPlaying.isVisible { active.insert(.nowPlaying) }
        if stats.isRunning, active.isEmpty { active.insert(.stats) }
        return active
    }

    /// Adds a heads-up. Non-urgent alerts wait while the workbench is open; urgent ones may
    /// interrupt it.
    public func receive(_ alert: NotchAlert) {
        alerts.enqueue(alert, now: Date())
        if alerts.current != nil {
            scheduleAlertExpiry()
        }
        pumpAlerts()
    }

    public func dismissAlert() {
        alertTask?.cancel()
        alertTask = nil
        alerts.dismissCurrent()
        pumpAlerts()
    }

    private func pumpAlerts() {
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
        if nowPlaying.isVisible, let title = nowPlaying.track?.title, !title.isEmpty {
            return String(title.prefix(28))
        }
        return ClockFormat.wallClockIST()
    }

    public var compactLabel: String {
        if timer.isActive { return timer.isPaused ? "Paused" : "Focus" }
        if timer.justFinished { return "Timer" }
        if nowPlaying.isVisible { return "Playing" }
        return "Ready"
    }
}
