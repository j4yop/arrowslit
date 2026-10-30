import SwiftUI

struct TimerPane: View {
    @Bindable var state: AppState

    private var timer: TimerService { state.timer }
    private var shownSeconds: TimeInterval {
        if timer.countdown == nil { return TimeInterval(timer.lastMinutes * 60) }
        return timer.remaining
    }

    private var status: String {
        if timer.justFinished { return "Complete" }
        if timer.isPaused { return "Paused" }
        if timer.isActive { return "Running" }
        return "Ready"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(status)
                        .font(ArrowTheme.label)
                        .foregroundStyle(timer.isActive ? ArrowTheme.amber : ArrowTheme.muted)
                    Text(ClockFormat.clock(shownSeconds, roundingUp: true))
                        .font(.system(size: 62, weight: .light))
                        .monospacedDigit()
                        .foregroundStyle(timer.justFinished ? ArrowTheme.amber : ArrowTheme.bone)
                        .contentTransition(.numericText())
                        .lineLimit(1)
                }

                Spacer(minLength: 16)

                VStack(alignment: .trailing, spacing: 4) {
                    Text("Session")
                        .font(ArrowTheme.detail)
                        .foregroundStyle(ArrowTheme.muted)
                    Text("\(timer.lastMinutes) min")
                        .font(.system(size: 13, weight: .medium))
                        .monospacedDigit()
                        .foregroundStyle(ArrowTheme.bone)
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
                .font(.system(size: 11, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(isSelected ? ArrowTheme.ink : ArrowTheme.bone.opacity(0.8))
                .frame(width: 54, height: 30)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(isSelected ? ArrowTheme.amber : Color.white.opacity(0.06))
                )
                .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
        .buttonStyle(NookPressStyle())
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
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(filled ? ArrowTheme.amber : Color.white.opacity(0.07))
            )
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(NookPressStyle())
    }
}
