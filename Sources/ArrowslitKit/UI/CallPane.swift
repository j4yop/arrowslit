import AppKit
import SwiftUI

/// The expanded call view: who is on the call, how long, camera use, mute and hang up.
struct CallPane: View {
    @Bindable var state: AppState

    private var calls: CallMonitor { state.calls }
    private var microphone: MicrophoneMute { state.microphone }

    var body: some View {
        if let session = calls.session {
            HStack(spacing: 12) {
                artwork(session)

                VStack(alignment: .leading, spacing: 2) {
                    Text(session.appName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(ArrowTheme.bone)
                        .lineLimit(1)
                    HStack(spacing: 5) {
                        Text(session.isCall ? "On call" : "Microphone")
                        Text(session.startDate, style: .timer)
                            .monospacedDigit()
                    }
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(session.isCall ? ArrowTheme.green : ArrowTheme.amber)
                    if let message = calls.hangUpMessage {
                        Text(message)
                            .font(.system(size: 9.5))
                            .foregroundStyle(ArrowTheme.muted)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if session.usesCamera {
                    Image(systemName: "video.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(ArrowTheme.green)
                        .accessibilityLabel("Camera in use")
                }

                if microphone.canMute {
                    callButton(
                        symbol: microphone.isMuted ? "mic.slash.fill" : "mic.fill",
                        tint: microphone.isMuted ? ArrowTheme.red : ArrowTheme.amber,
                        label: microphone.isMuted ? "Unmute microphone" : "Mute microphone"
                    ) {
                        microphone.toggle()
                    }
                }

                if calls.canHangUp {
                    callButton(symbol: "phone.down.fill", tint: ArrowTheme.red, label: "Hang up") {
                        Task { @MainActor in
                            if await calls.hangUp() == .sent {
                                state.collapse()
                            }
                        }
                    }
                } else {
                    callButton(symbol: "arrow.up.forward", tint: ArrowTheme.green, label: "Show \(session.appName)") {
                        calls.showApp()
                        state.collapse()
                    }
                }
            }
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityElement(children: .contain)
        } else {
            VStack(spacing: 4) {
                Image(systemName: "phone")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(ArrowTheme.faint)
                Text("No active call")
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(ArrowTheme.muted)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder
    private func artwork(_ session: CallMonitor.Session) -> some View {
        if let icon = calls.appIcon {
            Image(nsImage: icon)
                .resizable()
                .interpolation(.high)
                .frame(width: 34, height: 34)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        } else {
            Image(systemName: session.isCall ? "phone.fill" : "mic.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(session.isCall ? ArrowTheme.green : ArrowTheme.amber)
                .frame(width: 34, height: 34)
                .background(Circle().fill(Color.white.opacity(0.08)))
        }
    }

    private func callButton(symbol: String, tint: Color, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 30, height: 30)
                .background(Circle().fill(Color.white.opacity(0.08)))
        }
        .buttonStyle(NookPressStyle())
        .nookHitSlop()
        .help(label)
        .accessibilityLabel(label)
    }
}
