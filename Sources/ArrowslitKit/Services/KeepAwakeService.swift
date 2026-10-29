import AppKit
import Foundation
import Observation

@MainActor
@Observable
public final class KeepAwakeService {
    public private(set) var isOn = false

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
        isOn = true
    }

    public func stop() {
        if let activity {
            ProcessInfo.processInfo.endActivity(activity)
            self.activity = nil
        }
        isOn = false
    }
}
