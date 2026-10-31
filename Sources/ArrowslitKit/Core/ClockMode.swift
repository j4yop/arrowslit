import Foundation

/// The three modes in the shared clock panel. Pomodoro is the DynamicLedge "focus" mode.
public enum ClockMode: String, CaseIterable, Identifiable, Sendable, Equatable {
    case timer
    case focus
    case stopwatch

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .timer: "Timer"
        case .focus: "Pomodoro"
        case .stopwatch: "Stopwatch"
        }
    }
}
