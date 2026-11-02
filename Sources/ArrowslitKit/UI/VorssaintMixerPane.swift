import AppKit
import CoreAudio
import SwiftUI

/// Vorssaint's mixer desk: the output column on the left, one capsule fader
/// per app running sideways, and the output device over the desk. Each app
/// column carries its icon, menu, boost level and mute exactly as the
/// reference island does.
struct VorssaintMixerPane: View {
    @Bindable var state: AppState
    @StateObject private var mixer = AppVolumeMixer.shared
    @State private var showingOptions = false

    private let masterWidth: CGFloat = 64
    private let columnWidth: CGFloat = 92
    private let faderHeight: CGFloat = 84

    private var deviceName: String {
        mixer.outputDevices.first(where: { $0.uid == mixer.currentOutputDeviceUID })?.name
            ?? "Output unavailable"
    }

    var body: some View {
        VStack(spacing: 6) {
            topRow
            if showingOptions {
                options
            } else if !AppVolumeMixer.isSupported {
                VorssaintPageEmpty(symbol: "speaker.slash", title: "Audio taps unavailable",
                                   detail: "Per-app volume needs macOS 14.4 or newer.")
            } else if mixer.needsPermission {
                permission
            } else if mixer.apps.isEmpty {
                VorssaintPageEmpty(symbol: "speaker.wave.2", title: "Nothing is playing",
                                   detail: "Start audio in an app and it appears here with its own fader.")
            } else {
                desk
            }
        }
        .padding(.top, 1)
        .onAppear {
            mixer.syncWithPreferences()
            mixer.refreshApps()
        }
    }

    private var topRow: some View {
        HStack(spacing: 8) {
            Menu {
                ForEach(mixer.outputDevices.filter(\.canBeDefaultOutput)) { device in
                    Button {
                        _ = mixer.setUniversalOutputDeviceUID(device.uid)
                    } label: {
                        if device.uid == mixer.currentOutputDeviceUID {
                            Label(device.name, systemImage: "checkmark")
                        } else {
                            Text(device.name)
                        }
                    }
                }
                Divider()
                Button("Refresh") { mixer.refreshApps() }
            } label: {
                HStack(spacing: 5) {
                    Text(deviceName)
                        .font(.system(size: 11.5, weight: .medium))
                        .lineLimit(1)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white.opacity(0.5))
                }
                .foregroundStyle(.white.opacity(0.82))
                .contentShape(Rectangle())
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .help("System output")

            Spacer(minLength: 8)

            Button {
                withAnimation(.easeOut(duration: 0.18)) { showingOptions.toggle() }
            } label: {
                Image(systemName: showingOptions ? "xmark" : "slider.horizontal.3")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(showingOptions ? 1 : 0.62))
                    .frame(width: 24, height: 22)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(showingOptions ? Color.white.opacity(0.12) : .clear)
                    )
            }
            .buttonStyle(NookPressStyle(pressedScale: 0.94))
            .help(showingOptions ? "Close options" : "Mixer options")
        }
        .frame(height: 22)
    }

    private var desk: some View {
        HStack(alignment: .top, spacing: 10) {
            master
                .frame(width: masterWidth)
            Rectangle()
                .fill(.white.opacity(0.12))
                .frame(width: 1, height: faderHeight + 58)
                .padding(.top, 2)
                .accessibilityHidden(true)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 8) {
                    ForEach(mixer.apps) { app in
                        if app.isBypassed {
                            bypassed(app)
                                .frame(width: columnWidth)
                        } else {
                            appFader(app)
                                .frame(width: columnWidth)
                        }
                    }
                }
                .padding(.trailing, 4)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var master: some View {
        let level = mixer.systemOutputVolume.map { mixer.systemOutputMuted == true ? 0 : $0 } ?? 0
        let muted = mixer.systemOutputMuted == true
        return VStack(spacing: 6) {
            Button {
                if let muted = mixer.systemOutputMuted {
                    mixer.requestOutputAdjustment(muted: !muted)
                }
            } label: {
                Image(systemName: muted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(muted ? VorssaintTheme.red : .white)
                    .frame(width: 30, height: 30)
                    .contentShape(Circle())
            }
            .buttonStyle(NookPressStyle(pressedScale: 0.92))
            .help(muted ? "Unmute" : "Mute")

            VorssaintCapsuleFader(
                value: level,
                maximum: 1,
                tint: .white,
                unity: nil
            ) { mixer.requestOutputAdjustment(volume: $0) }
            .frame(width: 30, height: faderHeight)

            Text("\(Int((level * 100).rounded()))%")
                .font(.system(size: 10.5, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(.white.opacity(0.48))
                .frame(height: 20)
        }
        .frame(height: faderHeight + 58, alignment: .top)
    }

    private func appFader(_ app: MixerApp) -> some View {
        VStack(spacing: 6) {
            HStack(spacing: 3) {
                appIcon(app)
                appMenu(app)
            }
            .frame(height: 36)

            VorssaintCapsuleFader(
                value: app.volume,
                maximum: AppVolumeMixer.maxVolume,
                tint: VorssaintTheme.orange,
                unity: 1
            ) { mixer.setVolume($0, for: app) }
            .frame(width: 30, height: faderHeight)

            footer(app)
                .frame(height: 20)
        }
        .frame(height: faderHeight + 58, alignment: .top)
        .help(app.name)
    }

    private func appIcon(_ app: MixerApp) -> some View {
        ZStack(alignment: .bottomTrailing) {
            Image(nsImage: ResponsibleProcess.icon(for: app.ownerPid, pointSize: 40))
                .resizable()
                .interpolation(.high)
                .frame(width: 36, height: 36)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            if app.isPlaying {
                Circle()
                    .fill(VorssaintTheme.green)
                    .frame(width: 6, height: 6)
                    .overlay(Circle().stroke(.black, lineWidth: 2))
                    .offset(x: 1, y: 1)
            }
        }
        .frame(width: 38, height: 36)
    }

    private func appMenu(_ app: MixerApp) -> some View {
        Menu {
            Button(app.volume <= 0.001 ? "Unmute" : "Mute") { mixer.toggleMute(app) }
            Button("Reset to 100%") { mixer.setVolume(1, for: app) }
            Divider()
            Section("Output") {
                Button {
                    mixer.setOutputDeviceUID(nil, for: app)
                } label: {
                    if app.selectedOutputDeviceUID == nil {
                        Label("Follow system", systemImage: "checkmark")
                    } else {
                        Text("Follow system")
                    }
                }
                ForEach(mixer.outputDevices.filter(\.canBeDefaultOutput)) { device in
                    Button {
                        mixer.setOutputDeviceUID(device.uid, for: app)
                    } label: {
                        if app.selectedOutputDeviceUID == device.uid {
                            Label(device.name, systemImage: "checkmark")
                        } else {
                            Text(device.name)
                        }
                    }
                }
            }
            Divider()
            Button("Hide from mixer") { mixer.hideFromList(app) }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.38))
                .frame(width: 16, height: 24)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .help("\(app.name) options")
    }

    private func footer(_ app: MixerApp) -> some View {
        let percent = MixerRoutingSupport.displayPercent(forVolume: app.volume)
        let boosting = percent > 100
        let muted = app.volume <= 0.001
        return HStack(spacing: 3) {
            Button {
                mixer.setVolume(1, for: app)
            } label: {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 8.5, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.36))
            }
            .buttonStyle(.plain)
            .help("Reset to 100%")

            HStack(spacing: 1) {
                if boosting {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 7, weight: .bold))
                }
                Text("\(percent)%")
                    .font(.system(size: 9.5, weight: .medium))
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }
            .foregroundStyle(boosting ? VorssaintTheme.orange : .white.opacity(0.5))
            .lineLimit(1)
            .minimumScaleFactor(0.8)

            Button {
                mixer.toggleMute(app)
            } label: {
                Image(systemName: muted ? "speaker.slash.fill" : "speaker.wave.1.fill")
                    .font(.system(size: 8.5, weight: .semibold))
                    .foregroundStyle(muted ? VorssaintTheme.red : .white.opacity(0.36))
            }
            .buttonStyle(.plain)
        }
    }

    private func bypassed(_ app: MixerApp) -> some View {
        VStack(spacing: 6) {
            HStack(spacing: 3) {
                appIcon(app)
                appMenu(app)
            }
            .frame(height: 36)
            Text("This app manages its own audio.")
                .font(.system(size: 9.5))
                .foregroundStyle(.white.opacity(0.42))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(height: faderHeight + 58, alignment: .top)
    }

    private var permission: some View {
        VStack(spacing: 8) {
            Image(systemName: "waveform.badge.exclamationmark")
                .font(.system(size: 24, weight: .light))
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
            .foregroundStyle(VorssaintTheme.orange)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var options: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 4) {
                optionsRow("System output", symbol: "speaker.wave.2") {
                    Text(deviceName)
                        .font(.system(size: 10.5))
                        .foregroundStyle(.white.opacity(0.55))
                        .lineLimit(1)
                }
                ForEach(mixer.outputDevices.filter(\.canBeDefaultOutput)) { device in
                    Button {
                        _ = mixer.setUniversalOutputDeviceUID(device.uid)
                    } label: {
                        HStack {
                            Text(device.name)
                                .font(.system(size: 10.5))
                                .foregroundStyle(.white.opacity(0.82))
                            Spacer()
                            if device.uid == mixer.currentOutputDeviceUID {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(VorssaintTheme.orange)
                            }
                        }
                        .padding(.horizontal, PointSize.optionInset)
                        .frame(height: PointSize.optionRow)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                Divider().overlay(.white.opacity(0.1))
                optionsRow("Refresh app list", symbol: "arrow.clockwise") {
                    Button("Refresh") { mixer.refreshApps() }
                        .buttonStyle(.plain)
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundStyle(VorssaintTheme.orange)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func optionsRow<Trailing: View>(_ title: String, symbol: String,
                                            @ViewBuilder trailing: () -> Trailing) -> some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(.white.opacity(0.42))
                .frame(width: 16)
            Text(title)
                .font(.system(size: 10.5))
                .foregroundStyle(.white.opacity(0.55))
            Spacer(minLength: 4)
            trailing()
        }
        .frame(height: PointSize.optionRow)
    }

    private enum PointSize {
        static let optionRow: CGFloat = 24
        static let optionInset: CGFloat = 24
    }
}

/// The reference fader: a 30-point capsule whose fill rises from the bottom,
/// with a hairline at unity and an untinted cap above the fill. Dragging is
/// absolute, so a click jumps to that level as it does in Vorssaint.
private struct VorssaintCapsuleFader: View {
    let value: Double
    let maximum: Double
    let tint: Color
    let unity: Double?
    let onChange: (Double) -> Void

    var body: some View {
        GeometryReader { geometry in
            let height = max(1, geometry.size.height)
            let fraction = min(max(value / maximum, 0), 1)
            ZStack(alignment: .bottom) {
                Capsule(style: .continuous)
                    .fill(Color(white: 0.13))
                Capsule(style: .continuous)
                    .fill(tint)
                    .frame(height: max(0, height * fraction))
                if let unity, maximum > 0 {
                    Rectangle()
                        .fill(.white.opacity(0.55))
                        .frame(height: 0.75)
                        .offset(y: -max(0, height * (unity / maximum) - 0.4))
                }
            }
            .clipShape(Capsule(style: .continuous))
            .contentShape(Capsule(style: .continuous))
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        let ratio = 1 - min(max(gesture.location.y / height, 0), 1)
                        onChange(maximum * ratio)
                    }
            )
            .accessibilityElement()
            .accessibilityLabel("Volume")
            .accessibilityValue("\(Int((value * 100).rounded())) percent")
            .accessibilityAdjustableAction { direction in
                let step = maximum / 20
                switch direction {
                case .increment: onChange(min(maximum, value + step))
                case .decrement: onChange(max(0, value - step))
                @unknown default: break
                }
            }
        }
    }
}
