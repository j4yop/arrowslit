import Foundation

/// One alert at a time, with a queue behind it. Urgent alerts may interrupt a non-urgent one;
/// instant feedback is dropped rather than shown late.
public struct AlertQueue: Equatable, Sendable {
    public private(set) var current: NotchAlert?
    public private(set) var shownAt: Date?
    public private(set) var pending: [NotchAlert] = []

    public init() {}

    /// Adds an alert without necessarily showing it. A second alert of the same kind replaces the
    /// first one, whether it is showing or waiting.
    @discardableResult
    public mutating func enqueue(_ alert: NotchAlert, now: Date) -> Bool {
        if let current, current.kind == alert.kind {
            self.current = alert
            shownAt = now
            return true
        }

        pending.removeAll { $0.kind == alert.kind }

        if alert.isUrgent, let current, !current.isUrgent {
            if !current.isInstant {
                pending.insert(current, at: 0)
            }
            self.current = alert
            shownAt = now
            return true
        }

        if alert.isInstant, current?.isUrgent == true {
            return false
        }

        pending.append(alert)
        return false
    }

    /// Shows the next alert if the current one has gone. Non-urgent alerts wait while an
    /// expanded view is open.
    @discardableResult
    public mutating func present(now: Date, allowNonUrgent: Bool) -> Bool {
        guard current == nil else { return false }
        let index = pending.firstIndex(where: \.isUrgent)
            ?? (allowNonUrgent ? pending.firstIndex(where: { !$0.isUrgent }) : nil)
        guard let index else { return false }
        current = pending.remove(at: index)
        shownAt = now
        return true
    }

    public var expiry: Date? {
        guard let current, let shownAt else { return nil }
        return shownAt.addingTimeInterval(current.displayDuration)
    }

    @discardableResult
    public mutating func expire(now: Date) -> Bool {
        guard let expiry, now >= expiry else { return false }
        dismissCurrent()
        return true
    }

    public mutating func dismissCurrent() {
        current = nil
        shownAt = nil
    }

    public mutating func removeAll(of kind: NotchAlert.Kind) {
        pending.removeAll { $0.kind == kind }
        if current?.kind == kind {
            dismissCurrent()
        }
    }
}
