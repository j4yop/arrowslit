import CoreAudio
import SwiftUI

struct VorssaintMixerPane: View {
    @Bindable var state: AppState
    @State private var volume: Double = 0.5
    @State private var muted = false
    @State private var devices: [(id: AudioDeviceID, name: String)] = []
    @State private var selectedDevice: AudioDeviceID = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            PaneHeader("Volume mixer") {
                Button("Refresh") { refresh() }
                    .buttonStyle(.plain)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(ArrowTheme.amber)
            }

            HStack(alignment: .top, spacing: 10) {
                VorssaintCard(padding: 12) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Label("System output", systemImage: "speaker.wave.2.fill")
                                .font(.system(size: 10.5, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.65))
                            Spacer()
                            Text("\(Int((volume * 100).rounded()))%")
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(.white)
                        }
                        Slider(value: Binding(
                            get: { volume },
                            set: { value in
                                volume = value
                                AudioHW.setOutputVolume(Float(value))
                                if muted { muted = false; AudioHW.setOutputMuted(false) }
                            }
                        ), in: 0...1)
                        .tint(ArrowTheme.amber)
                        HStack(spacing: 8) {
                            Button {
                                muted.toggle()
                                AudioHW.setOutputMuted(muted)
                            } label: {
                                Image(systemName: muted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                                    .frame(width: 30, height: 26)
                                    .background(RoundedRectangle(cornerRadius: 7).fill(.white.opacity(0.08)))
                            }
                            .buttonStyle(NookPressStyle())
                            Picker("Output", selection: $selectedDevice) {
                                ForEach(devices, id: \.id) { device in
                                    Text(device.name).tag(device.id)
                                }
                            }
                            .labelsHidden()
                            .pickerStyle(.menu)
                            .onChange(of: selectedDevice) { _, id in
                                if id != 0 { _ = AudioHW.setDefaultOutputDevice(id) }
                            }
                        }
                    }
                }

                VorssaintCard(padding: 12) {
                    VStack(alignment: .leading, spacing: 9) {
                        Label("Microphone", systemImage: "mic.fill")
                            .font(.system(size: 10.5, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.65))
                        Text(state.microphone.isMuted ? "Muted for every app" : "Live input")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(state.microphone.isMuted ? ArrowTheme.red : .white)
                        Button {
                            state.microphone.toggle()
                            NookHaptics.perform(enabled: state.settings.hapticFeedback)
                        } label: {
                            Text(state.microphone.isMuted ? "Unmute microphone" : "Mute microphone")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(state.microphone.isMuted ? .white : ArrowTheme.ink)
                                .padding(.horizontal, 12)
                                .frame(height: 27)
                                .background(Capsule().fill(state.microphone.isMuted ? ArrowTheme.red : ArrowTheme.amber))
                        }
                        .buttonStyle(NookPressStyle())
                        .disabled(!state.microphone.canMute)
                        Text("Mic Mute is not a privacy lock: Siri and some apps may still hear you.")
                            .font(.system(size: 9))
                            .foregroundStyle(.white.opacity(0.38))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(width: 220)
            }
        }
        .padding(.top, 2)
        .onAppear { refresh() }
    }

    private func refresh() {
        volume = Double(AudioHW.outputVolume() ?? 0.5)
        muted = AudioHW.outputMuted()
        selectedDevice = AudioHW.defaultOutputDevice()
        devices = AudioHW.outputDevices().compactMap { id in
            guard let name = AudioHW.deviceName(id) else { return nil }
            return (id, name)
        }
    }
}
