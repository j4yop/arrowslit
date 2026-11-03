import SwiftUI
import UniformTypeIdentifiers

struct ArrowslitRootView: View {
    @Bindable var state: AppState
    /// The display this panel is on. With one panel this is the selected screen; with All
    /// displays each panel passes its own screen so its notch and width are correct.
    let screen: NSScreen?
    let role: PanelRole
    @AppStorage(NotchOutline.key) private var outlineEnabled = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var contrast

    private var geometry: ScreenGeometry {
        screen.map(ScreenReader.geometry(for:)) ?? ScreenReader.current
    }

    /// The compact strip can sit in a wider window when a second live
    /// activity is detached beside it. The outline belongs to the strip, so
    /// it always uses the strip's own width rather than the window's.
    private func outlineWidth(for presentation: NotchPresentation,
                              size: CGSize,
                              geometry: ScreenGeometry) -> CGFloat {
        switch presentation {
        case .hidden(let peek):
            return peek ? size.width : size.width - ParityLayout.restingOutlineInset * 2
        case .idle, .compact, .hud:
            return ParityLayout.compactWidth(state.settings.appearance, geometry: geometry)
        default:
            return size.width
        }
    }

    private func outlineHeight(for presentation: NotchPresentation,
                               size: CGSize,
                               geometry: ScreenGeometry) -> CGFloat {
        return size.height
    }

    private func isRestingNotch(_ presentation: NotchPresentation) -> Bool {
        if case .hidden(let peek) = presentation { return !peek }
        return false
    }

    private var presentation: NotchPresentation {
        role.isActive ? state.presentation : state.mirrorPresentation
    }

    var body: some View {
        let geometry = self.geometry
        let presentation = self.presentation
        let size = state.panelSize(for: presentation, geometry: geometry)

        ZStack(alignment: .top) {
            switch presentation {
            case .alert(let alert):
                NotchAlertView(state: state, alert: alert)
                    .transition(.opacity.combined(with: .scale(scale: 0.99, anchor: .top)))
            case .expanded(.nowPlaying):
                NowPlayingPlayerView(state: state)
                    .transition(.opacity.combined(with: .scale(scale: 0.99, anchor: .top)))
            case .clockRunning(let mode):
                ClockRunningPane(state: state, mode: mode)
                    .transition(.opacity.combined(with: .scale(scale: 0.99, anchor: .top)))
            case .expanded:
                NookView(state: state)
                    .transition(.opacity.combined(with: .scale(scale: 0.99, anchor: .top)))
            case .hidden(let peek):
                HiddenPeekShape(
                    size: size,
                    appearance: state.settings.appearance,
                    peek: peek,
                    open: { state.expand(.home) }
                )
                .transition(.opacity)
            case .idle:
                CompactBar(
                    state: state,
                    width: ParityLayout.compactWidth(state.settings.appearance, geometry: geometry),
                    height: ParityLayout.compactHeight(state.settings.appearance, geometry: geometry),
                    notchWidth: ParityLayout.notch(in: geometry).width,
                    hud: nil
                )
                .transition(.opacity)
            case .compact(let primary):
                CompactBar(
                    state: state,
                    width: ParityLayout.compactWidth(state.settings.appearance, geometry: geometry),
                    height: ParityLayout.compactHeight(state.settings.appearance, geometry: geometry),
                    notchWidth: ParityLayout.notch(in: geometry).width,
                    hud: nil,
                    activity: primary
                )
                .transition(.opacity)
            case .hud:
                CompactBar(
                    state: state,
                    width: ParityLayout.compactWidth(state.settings.appearance, geometry: geometry),
                    height: ParityLayout.compactHeight(state.settings.appearance, geometry: geometry),
                    notchWidth: ParityLayout.notch(in: geometry).width,
                    hud: presentation.hudAlert
                )
                .transition(.opacity)
            }

            if outlineEnabled, NotchOutline.isVisible(for: presentation),
               let radius = NotchOutline.radius(for: presentation) {
                NotchOutlineOverlay(
                    shape: SlitShape(radius: radius, flare: NotchOutline.flare(for: presentation)),
                    color: .white.opacity(contrast == .increased
                                          ? NotchOutline.increasedContrastOpacity
                                          : NotchOutline.opacity),
                    fillsNotch: isRestingNotch(presentation)
                )
                .frame(width: outlineWidth(for: presentation, size: size, geometry: geometry),
                       height: outlineHeight(for: presentation, size: size, geometry: geometry))
            }
        }
        .frame(width: size.width, height: size.height, alignment: .top)
        .animation(NookMotion.reducing(NookMotion.open, reduceMotion: reduceMotion), value: presentation)
        .environment(\.colorScheme, .dark)
        .environment(\.panelGeometry, geometry)
        .environment(\.panelScale, state.settings.appearance.size.scale)
    }
}

/// Arrowslit's optional outline: a two-point stroke, clipped so only its inner
/// half shows, with the first point at the top masked because the island hangs
/// from the top of the display.
private struct NotchOutlineOverlay: View {
    let shape: SlitShape
    let color: Color
    /// The hidden window is transparent; the resting notch needs its black
    /// body so the outline reads as the Mac notch, not a line over the desktop.
    var fillsNotch = false

    var body: some View {
        ZStack {
            if fillsNotch {
                shape.fill(Color.black)
            }
            shape
                .stroke(color, lineWidth: NotchOutline.lineWidth)
                .clipShape(shape)
                .mask(alignment: .top) {
                    Rectangle().padding(.top, NotchOutline.topGap)
                }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// The retracted notch. The panel is still a 200×35 hover target, but only the peek draws
/// anything; the real camera housing hides the rest.
private struct HiddenPeekShape: View {
    let size: CGSize
    let appearance: NotchAppearance
    let peek: Bool
    let open: () -> Void

    var body: some View {
        Group {
            if peek {
                SlitShape(radius: 11, flare: 5)
                    .fill(ArrowTheme.ink)
            } else {
                Color.clear
            }
        }
        .frame(width: size.width, height: size.height)
        .contentShape(Rectangle())
        .onTapGesture(perform: open)
        .accessibilityElement()
        .accessibilityLabel("Arrowslit")
        .accessibilityHint("Open Home")
        .accessibilityAction(named: "Open Home", open)
    }
}

/// The closed strip. Everything is laid out in the two ears beside the camera
/// housing, so nothing can disappear under the notch on any Mac.
private struct CompactBar: View {
    @Bindable var state: AppState
    @Environment(\.panelGeometry) private var geometry
    let width: CGFloat
    let height: CGFloat
    let notchWidth: CGFloat
    var hud: NotchAlert?
    /// Which live activity fills the strip; the agent compact strip opens its page.
    var activity: NotchActivity? = nil
    @State private var isDropTargeted = false
    @ObservedObject private var agentUsage = AgentUsageService.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var ear: CGFloat { max(0, (width - notchWidth) / 2) }

    private var isLiveClock: Bool {
        if state.timer.isActive || state.timer.justFinished { return false }
        if state.stopwatch.isActive { return false }
        if state.nowPlaying.isVisible,
           let title = state.nowPlaying.activeTrack?.title,
           !title.isEmpty { return false }
        return true
    }

    private var musicTrack: NowPlayingTrack? {
        guard state.nowPlaying.isVisible, let track = state.nowPlaying.activeTrack, track.hasContent else { return nil }
        return track
    }

    var body: some View {
        HStack(spacing: 0) {
            if let hud {
                hudContent(hud)
                    .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .top)))
            } else if let session = state.calls.session {
                Group {
                    if let icon = state.calls.appIcon {
                        Image(nsImage: icon)
                            .resizable()
                            .interpolation(.high)
                            .frame(width: 22, height: 22)
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    } else {
                        Image(systemName: session.isCall ? "phone.fill" : "mic.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(session.isCall ? ArrowTheme.green : ArrowTheme.amber)
                    }
                }
                .padding(.leading, 10)
                .frame(width: ear, alignment: .leading)

                Color.clear
                    .frame(width: notchWidth)

                HStack(spacing: 3) {
                    if state.microphone.isMuted {
                        Image(systemName: "mic.slash.fill")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(ArrowTheme.red)
                            .accessibilityHidden(true)
                    }
                    Text(session.startDate, style: .timer)
                        .font(.system(size: 11, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(session.isCall ? ArrowTheme.green : ArrowTheme.amber)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .padding(.trailing, 6)
                .frame(width: ear, alignment: .trailing)
            } else if state.timer.isActive {
                Image(systemName: "timer")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(state.timer.isPaused ? ArrowTheme.muted : ArrowTheme.amber)
                    .padding(.leading, 12)
                    .frame(width: ear, alignment: .leading)

                Color.clear
                    .frame(width: notchWidth)

                Text(ClockFormat.clock(state.timer.remaining, roundingUp: true))
                    .font(.system(size: 13, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(ArrowTheme.bone)
                    .padding(.trailing, 10)
                    .frame(width: ear, alignment: .trailing)
            } else if state.stopwatch.isActive {
                Image(systemName: "stopwatch")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(state.stopwatch.isRunning ? ArrowTheme.amber : ArrowTheme.muted)
                    .padding(.leading, 12)
                    .frame(width: ear, alignment: .leading)

                Color.clear
                    .frame(width: notchWidth)

                Text(ClockFormat.clock(state.stopwatch.elapsed, tenths: true))
                    .font(.system(size: 13, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(ArrowTheme.bone)
                    .padding(.trailing, 10)
                    .frame(width: ear, alignment: .trailing)
            } else if let live = agentUsage.snapshot.live.first {
                // Arrowslit's strip: one breathing mark per working agent,
                // each in its own color, and one reading on the other side.
                let working = AgentProvider.allCases.filter { provider in
                    agentUsage.snapshot.live.contains { $0.provider == provider }
                }
                let preferred = min(working.count > 1 ? 11.0 : 14.0, max(8, height - 14))
                // Arrowslit's ear is fixed, so several marks share its width
                // rather than widening the island as Arrowslit's wing does.
                let count = CGFloat(max(1, working.count))
                let inset: CGFloat = working.count > 1 ? 6 : 10
                let room = (ear - inset - (count - 1)) / (count * 1.45)
                let markSize = min(preferred, max(7, room))
                HStack(spacing: 1) {
                    ForEach(working) { provider in
                        NotchAgentGlyph(provider: provider, size: markSize)
                    }
                }
                .padding(.leading, inset)
                .frame(width: ear, alignment: .leading)

                Color.clear
                    .frame(width: notchWidth)

                Text(live.started, style: .timer)
                    .font(.system(size: min(15, height - 7), weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(working.first?.tint ?? live.provider.tint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .padding(.trailing, 7)
                    .frame(width: ear, alignment: .trailing)
            } else if let match = state.sports.notchMatch {
                SportsCompactScore(match: match, ear: ear, notchWidth: notchWidth)
            } else if let track = musicTrack {
                compactArtwork
                    .padding(.leading, 10)
                    .frame(width: ear, alignment: .leading)

                Color.clear
                    .frame(width: notchWidth)

                MusicBars(
                    isPlaying: track.isPlaying,
                    color: state.nowPlaying.activeAccent.color,
                    height: 15,
                    width: 20
                )
                .padding(.trailing, 10)
                .frame(width: ear, alignment: .trailing)
            } else if !state.downloadProgress.items.isEmpty {
                DownloadCompactIcon(fontSize: compactFontSize)
                    .padding(.leading, 10)
                    .frame(width: ear, alignment: .leading)

                Color.clear
                    .frame(width: notchWidth)

                DownloadCompactValue(summary: state.downloadProgress.summary, fontSize: compactFontSize)
                    .padding(.trailing, 10)
                    .frame(width: ear, alignment: .trailing)
            } else if state.settings.statsEnabled, state.stats.isRunning, state.stats.hasReading {
                HStack(spacing: 4) {
                    Image(systemName: "gauge.with.dots.needle.33percent")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(ArrowTheme.green)
                    Text("CPU \(Int((state.stats.cpu * 100).rounded()))%")
                        .font(.system(size: 10.5, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(ArrowTheme.bone)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .padding(.leading, 9)
                .frame(width: ear, alignment: .leading)

                Color.clear
                    .frame(width: notchWidth)

                Text("MEM \(Int((state.stats.memoryShare * 100).rounded()))%")
                    .font(.system(size: 10.5, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(ArrowTheme.muted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .padding(.trailing, 9)
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

                HStack(spacing: 3) {
                    compactValue

                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(ArrowTheme.bone.opacity(0.6))
                        .frame(width: 10)
                        .accessibilityHidden(true)
                }
                .padding(.trailing, 4)
                .frame(width: ear, alignment: .trailing)
            }
        }
        .frame(width: width, height: height)
        .animation(NookMotion.reducing(NookMotion.quick, reduceMotion: reduceMotion), value: hud)
        .background(NotchSurfaceBackground(appearance: state.settings.appearance, radius: 12, flare: 6, notchBand: geometry.notch?.height ?? 0))
        .clipShape(SlitShape(radius: 12, flare: 6))
        .overlay {
            if isDropTargeted || !state.settings.appearance.pitchBlack {
                SlitShape(radius: 12, flare: 6)
                    .stroke(
                        isDropTargeted ? ArrowTheme.blue : ArrowTheme.hairline,
                        lineWidth: isDropTargeted ? 1.5 : 0.5
                    )
                    .animation(NookMotion.reducing(NookMotion.hover, reduceMotion: reduceMotion), value: isDropTargeted)
            }
        }
        .contentShape(SlitShape(radius: 12, flare: 6))
        .onTapGesture {
            if activity == .agents, state.settings.isTabEnabled(.agents) {
                state.expand(.agents)
            } else {
                state.expandDefault()
            }
        }
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
            if let artwork = state.nowPlaying.activeArtwork {
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
                timeText(ClockFormat.wallClockShortIST(context.date), color: ArrowTheme.bone)
            }
        } else {
            timeText(
                state.compactValue,
                color: state.timer.isActive ? ArrowTheme.amber : ArrowTheme.bone
            )
        }
    }

    private var compactFontSize: CGFloat {
        let scale = state.settings.appearance.size.scale
        return min(max(height * 0.4 * scale, 10), 18)
    }

    private func timeText(_ value: String, color: Color) -> some View {
        let fontSize = compactFontSize
        return Text(value)
            .font(.system(size: fontSize, weight: .semibold))
            .monospacedDigit()
            .foregroundStyle(color)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .truncationMode(.tail)
            .frame(width: max(20, ear - 18), alignment: .trailing)
    }

    private var accessibilityLabel: String {
        if let session = state.calls.session {
            return "Arrowslit. \(session.isCall ? "On call with" : "Microphone used by") \(session.appName)"
        }
        if state.settings.statsEnabled, state.stats.hasReading, state.activeActivities == [.stats] {
            return "Arrowslit. CPU \(Int((state.stats.cpu * 100).rounded())) percent, memory \(Int((state.stats.memoryShare * 100).rounded())) percent"
        }
        if !state.downloadProgress.items.isEmpty {
            let count = state.downloadProgress.items.count
            let summary = state.downloadProgress.summary
            let progress = summary.fraction.map { "\(Int(($0 * 100).rounded())) percent" } ?? "in progress"
            return "Arrowslit. \(count == 1 ? "Download" : "\(count) downloads"), \(progress)"
        }
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
        if state.timer.isActive {
            return "Arrowslit. \(state.compactLabel) \(state.compactValue)"
        }
        if activity == .agents, let live = agentUsage.snapshot.live.first {
            return "Arrowslit. \(live.provider.displayName) working in \(live.project)"
        }
        if let match = state.sports.notchMatch {
            return "Arrowslit. \(match.home.shortName) \(match.homeScore ?? 0), \(match.away.shortName) \(match.awayScore ?? 0), \(SportsFormat.shortStatus(match))"
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

/// The closed notch's live sports ear: home abbreviation + score on one side,
/// away abbreviation + score on the other, with the camera housing between.
private struct SportsCompactScore: View {
    let match: SportsMatch
    let ear: CGFloat
    let notchWidth: CGFloat

    private var accent: Color { match.isLive ? ArrowTheme.green : ArrowTheme.muted }

    var body: some View {
        HStack(spacing: 0) {
            HStack(spacing: 5) {
                Circle()
                    .fill(accent)
                    .frame(width: 4.5, height: 4.5)
                Text(match.home.shortName)
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(ArrowTheme.bone)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Text(match.homeScore.map(String.init) ?? "–")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(ArrowTheme.bone)
            }
            .padding(.leading, 12)
            .frame(width: ear, alignment: .leading)

            Color.clear
                .frame(width: notchWidth)

            HStack(spacing: 4) {
                Text(match.away.shortName)
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(ArrowTheme.bone)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Text(match.awayScore.map(String.init) ?? "–")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(ArrowTheme.bone)
            }
            .padding(.trailing, 12)
            .frame(width: ear, alignment: .trailing)
        }
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
