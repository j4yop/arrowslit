import SwiftUI

struct StopwatchPane: View {
    @Bindable var state: AppState

    var body: some View {
        VStack(spacing: 14) {
            Text(ClockFormat.clock(state.stopwatch.elapsed, tenths: true))
                .font(.system(size: 48, weight: .light, design: .monospaced))
                .foregroundStyle(ArrowTheme.bone)
                .monospacedDigit()

            HStack(spacing: 8) {
                Button(state.stopwatch.isRunning ? "Pause" : "Start") {
                    state.stopwatch.toggle()
                }
                .buttonStyle(NookPressStyle())
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(ArrowTheme.ink)
                .padding(.horizontal, 14)
                .frame(height: 30)
                .background(Capsule().fill(ArrowTheme.amber))

                Button("Reset") {
                    state.stopwatch.reset()
                }
                .buttonStyle(NookPressStyle())
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(ArrowTheme.bone)
                .padding(.horizontal, 14)
                .frame(height: 30)
                .background(Capsule().fill(Color.white.opacity(0.08)))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct KeepAwakePane: View {
    @Bindable var state: AppState

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "cup.and.saucer.fill")
                .font(.system(size: 30, weight: .light))
                .foregroundStyle(state.keepAwake.isOn ? ArrowTheme.amber : ArrowTheme.faint)
            Text(state.keepAwake.isOn ? "This Mac stays awake." : "Keep this Mac awake.")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(ArrowTheme.bone)
            Text("Display sleep is still allowed.")
                .font(.system(size: 10))
                .foregroundStyle(ArrowTheme.faint)
            Button(state.keepAwake.isOn ? "Turn Off" : "Turn On") {
                state.keepAwake.toggle()
            }
            .buttonStyle(NookPressStyle())
            .font(.system(size: 10.5, weight: .semibold))
            .foregroundStyle(ArrowTheme.ink)
            .padding(.horizontal, 14)
            .frame(height: 28)
            .background(Capsule().fill(ArrowTheme.amber))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
