import AppKit
import CoreAudio
import SwiftUI

/// The real Vorssaint per-app mixer, narrowed to Arrowslit's page size.
/// Each app gets a live gain fader, mute and its own output route; the system
/// output stays as the master column.
struct VorssaintMixerPane: View {
    @Bindable var state: AppState
    @StateObject private var mixer = AppVolumeMixer.shared
    @State private var editing: String?
    @State private var editingText = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            PaneHeader("Volume mixer") {
                HStack(spacing: 7) {
                    if !mixer.outputDevices.isEmpty {
                        Picker("Output", selection: Binding(
                            get: { mixer.currentOutputDeviceUID ?? "" },
                            set: { uid in if !uid.isEmpty { _ = mixer.setSystemSoundOutputDeviceUID(uid) } }
                        )) {
                            ForEach(mixer.outputDevices) { device in
                                Text(device.name).tag(device.uid)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .controlSize(.mini)
                    }
                    Button("Refresh") { mixer.refreshApps() }
                        .buttonStyle(.plain)
                        .font(.system(size: 9.5, weight: .semibold))
                        .foregroundStyle(ArrowTheme.amber)
                }
            }

            if !AppVolumeMixer.isSupported {
                VorssaintPageEmpty(symbol: "speaker.slash", title: "Audio taps unavailable",
                                   detail: "Per-app volume needs macOS 14.4 or newer.")
            } else if mixer.needsPermission {
                permission
            } else if mixer.apps.isEmpty {
                VorssaintPageEmpty(symbol: "speaker.wave.2", title: "Nothing is playing",
                                   detail: "Start audio in an app and it appears here with its own fader.")
            } else {
                HStack(alignment: .top, spacing: 8) {
                    master
                    Rectangle().fill(.white.opacity(0.1)).frame(width: 1)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(alignment: .top, spacing: 7) {
                            ForEach(mixer.apps) { app in
                                appFader(app)
                            }
                        }
                    }
                }
            }
        }
        .padding(.top, 2)
        .onAppear {
            mixer.syncWithPreferences()
            mixer.refreshApps()
        }
    }

    private var permission: some View {
        VStack(spacing: 8) {
            Image(systemName: "waveform.badge.exclamationmark")
                .font(.system(size: 25, weight: .light))
                .foregroundStyle(.white.opacity(0.6))
            Text("System Audio Recording is needed to control apps separately.")
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.55))
                .multilineTextAlignment(.center)
            Button("Open System Settings") {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
                    NSWorkspace.shared.open(url)
                }
            }
            .buttonStyle(.plain)
            .font(.system(size: 9.5, weight: .semibold))
            .foregroundStyle(ArrowTheme.amber)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var master: some View {
        VStack(spacing: 5) {
            Button {
                if let muted = mixer.systemOutputMuted {
                    mixer.requestOutputAdjustment(muted: !muted)
                }
            } label: {
                Image(systemName: mixer.systemOutputMuted == true ? "speaker.slash.fill" : "speaker.wave.2.fill")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(mixer.systemOutputMuted == true ? ArrowTheme.red : .white)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(NookPressStyle(pressedScale: 0.94))
            Text("System")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.white.opacity(0.5))
            VorssaintLevelSlider(
                value: mixer.systemOutputVolume ?? 0,
                range: 0...1,
                tint: .white
            ) { mixer.requestOutputAdjustment(volume: $0) }
            Text("\(Int(((mixer.systemOutputVolume ?? 0) * 100).rounded()))%")
                .font(.system(size: 9, weight: .medium, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white.opacity(0.55))
        }
        .frame(width: 62)
    }

    private func appFader(_ app: MixerApp) -> some View {
        VStack(spacing: 5) {
            ZStack {
                if let icon = NSRunningApplication(processIdentifier: app.ownerPid)?.icon {
                    Image(nsImage: icon)
                        .resizable()
                        .interpolation(.high)
                        .frame(width: 26, height: 26)
                } else {
                    Image(systemName: "app")
                        .font(.system(size: 18))
                }
            }
            .frame(width: 28, height: 28)
            Text(app.name)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.white.opacity(0.72))
                .lineLimit(1)
                .frame(width: 72)
            VorssaintLevelSlider(
                value: app.volume,
                range: 0...AppVolumeMixer.maxVolume,
                tint: app.volume > 1 ? ArrowTheme.amber : .white
            ) { mixer.setVolume($0, for: app) }
            if editing == app.id {
                TextField("", text: $editingText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 9, weight: .medium))
                    .multilineTextAlignment(.center)
                    .frame(width: 42, height: 16)
                    .background(RoundedRectangle(cornerRadius: 4).fill(.white.opacity(0.1)))
                    .onSubmit { commit(app) }
            } else {
                Text("\(Int((app.volume * 100).rounded()))%")
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(app.volume > 1 ? ArrowTheme.amber : .white.opacity(0.5))
                    .onTapGesture {
                        editing = app.id
                        editingText = "\(Int((app.volume * 100).rounded()))"
                    }
            }
            HStack(spacing: 4) {
                Button {
                    mixer.toggleMute(app)
                } label: {
                    Image(systemName: app.volume == 0 ? "speaker.slash.fill" : "speaker.wave.2.fill")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(app.volume == 0 ? ArrowTheme.red : .white.opacity(0.55))
                }
                .buttonStyle(.plain)
                if !mixer.outputDevices.isEmpty {
                    Menu {
                        ForEach(mixer.outputDevices) { device in
                            Button(device.name) {
                                mixer.setOutputDeviceUID(device.uid, for: app)
                            }
                        }
                        Divider()
                        Button("Follow system") { mixer.setOutputDeviceUID(nil, for: app) }
                    } label: {
                        Image(systemName: "hifispeaker")
                            .font(.system(size: 8, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.45))
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                }
            }
        }
        .padding(7)
        .frame(width: 82)
        .background(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(Color.white.opacity(0.055))
        )
        .opacity(app.isPlaying ? 1 : 0.62)
        .help(app.name)
    }

    private func commit(_ app: MixerApp) {
        if let percent = Double(editingText.trimmingCharacters(in: .whitespaces)) {
            mixer.setVolume(min(max(percent / 100, 0), AppVolumeMixer.maxVolume), for: app)
        }
        editing = nil
    }
}

/// A compact vertical fader for the mixer columns.
private struct VorssaintLevelSlider: View {
    let value: Double
    let range: ClosedRange<Double>
    let tint: Color
    let onChange: (Double) -> Void

    var body: some View {
        GeometryReader { geometry in
            let height = max(28, geometry.size.height)
            let fraction = (value - range.lowerBound) / (range.upperBound - range.lowerBound)
            ZStack(alignment: .bottom) {
                Capsule()
                    .fill(.white.opacity(0.12))
                    .frame(width: 4)
                Capsule()
                    .fill(tint.opacity(0.85))
                    .frame(width: 4, height: max(3, height * fraction))
                Circle()
                    .fill(.white)
                    .frame(width: 11, height: 11)
                    .offset(y: -max(0, height * fraction - 5))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        let ratio = 1 - min(max(gesture.location.y / height, 0), 1)
                        onChange(range.lowerBound + ratio * (range.upperBound - range.lowerBound))
                    }
            )
            .accessibilityElement()
            .accessibilityLabel("Volume")
            .accessibilityValue("\(Int((value * 100).rounded())) percent")
            .accessibilityAdjustableAction { direction in
                let step = (range.upperBound - range.lowerBound) / 20
                switch direction {
                case .increment: onChange(min(range.upperBound, value + step))
                case .decrement: onChange(max(range.lowerBound, value - step))
                @unknown default: break
                }
            }
        }
        .frame(height: 66)
    }
}
