import AppKit
import SwiftUI

/// Vorssaint's Timer page: mode tabs, a Start pill, the orange minute ruler
/// and the large remaining time beside it. The stopwatch keeps the same
/// chrome and swaps the ruler for its elapsed reading.
struct VorssaintTimerPane: View {
    @Bindable var state: AppState
    @State private var mode: Mode = .timer
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private enum Mode: String, CaseIterable, Identifiable {
        case timer = "Timer"
        case pomodoro = "Pomodoro"
        case stopwatch = "Stopwatch"
        var id: String { rawValue }
    }

    private var timer: TimerService { state.timer }
    private var stopwatch: StopwatchService { state.stopwatch }

    private var shownSeconds: TimeInterval {
        if timer.countdown == nil { return TimeInterval(timer.panelMinutes * 60) }
        return timer.remaining
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                tabs
                Spacer(minLength: 12)
                actionPill
            }
            .frame(height: 28)

            Spacer(minLength: 8)

            if mode == .stopwatch {
                stopwatchBody
            } else {
                rulerBody
            }

            Spacer(minLength: 0)
        }
        .padding(.top, 2)
    }

    private var tabs: some View {
        HStack(spacing: 18) {
            ForEach(Mode.allCases) { tab in
                Button {
                    withAnimation(reduceMotion ? nil : .smooth(duration: 0.2)) { mode = tab }
                } label: {
                    Text(tab.rawValue)
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(mode == tab ? .white : .white.opacity(0.4))
                        .padding(.bottom, 5)
                        .overlay(alignment: .bottom) {
                            Capsule()
                                .fill(mode == tab ? VorssaintTheme.orange : .clear)
                                .frame(height: 2)
                        }
                        .fixedSize()
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(mode == tab ? .isSelected : [])
            }
        }
    }

    private var actionPill: some View {
        Button {
            switch mode {
            case .stopwatch:
                stopwatch.toggle()
                NookHaptics.perform(enabled: state.settings.hapticFeedback)
            case .timer:
                if timer.isActive {
                    state.toggleTimer()
                } else {
                    state.startTimer(minutes: timer.panelMinutes)
                    NookHaptics.perform(enabled: state.settings.hapticFeedback)
                }
            case .pomodoro:
                if timer.isActive {
                    state.toggleTimer()
                } else {
                    state.startFocus()
                    NookHaptics.perform(enabled: state.settings.hapticFeedback)
                }
            }
        } label: {
            Text(actionTitle)
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundStyle(VorssaintTheme.orange)
                .padding(.horizontal, 14)
                .frame(height: 27)
                .background(
                    Capsule()
                        .fill(VorssaintTheme.orange.opacity(0.16))
                )
                .contentShape(Capsule())
        }
        .buttonStyle(NookPressStyle(pressedScale: 0.94))
        .accessibilityLabel(actionTitle)
    }

    private var actionTitle: String {
        switch mode {
        case .stopwatch:
            return stopwatch.isRunning ? "Stop" : (stopwatch.elapsed > 0 ? "Resume" : "Start")
        case .timer, .pomodoro:
            if timer.isActive { return timer.isPaused ? "Resume" : "Pause" }
            return timer.justFinished ? "Again" : "Start"
        }
    }

    private var rulerBody: some View {
        HStack(alignment: .center, spacing: 14) {
            VorssaintMinuteRuler(
                minutes: Binding(
                    get: { timer.panelMinutes },
                    set: { timer.panelMinutes = $0 }
                )
            ) {
                NookHaptics.perform(enabled: state.settings.hapticFeedback)
            }
            .frame(height: 88)
            .disabled(timer.isActive)
            .opacity(timer.isActive ? 0.5 : 1)

            Text(ClockFormat.clock(shownSeconds, roundingUp: true))
                .font(.system(size: 22, weight: .light))
                .monospacedDigit()
                .foregroundStyle(VorssaintTheme.orange)
                .contentTransition(.numericText())
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(width: 76, alignment: .trailing)
                .accessibilityLabel("Time remaining")
        }
    }

    private var stopwatchBody: some View {
        VStack(spacing: 14) {
            Text(ClockFormat.clock(stopwatch.elapsed))
                .font(.system(size: 56, weight: .thin))
                .monospacedDigit()
                .foregroundStyle(.white)
                .contentTransition(.numericText())
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            HStack(spacing: 12) {
                Button {
                    stopwatch.reset()
                } label: {
                    Label("Reset", systemImage: "arrow.counterclockwise")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.7))
                        .padding(.horizontal, 14)
                        .frame(height: 30)
                        .background(Capsule().fill(.white.opacity(0.08)))
                }
                .buttonStyle(NookPressStyle(pressedScale: 0.94))
                .disabled(!stopwatch.isActive)
                .opacity(stopwatch.isActive ? 1 : 0.4)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// The recorded ruler: thirty rounded bars, orange up to the chosen minute,
/// labels every five, and a small orange triangle under the selection.
struct VorssaintMinuteRuler: View {
    @Binding var minutes: Int
    var range: ClosedRange<Int> = 1...30
    var onChange: (() -> Void)? = nil

    var body: some View {
        GeometryReader { geometry in
            let width = max(1, geometry.size.width)
            let count = range.upperBound - range.lowerBound + 1
            let step = width / CGFloat(count)
            let selectedFraction = CGFloat(minutes - range.lowerBound) / CGFloat(max(1, count - 1))
            let selectedX = min(width - step / 2, max(step / 2, selectedFraction * width))

            ZStack(alignment: .topLeading) {
                // minute labels
                ForEach(Array(range), id: \.self) { minute in
                    if minute == 1 || minute % 5 == 0 {
                        let x = labelX(minute: minute, width: width, count: count)
                        Text("\(minute)")
                            .font(.system(size: 9, weight: .medium, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(barColor(minute: minute).opacity(0.95))
                            .fixedSize()
                            .position(x: x, y: 7)
                    }
                }

                // bars
                ForEach(Array(range), id: \.self) { minute in
                    let x = barX(minute: minute, width: width, count: count)
                    Capsule(style: .continuous)
                        .fill(barColor(minute: minute))
                        .frame(width: 3.6, height: barHeight(minute: minute))
                        .position(x: x, y: 22 + barHeight(minute: minute) / 2)
                }

                // selection marker
                Image(systemName: "triangle.fill")
                    .font(.system(size: 7, weight: .bold))
                    .foregroundStyle(VorssaintTheme.orange)
                    .rotationEffect(.degrees(180))
                    .position(x: selectedX, y: 77)
            }
            .overlay {
                MinuteRulerInteraction(range: range, current: minutes) { minute in
                    guard minute != minutes else { return }
                    minutes = minute
                    onChange?()
                }
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Timer minutes")
        .accessibilityValue("\(minutes) minutes")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: minutes = min(range.upperBound, minutes + 1)
            case .decrement: minutes = max(range.lowerBound, minutes - 1)
            @unknown default: break
            }
            onChange?()
        }
    }

    private func barX(minute: Int, width: CGFloat, count: Int) -> CGFloat {
        let step = width / CGFloat(count)
        return step * (CGFloat(minute - range.lowerBound) + 0.5)
    }

    private func labelX(minute: Int, width: CGFloat, count: Int) -> CGFloat {
        let step = width / CGFloat(count)
        let x = step * (CGFloat(minute - range.lowerBound) + 0.5)
        return min(width - 8, max(8, x))
    }

    private func barHeight(minute: Int) -> CGFloat {
        minute == range.lowerBound || minute % 5 == 0 ? 26 : 20
    }

    private func barColor(minute: Int) -> Color {
        if minute <= minutes {
            return VorssaintTheme.orange
        }
        let distance = Double(minute - minutes)
        return VorssaintTheme.orange.opacity(max(0.12, 0.45 - distance * 0.012))
    }
}

/// A transparent AppKit layer so the ruler takes the wheel and absolute
/// clicks as naturally as Vorssaint's own ruler, while SwiftUI draws it.
private struct MinuteRulerInteraction: NSViewRepresentable {
    let range: ClosedRange<Int>
    let current: Int
    let onMinute: (Int) -> Void

    func makeNSView(context: Context) -> RulerInteractionView {
        let view = RulerInteractionView()
        view.range = range
        view.currentMinute = current
        view.onMinute = onMinute
        return view
    }

    func updateNSView(_ view: RulerInteractionView, context: Context) {
        view.range = range
        view.currentMinute = current
        view.onMinute = onMinute
    }
}

private final class RulerInteractionView: NSView {
    var range: ClosedRange<Int> = 1...30
    var currentMinute = 15
    var onMinute: ((Int) -> Void)?
    private var preciseAccumulator: CGFloat = 0

    override var acceptsFirstResponder: Bool { true }

    override func scrollWheel(with event: NSEvent) {
        let count = max(1, range.upperBound - range.lowerBound + 1)
        if event.hasPreciseScrollingDeltas {
            preciseAccumulator += event.scrollingDeltaY
            let step = max(1, bounds.width / CGFloat(count) / 3)
            while abs(preciseAccumulator) >= step {
                let direction = preciseAccumulator > 0 ? 1 : -1
                preciseAccumulator -= CGFloat(direction) * step
                stepMinute(direction)
            }
        } else {
            stepMinute(event.scrollingDeltaY > 0 ? 1 : -1)
        }
    }

    override func mouseDown(with event: NSEvent) {
        updateMinute(with: event)
    }

    override func mouseDragged(with event: NSEvent) {
        updateMinute(with: event)
    }

    private func updateMinute(with event: NSEvent) {
        guard bounds.width > 0 else { return }
        let point = convert(event.locationInWindow, from: nil)
        let fraction = min(max(point.x / bounds.width, 0), 1)
        let count = range.upperBound - range.lowerBound + 1
        let index = Int((fraction * CGFloat(count)).rounded(.down))
        let minute = min(range.upperBound, range.lowerBound + index)
        onMinute?(minute)
    }

    private func stepMinute(_ direction: Int) {
        let next = min(range.upperBound, max(range.lowerBound, currentMinute + direction))
        guard next != currentMinute else { return }
        currentMinute = next
        onMinute?(next)
    }
}
