import Foundation

/// A live thing that can fill the compact notch.
public enum NotchActivity: String, CaseIterable, Sendable, Equatable {
    case call
    case timer
    case stopwatch
    case agents
    case calendar
    case keepAwake
    case watch
    case sports
    case nowPlaying
    case download
    case charging
    case stats

    /// Lower comes first when several activities are live.
    public var priority: Int {
        switch self {
        case .call: 0
        case .timer: 1
        case .stopwatch: 2
        case .agents: 3
        case .calendar: 4
        case .keepAwake: 5
        case .watch: 6
        case .sports: 7
        case .nowPlaying: 8
        case .download: 9
        case .charging: 10
        case .stats: 11
        }
    }
}

/// A short heads-up shown over the notch.
public enum NotchAlert: Equatable, Sendable {
    case upcomingEvent(title: String, startsAt: Date, joinURL: URL?, provider: MeetingLinks.Provider?)
    case timerFinished
    case charging(level: Int, isCharging: Bool)
    case lowBattery(level: Int)
    case headphones(name: String)
    case download(name: String)
    case update(version: String)
    case welcome(name: String)
    case sportsGoal(SportsGoalEvent)
    case shortcut(name: String, succeeded: Bool)
    case agentRequest(AgentRequest)
    case level(kind: LevelKind, value: Double, muted: Bool)
    case clipboard(kind: String)
    case track(title: String, artist: String)
    case microphone(muted: Bool)
    case inputSource(code: String, name: String)
    case agentEvent(provider: String, title: String, detail: String)
    case systemNotification(app: String, title: String, body: String)
    case capture(kind: String)
    case watch(title: String, detail: String)

    public enum LevelKind: String, Sendable, Equatable {
        case volume
        case brightness
        case keyboardLight
    }

    /// Alerts of the same kind replace one another instead of stacking.
    public enum Kind: Hashable, Sendable {
        case calendar
        case timer
        case power
        case headphones
        case download
        case update
        case welcome
        case sports
        case shortcut
        case agent
        case level
        case clipboard
        case track
        case microphone
        case inputSource
        case systemNotification
        case capture
        case watch
    }

    public var kind: Kind {
        switch self {
        case .upcomingEvent: .calendar
        case .timerFinished: .timer
        case .charging, .lowBattery: .power
        case .headphones: .headphones
        case .download: .download
        case .update: .update
        case .welcome: .welcome
        case .sportsGoal: .sports
        case .shortcut: .shortcut
        case .agentRequest: .agent
        case .level: .level
        case .clipboard: .clipboard
        case .track: .track
        case .microphone: .microphone
        case .inputSource: .inputSource
        case .agentEvent: .agent
        case .systemNotification: .systemNotification
        case .capture: .capture
        case .watch: .watch
        }
    }

    public var displayDuration: TimeInterval {
        switch self {
        case .upcomingEvent: 8
        case .timerFinished: 600
        case .charging: 3
        case .lowBattery: 4
        case .headphones: 3
        case .download: 5
        case .update: 10
        case .welcome: 4
        case .sportsGoal: 7
        case .shortcut: 2.5
        case .agentRequest: 125
        case .level: 1.6
        case .clipboard: 2.5
        case .track: 3
        case .microphone: 1.6
        case .inputSource: 1.6
        case .agentEvent: 5
        case .systemNotification: 3
        case .capture: 12
        case .watch: 6
        }
    }

    /// Urgent alerts may interrupt an expanded view.
    public var isUrgent: Bool {
        switch self {
        case .timerFinished, .agentRequest: true
        default: false
        }
    }

    /// Instant feedback is dropped, never replayed, when an urgent alert takes over.
    public var isInstant: Bool {
        if case .level = self { return true }
        return false
    }

    /// These alerts fit in the compact strip. Calendar and timer alerts keep the larger panel.
    public var usesCompactHUD: Bool {
        switch self {
        case .charging, .lowBattery, .headphones, .level,
             .clipboard, .microphone, .inputSource, .agentEvent,
             .systemNotification, .capture, .watch:
            return true
        case .upcomingEvent, .timerFinished, .download, .update, .welcome, .sportsGoal, .shortcut, .agentRequest, .track:
            return false
        }
    }

    /// These alerts use Notch Shell's short, content-adaptive alert row: a leading label and a
    /// trailing value around the camera. Goal and timer-done cards keep their larger layout.
    public var usesCompactAlert: Bool {
        switch self {
        case .upcomingEvent, .download, .update, .welcome, .shortcut, .track:
            return true
        case .timerFinished, .charging, .lowBattery, .headphones, .sportsGoal, .agentRequest, .level,
             .clipboard, .track, .microphone, .inputSource, .agentEvent,
             .systemNotification, .capture, .watch:
            return false
        }
    }
}

/// What the notch is showing right now.
public enum NotchPresentation: Equatable, Sendable {
    /// Retracted into the physical notch. `peek` swells it slightly under the pointer.
    case hidden(peek: Bool)
    /// An empty pill, shown when "Show when idle" is on.
    case idle
    /// The closed strip: at most one live activity plus the clock. Keeping
    /// the strip to one reading means a second activity never grows a
    /// companion bubble beside the notch.
    case compact(primary: NotchActivity?)
    /// A transient system HUD drawn inside the compact strip.
    case hud(NotchAlert)
    /// The open workbench on one tab.
    case expanded(WorkbenchTab)
    /// A running timer or stopwatch, shown as the narrow pause/close compact strip.
    case clockRunning(ClockMode)
    /// A short heads-up above the notch.
    case alert(NotchAlert)

    public var isAlert: Bool {
        switch self {
        case .alert, .hud: return true
        default: return false
        }
    }

    public var isExpanded: Bool {
        switch self {
        case .expanded, .clockRunning: return true
        default: return false
        }
    }

    public var isHidden: Bool {
        if case .hidden = self { return true }
        return false
    }

    public var hudAlert: NotchAlert? {
        if case .hud(let alert) = self { return alert }
        return nil
    }
}

public struct PresentationInput: Equatable, Sendable {
    public var isExpanded: Bool
    public var activeTab: WorkbenchTab
    public var activeActivities: Set<NotchActivity>
    public var preferredPrimary: NotchActivity?
    public var alert: NotchAlert?
    public var showWhenIdle: Bool
    public var isHoveringNotch: Bool

    public init(
        isExpanded: Bool = false,
        activeTab: WorkbenchTab = .home,
        activeActivities: Set<NotchActivity> = [],
        preferredPrimary: NotchActivity? = nil,
        alert: NotchAlert? = nil,
        showWhenIdle: Bool = false,
        isHoveringNotch: Bool = false
    ) {
        self.isExpanded = isExpanded
        self.activeTab = activeTab
        self.activeActivities = activeActivities
        self.preferredPrimary = preferredPrimary
        self.alert = alert
        self.showWhenIdle = showWhenIdle
        self.isHoveringNotch = isHoveringNotch
    }
}

/// Pure resolution of what the notch should show. No AppKit, no timers, no side effects.
public enum PresentationResolver {
    public static func ordered(_ activities: Set<NotchActivity>, preferred: NotchActivity?) -> [NotchActivity] {
        let byPriority = activities.sorted { $0.priority < $1.priority }
        guard let preferred, activities.contains(preferred) else { return byPriority }
        return [preferred] + byPriority.filter { $0 != preferred }
    }

    public static func resolve(_ input: PresentationInput) -> NotchPresentation {
        if let alert = input.alert, !input.isExpanded || alert.isUrgent {
            if alert.usesCompactHUD, !input.isExpanded {
                return .hud(alert)
            }
            return .alert(alert)
        }
        if input.isExpanded {
            switch input.activeTab {
            case .timer where input.activeActivities.contains(.timer):
                return .clockRunning(.timer)
            case .stopwatch where input.activeActivities.contains(.stopwatch):
                return .clockRunning(.stopwatch)
            default:
                return .expanded(input.activeTab)
            }
        }

        let ordered = ordered(input.activeActivities, preferred: input.preferredPrimary)
        if let primary = ordered.first {
            return .compact(primary: primary)
        }
        if input.showWhenIdle {
            return .idle
        }
        return .hidden(peek: input.isHoveringNotch)
    }
}
