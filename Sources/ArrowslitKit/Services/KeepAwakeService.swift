import AppKit
import Foundation
import Observation

@MainActor
@Observable
public final class KeepAwakeService {
    public private(set) var isOn = false
    /// When the current session started, for the closed-notch timer.
    public private(set) var startedAt: Date?
    /// When a timed session ends; nil when it runs until switched off.
    public private(set) var endDate: Date?

    @ObservationIgnored private var activity: NSObjectProtocol?
    @ObservationIgnored private var endTask: Task<Void, Never>?
    @ObservationIgnored private var caffeinate: Process?

    public init() {}

    public func toggle() {
        if isOn { stop() } else { start() }
    }

    public func start() {
        guard !isOn else { return }
        let defaults = UserDefaults.standard
        let minutes = defaults.object(forKey: "arrowslit.keepAwake.minutes") as? Int ?? 0
        let allowDisplaySleep = defaults.object(forKey: "arrowslit.keepAwake.allowDisplaySleep") as? Bool ?? false
        let allowDiskSleep = defaults.object(forKey: "arrowslit.keepAwake.allowDiskSleep") as? Bool ?? false
        var options: ProcessInfo.ActivityOptions = [.idleSystemSleepDisabled, .userInitiated]
        if !allowDisplaySleep { options.insert(.idleDisplaySleepDisabled) }
        activity = ProcessInfo.processInfo.beginActivity(
            options: options,
            reason: "Arrowslit Keep Awake"
        )
        if !allowDiskSleep {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/caffeinate")
            process.arguments = ["-m"]
            if (try? process.run()) != nil { caffeinate = process }
        }
        startedAt = Date()
        endDate = minutes > 0 ? Date().addingTimeInterval(TimeInterval(minutes * 60)) : nil
        isOn = true
        if let endDate {
            endTask?.cancel()
            endTask = Task { [weak self] in
                try? await Task.sleep(for: .seconds(max(0, endDate.timeIntervalSinceNow)))
                guard !Task.isCancelled else { return }
                self?.stop()
            }
        }
    }

    public func stop() {
        endTask?.cancel()
        endTask = nil
        if let activity {
            ProcessInfo.processInfo.endActivity(activity)
            self.activity = nil
        }
        if let caffeinate {
            if caffeinate.isRunning { caffeinate.terminate() }
            self.caffeinate = nil
        }
        startedAt = nil
        endDate = nil
        isOn = false
    }
}
