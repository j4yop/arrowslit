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
        lowBatteryAlerts: Bool,
        warningLevel: Int = 20,
        criticalLevel: Int = 10
    ) -> [NotchAlert] {
        guard let previous else {
            self.previous = snapshot
            rearm(for: snapshot, warningLevel: warningLevel, criticalLevel: criticalLevel)
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
            let thresholds = Set([warningLevel, criticalLevel].filter { (0..<100).contains($0) })
                .sorted(by: >)
            for threshold in thresholds where snapshot.level <= threshold
                && previous.level > threshold
                && !announced.contains(threshold) {
                alerts.append(.lowBattery(level: snapshot.level))
                announced.insert(threshold)
            }
        }

        rearm(for: snapshot, warningLevel: warningLevel, criticalLevel: criticalLevel)
        return alerts
    }

    private mutating func rearm(for snapshot: PowerSnapshot, warningLevel: Int = 20, criticalLevel: Int = 10) {
        if snapshot.isOnAC || snapshot.isCharging {
            announced.removeAll()
            return
        }
        for threshold in [warningLevel, criticalLevel] where snapshot.level > threshold {
            announced.remove(threshold)
        }
    }
}
