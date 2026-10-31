import Foundation

/// A reading from the Mac's internal battery.
public struct PowerSnapshot: Equatable, Sendable {
    public var level: Int
    public var isCharging: Bool
    public var isOnAC: Bool

    public init(level: Int, isCharging: Bool, isOnAC: Bool) {
        self.level = level
        self.isCharging = isCharging
        self.isOnAC = isOnAC
    }
}

/// Turns battery readings into the two power alerts the notch knows about.
///
/// The first reading is a baseline, so launching while already plugged in does not announce
/// "Charging". The 20% and 10% warnings fire once on the way down and re-arm after the battery
/// goes back above the threshold or the Mac is plugged in.
public struct PowerAlertRules {
    private var previous: PowerSnapshot?
    private var announced: Set<Int> = []

    public init() {}

    public mutating func observe(
        _ snapshot: PowerSnapshot,
        chargingAlerts: Bool,
        lowBatteryAlerts: Bool
    ) -> [NotchAlert] {
        guard let previous else {
            self.previous = snapshot
            rearm(for: snapshot)
            return []
        }

        self.previous = snapshot
        var alerts: [NotchAlert] = []

        let gainedPower = !previous.isOnAC && snapshot.isOnAC
        let startedCharging = !previous.isCharging && snapshot.isCharging
        if chargingAlerts, gainedPower || startedCharging {
            alerts.append(.charging(level: snapshot.level, isCharging: snapshot.isCharging))
        }

        if lowBatteryAlerts, !snapshot.isOnAC, !snapshot.isCharging {
            for threshold in [20, 10] where snapshot.level <= threshold
                && previous.level > threshold
                && !announced.contains(threshold) {
                alerts.append(.lowBattery(level: snapshot.level))
                announced.insert(threshold)
            }
        }

        rearm(for: snapshot)
        return alerts
    }

    private mutating func rearm(for snapshot: PowerSnapshot) {
        if snapshot.isOnAC || snapshot.isCharging || snapshot.level > 20 {
            announced.remove(20)
        }
        if snapshot.isOnAC || snapshot.isCharging || snapshot.level > 10 {
            announced.remove(10)
        }
    }
}
