import AppKit
import Foundation
import Observation

@MainActor
@Observable
public final class TimerService {
    public private(set) var countdown: Countdown?
    public private(set) var lastMinutes: Int = 25
    public private(set) var justFinished = false
    public private(set) var lastWasFocus = false

    /// The value under the Timer ruler. It survives a reset so the panel opens where it left off.
    public var panelMinutes = 25
    /// The value under the Pomodoro ruler.
    public var focusMinutes = 25
    /// The break shown under the Pomodoro time.
    public var breakMinutes = 5

    @ObservationIgnored private var ticker: Timer?
    @ObservationIgnored private var activity: NSObjectProtocol?
    @ObservationIgnored private var finishTask: Task<Void, Never>?

    public init() {}

    public var isActive: Bool { countdown != nil && !(countdown?.isFinished ?? true) }
    public var isPaused: Bool { countdown?.isPaused ?? false }
    public var remaining: TimeInterval { countdown?.remaining(at: Date()) ?? 0 }
    public var progress: Double { countdown?.progress(at: Date()) ?? 0 }

    public func startFocus(minutes: Int = 25) {
        let value = min(max(minutes, 5), 60)
        focusMinutes = value
        start(minutes: value, updatePanel: false)
        lastWasFocus = true
    }

    public func startBreak(minutes: Int = 5) {
        let value = min(max(minutes, 1), 60)
        breakMinutes = value
        start(minutes: value, updatePanel: false)
        lastWasFocus = false
    }

    public func start(minutes: Int) {
        start(minutes: minutes, updatePanel: true)
    }

    private func start(minutes: Int, updatePanel: Bool) {
        stopTicker()
        lastMinutes = min(max(minutes, 1), 24 * 60)
        if updatePanel { panelMinutes = lastMinutes }
        countdown = Countdown(minutes: lastMinutes, now: Date())
        justFinished = false
        beginActivity()
        startTicker()
    }

    public func togglePause() {
        guard var current = countdown else { return }
        if current.isRunning {
            current.pause(at: Date())
            stopTicker()
            endActivity()
        } else if current.isPaused {
            current.resume(at: Date())
            beginActivity()
            startTicker()
        }
        countdown = current
    }

    public func add(minutes: Int) {
        guard var current = countdown else { return }
        current.add(minutes: minutes, now: Date())
        countdown = current
        if current.isRunning { startTicker() }
    }

    public func reset() {
        stopTicker()
        endActivity()
        countdown = nil
        justFinished = false
        finishTask?.cancel()
        finishTask = nil
    }

    public func acknowledgeFinish() {
        justFinished = false
    }

    private func startTicker() {
        stopTicker()
        let timer = Timer(timeInterval: 0.2, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        timer.tolerance = 0.05
        RunLoop.main.add(timer, forMode: .common)
        ticker = timer
    }

    private func stopTicker() {
        ticker?.invalidate()
        ticker = nil
    }

    private func tick() {
        guard var current = countdown else { return }
        guard current.finishIfDue(at: Date()) else {
            countdown = current
            return
        }
        countdown = current
        stopTicker()
        endActivity()
        justFinished = true
        NSSound(named: NSSound.Name("Glass"))?.play()
        finishTask?.cancel()
        finishTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled else { return }
            self?.justFinished = false
        }
    }

    private func beginActivity() {
        guard activity == nil else { return }
        activity = ProcessInfo.processInfo.beginActivity(
            options: [.userInitiatedAllowingIdleSystemSleep],
            reason: "Arrowslit countdown"
        )
    }

    private func endActivity() {
        if let activity {
            ProcessInfo.processInfo.endActivity(activity)
        }
        activity = nil
    }
}
