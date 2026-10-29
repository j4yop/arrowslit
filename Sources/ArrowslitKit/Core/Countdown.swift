import Foundation

/// Pure countdown state with an injected clock, so the maths is testable without waiting.
public struct Countdown: Equatable, Sendable {
    public enum Phase: Equatable, Sendable {
        case running(until: Date)
        case paused(remaining: TimeInterval)
        case finished
    }

    public let total: TimeInterval
    public private(set) var phase: Phase

    public init(minutes: Int, now: Date) {
        let seconds = min(max(Double(minutes) * 60, 1), 24 * 3600)
        total = seconds
        phase = .running(until: now.addingTimeInterval(seconds))
    }

    public func remaining(at now: Date) -> TimeInterval {
        switch phase {
        case .running(let until): max(0, until.timeIntervalSince(now))
        case .paused(let value): max(0, value)
        case .finished: 0
        }
    }

    public func progress(at now: Date) -> Double {
        guard total > 0 else { return 1 }
        return min(max(1 - remaining(at: now) / total, 0), 1)
    }

    public var isRunning: Bool {
        if case .running = phase { return true }
        return false
    }

    public var isPaused: Bool {
        if case .paused = phase { return true }
        return false
    }

    public var isFinished: Bool { phase == .finished }

    public mutating func pause(at now: Date) {
        guard case .running = phase else { return }
        phase = .paused(remaining: remaining(at: now))
    }

    public mutating func resume(at now: Date) {
        guard case .paused(let value) = phase else { return }
        phase = .running(until: now.addingTimeInterval(value))
    }

    public mutating func add(minutes: Int, now: Date) {
        let delta = Double(minutes) * 60
        switch phase {
        case .running(let until):
            phase = .running(until: until.addingTimeInterval(delta))
        case .paused(let value):
            phase = .paused(remaining: max(1, value + delta))
        case .finished:
            phase = .running(until: now.addingTimeInterval(delta))
        }
    }

    @discardableResult
    public mutating func finishIfDue(at now: Date) -> Bool {
        guard case .running(let until) = phase, now >= until else { return false }
        phase = .finished
        return true
    }
}
