import AppKit
import Foundation
import Observation

@MainActor
@Observable
public final class KeepAwakeService {
    public private(set) var isOn = false
    /// When the current session started, for the closed-notch timer.
    public private(set) var startedAt: Date?

    @ObservationIgnored private var activity: NSObjectProtocol?

    public init() {}

    public func toggle() {
        if isOn { stop() } else { start() }
    }

    public func start() {
        guard !isOn else { return }
        activity = ProcessInfo.processInfo.beginActivity(
            options: [.idleSystemSleepDisabled, .userInitiated],
            reason: "Arrowslit Keep Awake"
        )
        startedAt = Date()
        isOn = true
    }

    public func stop() {
        if let activity {
            ProcessInfo.processInfo.endActivity(activity)
            self.activity = nil
        }
        startedAt = nil
        isOn = false
    }
}
