import AppKit
import SwiftUI

/// The shared Timer / Pomodoro / Stopwatch panel. The minute tape follows the pointer,
/// settles on a whole minute, and gives one haptic detent per minute crossed.
struct ClockPane: View {
    @Bindable var state: AppState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var timer: TimerService { state.timer }
    private var stopwatch: StopwatchService { state.stopwatch }
    private var mode: ClockMode { state.clockMode }

    var body: some View {
        setupView
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .onAppear { syncModeToTab() }
            .onChange(of: state.activeTab) { _, _ in syncModeToTab() }
    }

    private var setupView: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                ForEach(ClockMode.allCases) { option in
                    ClockModeTab(title: option.title, isSelected: option == mode) {
                        withAnimation(
                            NookMotion.reducing(.spring(duration: 0.3, bounce: 0.2), reduceMotion: reduceMotion)
                        ) {
                            state.setClockMode(option)
                        }
                    }
                }

                Spacer(minLength: 8)

                Button("Start") { start() }
                    .buttonStyle(ClockStartButtonStyle())
                    .keyboardShortcut(.defaultAction)
            }

            HStack(alignment: .center, spacing: 16) {
                switch mode {
                case .timer:
                    SlidingRuler(range: RulerMath.timerRange, value: timer.panelMinutes) { minutes in
                        pick(minutes, current: timer.panelMinutes) { timer.panelMinutes = $0 }
                    }
                case .focus:
                    SlidingRuler(range: RulerMath.focusRange, value: timer.focusMinutes) { minutes in
                        pick(minutes, current: timer.focusMinutes) { timer.focusMinutes = $0 }
                    }
                case .stopwatch:
                    SlidingRuler(range: RulerMath.stopwatchRange, value: 0, isEnabled: false) { _ in }
                }

                VStack(alignment: .trailing, spacing: 0) {
                    Text(bigText)
                        .font(.system(size: 40, weight: .thin))
                        .monospacedDigit()
                        .foregroundStyle(ArrowTheme.amber)
                        .contentTransition(.numericText())
                        .lineLimit(1)
                        .fixedSize()
                        .animation(
                            NookMotion.reducing(.snappy(duration: 0.2), reduceMotion: reduceMotion),
                            value: bigText
                        )

                    if mode == .focus {
                        Text("then a \(timer.breakMinutes) min break")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(ArrowTheme.muted)
                            .fixedSize()
                    }
                }
                .frame(minWidth: 116, alignment: .trailing)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func start() {
        switch mode {
        case .timer:
            timer.start(minutes: timer.panelMinutes)
        case .focus:
            timer.startFocus(minutes: timer.focusMinutes)
        case .stopwatch:
            stopwatch.start()
        }
    }

    private func pick(_ minutes: Int, current: Int, set: (Int) -> Void) {
        guard minutes != current else { return }
        set(minutes)
        guard state.settings.hapticFeedback else { return }
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
    }

    private func syncModeToTab() {
        if state.activeTab == .stopwatch, state.clockMode != .stopwatch {
            state.clockMode = .stopwatch
        } else if state.activeTab == .timer, state.clockMode == .stopwatch {
            state.clockMode = .timer
        }
    }

    private var bigText: String {
        switch mode {
        case .timer: ClockFormat.clock(TimeInterval(timer.panelMinutes * 60))
        case .focus: ClockFormat.clock(TimeInterval(timer.focusMinutes * 60))
        case .stopwatch: "0:00.0"
        }
    }
}

/// The narrow running nudge: back, pause, close on the left, label and time on the right.
struct ClockRunningPane: View {
    @Bindable var state: AppState
    let mode: ClockMode

    private var timer: TimerService { state.timer }
    private var stopwatch: StopwatchService { state.stopwatch }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button {
                    state.collapse()
                } label: {
                    Image(systemName: "chevron.backward")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.85))
                        .frame(width: 24, height: 24)
                        .contentShape(Rectangle())
                }
                .buttonStyle(NookPressStyle())
                .help("Back")
                .accessibilityLabel(Text("Back"))

                Spacer()
            }
            .padding(.leading, 14)
            .frame(height: 32)

            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 360, height: 124)
        .background(ArrowTheme.ink)
        .clipShape(SlitShape(radius: 18))
        .overlay {
            SlitShape(radius: 18)
                .stroke(ArrowTheme.hairline, lineWidth: 0.5)
        }
        .shadow(color: .black.opacity(0.4), radius: 18, y: 8)
    }

    @ViewBuilder
    private var content: some View {
        switch mode {
        case .timer, .focus:
            ClockRunningClock(
                isPaused: timer.isPaused,
                label: timer.lastWasFocus ? "Pomodoro" : "Timer",
                pauseLabel: timer.isPaused ? "Resume Timer" : "Pause Timer",
                cancelLabel: "Cancel Timer",
                togglePause: { timer.togglePause() },
                cancel: {
                    timer.reset()
                    state.collapse()
                }
            ) {
                Text(ClockFormat.clock(timer.remaining, roundingUp: true))
            }
        case .stopwatch:
            ClockRunningClock(
                isPaused: !stopwatch.isRunning,
                label: "Stopwatch",
                pauseLabel: stopwatch.isRunning ? "Pause Stopwatch" : "Resume Stopwatch",
                cancelLabel: "Reset Stopwatch",
                togglePause: { stopwatch.toggle() },
                cancel: {
                    stopwatch.reset()
                    state.collapse()
                }
            ) {
                Text(ClockFormat.clock(stopwatch.elapsed, tenths: true))
            }
        }
    }
}

private struct ClockModeTab: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(isSelected ? ArrowTheme.bone : ArrowTheme.muted)
                .padding(.horizontal, 8)
                .frame(height: 28)
                .overlay(alignment: .bottom) {
                    if isSelected {
                        Capsule()
                            .fill(ArrowTheme.amber)
                            .frame(height: 2.5)
                            .padding(.horizontal, 8)
                    }
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(NookPressStyle())
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct ClockStartButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        ClockStartButtonBody(configuration: configuration)
    }

    private struct ClockStartButtonBody: View {
        let configuration: ButtonStyleConfiguration
        @Environment(\.accessibilityReduceMotion) private var reduceMotion

        var body: some View {
            configuration.label
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(ArrowTheme.amber)
                .padding(.horizontal, 22)
                .frame(height: 34)
                .background(
                    Capsule()
                        .fill(ArrowTheme.amber.opacity(configuration.isPressed ? 0.32 : 0.22))
                )
                .scaleEffect(configuration.isPressed ? 0.95 : 1)
                .animation(
                    NookMotion.reducing(.spring(duration: 0.2, bounce: 0.4), reduceMotion: reduceMotion),
                    value: configuration.isPressed
                )
        }
    }
}

private struct ClockRunningClock<Time: View>: View {
    let isPaused: Bool
    let label: String
    let pauseLabel: String
    let cancelLabel: String
    let togglePause: () -> Void
    let cancel: () -> Void
    @ViewBuilder var time: Time

    var body: some View {
        HStack(spacing: 12) {
            ClockCircleButton(
                symbol: isPaused ? "play.fill" : "pause.fill",
                size: 46,
                foreground: ArrowTheme.amber,
                background: ArrowTheme.amber.opacity(0.3),
                label: pauseLabel,
                action: togglePause
            )
            ClockCircleButton(
                symbol: "xmark",
                size: 46,
                foreground: ArrowTheme.bone.opacity(0.85),
                background: Color.white.opacity(0.08),
                label: cancelLabel,
                action: cancel
            )

            Spacer(minLength: 8)

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(label)
                    .font(.system(size: 14, weight: .medium))
                time
                    .font(.system(size: 46, weight: .thin))
                    .monospacedDigit()
                    .lineLimit(1)
                    .fixedSize()
            }
            .foregroundStyle(ArrowTheme.amber.opacity(isPaused ? 0.6 : 1))
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct ClockCircleButton: View {
    let symbol: String
    var size: CGFloat = 44
    var foreground: Color = ArrowTheme.bone
    var background: Color = Color.white.opacity(0.08)
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size * 0.4, weight: .semibold))
                .foregroundStyle(foreground)
                .frame(width: size, height: size)
                .background(Circle().fill(background))
        }
        .buttonStyle(NookPressStyle())
        .accessibilityLabel(Text(label))
    }
}

/// Minute ticks slide under a fixed pointer. The tick left of the pointer is lit, the rest
/// fade out; dragging follows the pointer and settles on a whole minute.
private struct SlidingRuler: View {
    var range: ClosedRange<Int>
    var value: Int
    var isEnabled = true
    var onChange: (Int) -> Void

    @State private var dragValue: Double?
    @State private var dragStart: Double?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let spacing: CGFloat = 14
    private let tickTop: CGFloat = 20
    private let tickHeight: CGFloat = 34

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let center = width / 2
            let shown = dragValue ?? Double(value)

            ZStack(alignment: .topLeading) {
                if let visible = RulerMath.visibleRange(
                    value: shown,
                    width: Double(width),
                    spacing: Double(spacing),
                    range: range
                ) {
                    ForEach(visible, id: \.self) { minute in
                        let x = center + CGFloat(Double(minute) - shown) * spacing
                        let lit = Double(minute) <= shown + 0.001

                        if minute % 5 == 0 {
                            Text("\(minute)")
                                .font(.system(size: 12, weight: .semibold))
                                .monospacedDigit()
                                .foregroundStyle(ArrowTheme.amber.opacity(lit ? 1 : 0.35))
                                .fixedSize()
                                .position(x: x, y: 8)
                        }

                        Capsule()
                            .fill(ArrowTheme.amber.opacity(lit ? 1 : 0.3))
                            .frame(width: 3.5, height: tickHeight)
                            .position(x: x, y: tickTop + tickHeight / 2)
                    }
                }

                Triangle()
                    .fill(ArrowTheme.amber.opacity(isEnabled ? 1 : 0.4))
                    .frame(width: 11, height: 8)
                    .position(x: center, y: tickTop + tickHeight + 10)
            }
            .mask(
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0),
                        .init(color: .black, location: 0.16),
                        .init(color: .black, location: 0.84),
                        .init(color: .clear, location: 1),
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        let start = dragStart ?? Double(value)
                        dragStart = start
                        if abs(drag.translation.width) < 2 { return }

                        let next = RulerMath.clamp(
                            start - Double(drag.translation.width / spacing),
                            to: range
                        )
                        dragValue = next
                        let minute = Int(next.rounded())
                        if minute != value { onChange(minute) }
                    }
                    .onEnded { drag in
                        defer { dragStart = nil }
                        if abs(drag.translation.width) < 2 {
                            let tapped = RulerMath.tappedMinute(
                                at: Double(drag.location.x),
                                center: Double(center),
                                current: value,
                                spacing: Double(spacing),
                                range: range
                            )
                            withAnimation(
                                NookMotion.reducing(.spring(duration: 0.45, bounce: 0.2), reduceMotion: reduceMotion)
                            ) {
                                onChange(tapped)
                            }
                            return
                        }
                        withAnimation(
                            NookMotion.reducing(.spring(duration: 0.35, bounce: 0.25), reduceMotion: reduceMotion)
                        ) {
                            dragValue = nil
                        }
                    },
                including: isEnabled ? .all : .none
            )
        }
        .frame(height: tickTop + tickHeight + 16)
        .accessibilityElement()
        .accessibilityLabel(Text("Minutes"))
        .accessibilityValue(Text("\(value)"))
        .accessibilityAdjustableAction { direction in
            guard isEnabled else { return }
            let next = direction == .increment ? value + 1 : value - 1
            onChange(min(max(next, range.lowerBound), range.upperBound))
        }
    }
}

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.midX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.closeSubpath()
        }
    }
}
