import SwiftUI

struct TimerPane: View {
    @Bindable var state: AppState

    private var timer: TimerService { state.timer }
    private var shownSeconds: TimeInterval {
        if timer.countdown == nil { return TimeInterval(timer.lastMinutes * 60) }
        return timer.remaining
    }

    private var status: String {
        if timer.justFinished { return "COMPLETE" }
        if timer.isPaused { return "PAUSED" }
        if timer.isActive { return "RUNNING" }
        return "READY"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(status)
                        .font(.system(size: 9, weight: .bold))
                        .tracking(1.4)
                        .foregroundStyle(timer.isActive ? ArrowTheme.amber : ArrowTheme.faint)
                    Text(ClockFormat.clock(shownSeconds, roundingUp: true))
                        .font(.system(size: 62, weight: .light, design: .monospaced))
                        .foregroundStyle(timer.justFinished ? ArrowTheme.amber : ArrowTheme.bone)
                        .contentTransition(.numericText())
                        .lineLimit(1)
                }

                Spacer(minLength: 16)

                VStack(alignment: .trailing, spacing: 6) {
                    Text("FOCUS WINDOW")
                        .font(.system(size: 8, weight: .bold))
                        .tracking(1.2)
                        .foregroundStyle(ArrowTheme.faint)
                    Text("\(timer.lastMinutes) MIN")
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundStyle(ArrowTheme.muted)
                }
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.07))
                    Capsule()
                        .fill(ArrowTheme.amber)
                        .frame(width: max(4, geometry.size.width * CGFloat(timer.progress)))
                }
            }
            .frame(height: 4)

            HStack(spacing: 8) {
                ForEach([5, 10, 25, 50], id: \.self) { minutes in
                    PresetButton(
                        label: ClockFormat.presetLabel(minutes: minutes),
                        isSelected: timer.lastMinutes == minutes && !timer.isActive
                    ) {
                        state.startTimer(minutes: minutes)
                    }
                }
                Spacer(minLength: 0)
            }

            HStack(spacing: 10) {
                if timer.isActive {
                    ActionButton(
                        title: timer.isPaused ? "Resume" : "Pause",
                        symbol: timer.isPaused ? "play.fill" : "pause.fill",
                        filled: true
                    ) {
                        state.toggleTimer()
                    }
                    ActionButton(title: "Reset", symbol: "arrow.counterclockwise", filled: false) {
                        state.resetTimer()
                    }
                } else {
                    ActionButton(title: "Start \(timer.lastMinutes)m", symbol: "play.fill", filled: true) {
                        state.startTimer(minutes: timer.lastMinutes)
                    }
                    if timer.justFinished {
                        ActionButton(title: "Clear", symbol: "xmark", filled: false) {
                            timer.acknowledgeFinish()
                            state.resetTimer()
                        }
                    }
                }
                Spacer()
                Text("The timer keeps running when Arrowslit is closed.")
                    .font(.system(size: 10))
                    .foregroundStyle(ArrowTheme.faint)
            }
        }
        .padding(.top, 2)
    }
}

private struct PresetButton: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(isSelected ? ArrowTheme.ink : ArrowTheme.bone.opacity(0.8))
                .frame(width: 54, height: 30)
                .background(
                    Capsule().fill(isSelected ? ArrowTheme.amber : Color.white.opacity(0.06))
                )
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

private struct ActionButton: View {
    let title: String
    let symbol: String
    let filled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: symbol).font(.system(size: 10, weight: .bold))
                Text(title).font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(filled ? ArrowTheme.ink : ArrowTheme.bone.opacity(0.85))
            .padding(.horizontal, 16)
            .frame(height: 34)
            .background(
                Capsule().fill(filled ? ArrowTheme.amber : Color.white.opacity(0.07))
            )
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
