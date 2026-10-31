import Foundation

/// A live thing that can fill the compact notch.
public enum NotchActivity: String, CaseIterable, Sendable, Equatable {
    case call
    case timer
    case stopwatch
    case nowPlaying
    case charging
    case stats

    /// Lower comes first when several activities are live.
    public var priority: Int {
        switch self {
        case .call: 0
        case .timer: 1
        case .stopwatch: 2
        case .nowPlaying: 3
        case .charging: 4
        case .stats: 5
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
    case level(kind: LevelKind, value: Double, muted: Bool)

    public enum LevelKind: String, Sendable, Equatable {
        case volume
        case brightness
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
        case level
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
        case .level: .level
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
        case .level: 1.6
        }
    }

    /// Urgent alerts may interrupt an expanded view.
    public var isUrgent: Bool {
        self == .timerFinished
    }

    /// Instant feedback is dropped, never replayed, when an urgent alert takes over.
    public var isInstant: Bool {
        if case .level = self { return true }
        return false
    }

    /// These alerts fit in the compact strip. Calendar and timer alerts keep the larger panel.
    public var usesCompactHUD: Bool {
        switch self {
        case .charging, .lowBattery, .headphones, .level:
            return true
        case .upcomingEvent, .timerFinished, .download, .update, .welcome:
            return false
        }
    }
}

/// What the notch is showing right now.
public enum NotchPresentation: Equatable, Sendable {
    /// The closed strip: optional live activity plus the clock.
    case compact(primary: NotchActivity?, secondary: NotchActivity?)
    /// A transient system HUD drawn inside the compact strip.
    case hud(NotchAlert)
    /// The open workbench on one tab.
    case expanded(WorkbenchTab)
    /// A running timer or stopwatch, shown as the narrow pause/close nudge.
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

    public init(
        isExpanded: Bool = false,
        activeTab: WorkbenchTab = .home,
        activeActivities: Set<NotchActivity> = [],
        preferredPrimary: NotchActivity? = nil,
        alert: NotchAlert? = nil
    ) {
        self.isExpanded = isExpanded
        self.activeTab = activeTab
        self.activeActivities = activeActivities
        self.preferredPrimary = preferredPrimary
        self.alert = alert
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
        return .compact(primary: ordered.first, secondary: ordered.dropFirst().first)
    }
}
