import SwiftUI
import UniformTypeIdentifiers

struct ArrowslitRootView: View {
    @Bindable var state: AppState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let geometry = ScreenReader.current
        let presentation = state.presentation
        let size = NotchPanelMetrics.size(for: presentation, geometry: geometry)

        ZStack(alignment: .top) {
            switch presentation {
            case .alert(let alert):
                NotchAlertView(state: state, alert: alert)
                    .transition(.opacity.combined(with: .scale(scale: 0.99, anchor: .top)))
            case .expanded(.nowPlaying):
                NowPlayingPlayerView(state: state)
                    .transition(.opacity.combined(with: .scale(scale: 0.99, anchor: .top)))
            case .expanded:
                NookView(state: state)
                    .transition(.opacity.combined(with: .scale(scale: 0.99, anchor: .top)))
            case .compact, .hud:
                CompactBar(
                    state: state,
                    width: geometry.compactWidth,
                    notchWidth: geometry.notchWidth,
                    hud: presentation.hudAlert
                )
                .transition(.opacity)
            }
        }
        .frame(width: size.width, height: size.height, alignment: .top)
        .animation(NookMotion.reducing(NookMotion.open, reduceMotion: reduceMotion), value: presentation)
        .environment(\.colorScheme, .dark)
    }
}

/// The closed strip. Everything is laid out in the two ears beside the camera
/// housing, so nothing can disappear under the notch on any Mac.
private struct CompactBar: View {
    @Bindable var state: AppState
    let width: CGFloat
    let notchWidth: CGFloat
    var hud: NotchAlert?
    @State private var isDropTargeted = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var ear: CGFloat { max(0, (width - notchWidth) / 2) }

    private var isLiveClock: Bool {
        if state.timer.isActive || state.timer.justFinished { return false }
        if state.nowPlaying.isVisible,
           let title = state.nowPlaying.track?.title,
           !title.isEmpty { return false }
        return true
    }

    private var musicTrack: NowPlayingTrack? {
        guard state.nowPlaying.isVisible, let track = state.nowPlaying.track, track.hasContent else { return nil }
        return track
    }

    var body: some View {
        HStack(spacing: 0) {
            if let hud {
                hudContent(hud)
                    .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .top)))
            } else if let track = musicTrack {
                compactArtwork
                    .padding(.leading, 10)
                    .frame(width: ear, alignment: .leading)

                Color.clear
                    .frame(width: notchWidth)

                MusicBars(
                    isPlaying: track.isPlaying,
                    color: state.nowPlaying.accent.color,
                    height: 15,
                    width: 20
                )
                .padding(.trailing, 10)
                .frame(width: ear, alignment: .trailing)
            } else if state.compactCharging {
                HStack(spacing: 5) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(ArrowTheme.green)
                    Text("\(state.system.batteryLevel)%")
                        .font(.system(size: 13, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(ArrowTheme.bone)
                        .lineLimit(1)
                }
                .padding(.leading, 12)
                .frame(width: ear, alignment: .leading)

                Color.clear
                    .frame(width: notchWidth)

                Text("Charging")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(ArrowTheme.green)
                    .padding(.trailing, 10)
                    .frame(width: ear, alignment: .trailing)
            } else {
                HStack(spacing: 7) {
                    SlitMark(height: 14)
                }
                .padding(.leading, 12)
                .frame(width: ear, alignment: .leading)

                Color.clear
                    .frame(width: notchWidth)

                HStack(spacing: 5) {
                    compactValue

                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(ArrowTheme.bone.opacity(0.6))
                        .frame(width: 10)
                        .accessibilityHidden(true)
                }
                .padding(.trailing, 8)
                .frame(width: ear, alignment: .trailing)
            }
        }
        .frame(width: width, height: 32)
        .animation(NookMotion.reducing(NookMotion.quick, reduceMotion: reduceMotion), value: hud)
        .background(ArrowTheme.ink)
        .clipShape(SlitShape(radius: 12))
        .overlay {
            SlitShape(radius: 12)
                .stroke(isDropTargeted ? Color(red: 0.20, green: 0.55, blue: 1) : ArrowTheme.hairline, lineWidth: isDropTargeted ? 1.5 : 0.5)
                .animation(NookMotion.reducing(NookMotion.hover, reduceMotion: reduceMotion), value: isDropTargeted)
        }
        .contentShape(SlitShape(radius: 12))
        .onTapGesture { state.expandDefault() }
        .onDrop(of: [.fileURL, .url], isTargeted: $isDropTargeted) { providers in
            Task { @MainActor in
                let urls = await FileDrop.urls(from: providers)
                if state.tray.add(urls) > 0 {
                    state.expand(.tray)
                }
            }
            return true
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(.isButton)
    }

    @ViewBuilder
    private func hudContent(_ alert: NotchAlert) -> some View {
        switch alert {
        case .level(let kind, let value, let muted):
            HUDLevelRow(kind: kind, value: value, muted: muted, ear: ear, notchWidth: notchWidth)
        case .charging(let level, let isCharging):
            HUDStatusRow(
                symbol: "bolt.fill",
                tint: ArrowTheme.green,
                title: isCharging ? "Charging" : "Connected",
                detail: "\(level)%",
                pulses: true,
                ear: ear,
                notchWidth: notchWidth
            )
        case .lowBattery(let level):
            HUDStatusRow(
                symbol: level <= 10 ? "battery.0" : "battery.25",
                tint: ArrowTheme.red,
                title: "Low Battery",
                detail: "\(level)%",
                pulses: true,
                ear: ear,
                notchWidth: notchWidth
            )
        case .headphones(let name):
            HUDStatusRow(
                symbol: "headphones",
                tint: ArrowTheme.green,
                title: "Connected",
                detail: name,
                pulses: false,
                ear: ear,
                notchWidth: notchWidth
            )
        default:
            EmptyView()
        }
    }

    @ViewBuilder
    private var compactArtwork: some View {
        Group {
            if let artwork = state.nowPlaying.artwork {
                Image(nsImage: artwork)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fill)
            } else {
                SlitMark(height: 14)
            }
        }
        .frame(width: 26, height: 26)
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
    }

    @ViewBuilder
    private var compactValue: some View {
        if isLiveClock {
            TimelineView(.everyMinute) { context in
                timeText(ClockFormat.wallClockIST(context.date), color: ArrowTheme.bone)
            }
        } else {
            timeText(
                state.compactValue,
                color: state.timer.isActive ? ArrowTheme.amber : ArrowTheme.bone
            )
        }
    }

    private func timeText(_ value: String, color: Color) -> some View {
        Text(value)
            .font(.system(size: 13, weight: .semibold))
            .monospacedDigit()
            .foregroundStyle(color)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .truncationMode(.tail)
            .frame(width: max(24, ear - 27), alignment: .trailing)
    }

    private var accessibilityLabel: String {
        if let hud {
            switch hud {
            case .level(let kind, let value, let muted):
                let name = kind == .volume ? "Volume" : "Brightness"
                return muted ? "Arrowslit. \(name) muted" : "Arrowslit. \(name) \(Int((value * 100).rounded())) percent"
            case .charging(let level, let isCharging):
                return "Arrowslit. \(isCharging ? "Charging" : "Connected") \(level) percent"
            case .lowBattery(let level):
                return "Arrowslit. Low battery \(level) percent"
            case .headphones(let name):
                return "Arrowslit. Headphones connected. \(name)"
            default:
                break
            }
        }
        if let track = musicTrack {
            return "Arrowslit. Now playing \(track.title) by \(track.artist)"
        }
        if state.compactCharging {
            return "Arrowslit. Charging \(state.system.batteryLevel) percent"
        }
        return state.compactLabel == "Ready"
            ? "Arrowslit. \(state.compactValue)"
            : "Arrowslit. \(state.compactLabel) \(state.compactValue)"
    }
}

private struct HUDLevelRow: View {
    let kind: NotchAlert.LevelKind
    let value: Double
    let muted: Bool
    let ear: CGFloat
    let notchWidth: CGFloat

    var body: some View {
        HStack(spacing: 0) {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(ArrowTheme.bone)
                .contentTransition(.symbolEffect(.replace))
                .padding(.leading, 12)
                .frame(width: ear, alignment: .leading)

            Color.clear
                .frame(width: notchWidth)

            HUDLevelBar(value: muted ? 0 : value, muted: muted)
                .padding(.horizontal, 10)
                .frame(width: ear, alignment: .trailing)
        }
    }

    private var symbol: String {
        switch kind {
        case .volume: muted ? "speaker.slash.fill" : "speaker.wave.2.fill"
        case .brightness: "sun.max"
        }
    }
}

private struct HUDLevelBar: View {
    let value: Double
    let muted: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geometry in
            let width = max(0, geometry.size.width)
            let level = min(max(value, 0), 1)
            let fill = width * level
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.18))
                    .frame(height: 6)

                if !muted {
                    Capsule()
                        .fill(ArrowTheme.bone)
                        .frame(width: fill, height: 6)

                    Capsule()
                        .fill(ArrowTheme.bone)
                        .frame(width: 12, height: 14)
                        .offset(x: min(max(0, fill - 6), max(0, width - 12)))
                }
            }
            .frame(width: width, height: geometry.size.height, alignment: .leading)
            .animation(
                NookMotion.reducing(.smooth(duration: 0.16), reduceMotion: reduceMotion),
                value: value
            )
        }
        .frame(height: 14)
    }
}

private struct HUDStatusRow: View {
    let symbol: String
    let tint: Color
    let title: String
    let detail: String
    let pulses: Bool
    let ear: CGFloat
    let notchWidth: CGFloat

    var body: some View {
        HStack(spacing: 0) {
            HUDSymbol(symbol: symbol, tint: tint, pulses: pulses)
                .padding(.leading, 12)
                .frame(width: ear, alignment: .leading)

            Color.clear
                .frame(width: notchWidth)

            VStack(alignment: .trailing, spacing: 1) {
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(tint)
                    .lineLimit(1)
                Text(detail)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(ArrowTheme.muted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .padding(.trailing, 10)
            .frame(width: ear, alignment: .trailing)
        }
    }
}

private struct HUDSymbol: View {
    let symbol: String
    let tint: Color
    let pulses: Bool
    @State private var pulsing = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(tint)
            .scaleEffect(pulsing && pulses ? 1.08 : 1)
            .opacity(pulsing && pulses ? 0.76 : 1)
            .onAppear {
                guard pulses, !reduceMotion, NookMotion.liquidAnimations else { return }
                withAnimation(.easeInOut(duration: 0.75).repeatForever(autoreverses: true)) {
                    pulsing = true
                }
            }
            .onDisappear { pulsing = false }
    }
}
