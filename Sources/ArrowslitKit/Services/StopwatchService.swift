import AppKit
import Foundation
import Observation

@MainActor
@Observable
public final class StopwatchService {
    public private(set) var isRunning = false
    public private(set) var elapsed: TimeInterval = 0

    @ObservationIgnored private var accumulated: TimeInterval = 0
    @ObservationIgnored private var startedAt: Date?
    @ObservationIgnored private var ticker: Timer?

    public init() {}

    public func toggle() {
        if isRunning { pause() } else { start() }
    }

    public func start() {
        guard !isRunning else { return }
        startedAt = Date()
        isRunning = true
        startTicker()
    }

    public func pause() {
        guard isRunning else { return }
        accumulated = elapsed
        startedAt = nil
        isRunning = false
        stopTicker()
    }

    public func reset() {
        stopTicker()
        accumulated = 0
        startedAt = nil
        elapsed = 0
        isRunning = false
    }

    private func startTicker() {
        stopTicker()
        let timer = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, let startedAt = self.startedAt else { return }
                self.elapsed = self.accumulated + max(0, Date().timeIntervalSince(startedAt))
            }
        }
        timer.tolerance = 0.03
        RunLoop.main.add(timer, forMode: .common)
        ticker = timer
    }

    private func stopTicker() {
        ticker?.invalidate()
        ticker = nil
    }
}
