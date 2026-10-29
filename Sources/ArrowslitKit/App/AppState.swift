import AppKit
import Foundation
import Observation

public enum WorkbenchTab: String, CaseIterable, Identifiable, Sendable {
    case nowPlaying
    case timer
    case calendar
    case tray
    case mirror
    case clipboard
    case notes
    case stats

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .nowPlaying: "Now Playing"
        case .timer: "Timer"
        case .calendar: "Calendar"
        case .tray: "Files"
        case .mirror: "Mirror"
        case .clipboard: "Clipboard"
        case .notes: "Scratchpad"
        case .stats: "System"
        }
    }

    public var symbol: String {
        switch self {
        case .nowPlaying: "music.note"
        case .timer: "timer"
        case .calendar: "calendar"
        case .tray: "tray.full"
        case .mirror: "web.camera"
        case .clipboard: "doc.on.clipboard"
        case .notes: "square.and.pencil"
        case .stats: "gauge.with.dots.needle.33percent"
        }
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

    public private(set) var activeTab: WorkbenchTab = .timer
    public private(set) var isExpanded = false

    @ObservationIgnored public var onOpenSettings: (() -> Void)?

    public init(
        settings: SettingsStore = SettingsStore(),
        nowPlaying: NowPlayingService = NowPlayingService(),
        timer: TimerService = TimerService(),
        calendar: CalendarService = CalendarService(),
        tray: TrayStore = TrayStore(),
        clipboard: ClipboardService = ClipboardService(),
        notes: NotesStore = NotesStore(),
        stats: StatsService = StatsService()
    ) {
        self.settings = settings
        self.nowPlaying = nowPlaying
        self.timer = timer
        self.calendar = calendar
        self.tray = tray
        self.clipboard = clipboard
        self.notes = notes
        self.stats = stats
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
    }

    public func expand(_ tab: WorkbenchTab = .timer) {
        if isExpanded, activeTab == tab { return }
        isExpanded = true
        select(tab)
    }

    public func collapse() {
        guard isExpanded else { return }
        isExpanded = false
        stats.stop()
        notes.save()
    }

    public func toggle() {
        if isExpanded { collapse() } else { expand(.timer) }
    }

    public func select(_ tab: WorkbenchTab) {
        activeTab = tab
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

    public func toggleTimer() {
        timer.togglePause()
    }

    public func resetTimer() {
        timer.reset()
    }

    public func setClipboardEnabled(_ enabled: Bool) {
        settings.clipboardEnabled = enabled
        if enabled { clipboard.start() } else { clipboard.stop() }
    }

    public func setStatsEnabled(_ enabled: Bool) {
        settings.statsEnabled = enabled
        if !enabled { stats.stop() }
    }

    public func setNotesEnabled(_ enabled: Bool) {
        settings.notesEnabled = enabled
        if !enabled, activeTab == .notes { select(.timer) }
    }

    public func setMenuBarIconVisible(_ visible: Bool) {
        settings.showMenuBarIcon = visible
    }

    public var compactValue: String {
        if timer.isActive {
            return ClockFormat.clock(timer.remaining, roundingUp: true)
        }
        if timer.justFinished { return "DONE" }
        if nowPlaying.isVisible, let title = nowPlaying.track?.title, !title.isEmpty {
            return String(title.prefix(28))
        }
        return ClockFormat.wallClock()
    }

    public var compactLabel: String {
        if timer.isActive { return timer.isPaused ? "PAUSED" : "FOCUS" }
        if timer.justFinished { return "TIMER" }
        if nowPlaying.isVisible { return "PLAYING" }
        return "READY"
    }
}
