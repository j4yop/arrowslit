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
        case .idle:
            return ParityLayout.compactWidth(state.settings.appearance, geometry: geometry)
        case .compact, .hud:
            return size.width
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
                    width: size.width,
                    height: size.height,
                    notchWidth: ParityLayout.notch(in: geometry).width,
                    hud: nil,
                    activity: primary
                )
                .transition(.opacity)
            case .hud:
                CompactBar(
                    state: state,
                    width: size.width,
                    height: size.height,
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
        // A HUD replaces the strip rather than growing out of it; crossfading
        // both leaves the old reading visible beneath the new one.
        .animation(presentation.hudAlert == nil
                   ? NookMotion.reducing(NookMotion.open, reduceMotion: reduceMotion)
                   : nil,
                   value: presentation)
        .environment(\.colorScheme, .dark)
        .environment(\.panelGeometry, geometry)
        .environment(\.panelScale, state.settings.appearance.size.scale)
    }
}

/// The optional notch outline: a two-point stroke, clipped so only its inner
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
    /// Which live activity fills the strip; the agent strip opens its page.
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
        Group {
            if let hud {
                LiveNoticeView(state: state, alert: hud, width: width, height: height, notchWidth: notchWidth)
            } else if activity == .nowPlaying, let track = musicTrack {
                let side = min(30, height - 8)
                HStack(spacing: 0) {
                    mediaMark(side: side)
                        .frame(width: ear, height: height, alignment: .center)

                    Color.clear
                        .frame(width: notchWidth)

                    Group {
                        if state.live.equalizer {
                            MusicBars(
                                isPlaying: track.isPlaying,
                                color: state.nowPlaying.activeAccent.color,
                                height: 18,
                                width: 24
                            )
                        } else {
                            Image(systemName: track.isPlaying ? "speaker.wave.2.fill" : "pause.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(state.nowPlaying.activeAccent.color)
                        }
                    }
                    .frame(width: ear, height: height, alignment: .center)
                }
                .frame(width: width, height: height)
            } else if activity == .agents, let live = agentUsage.snapshot.live.first {
                // The compact strip: one breathing mark per working agent,
                // each in its own color, and one reading on the other side.
                let working = AgentProvider.allCases.filter { provider in
                    agentUsage.snapshot.live.contains { $0.provider == provider }
                }
                let preferred = min(working.count > 1 ? 13.0 : 18.0, max(8, height - 16))
                let count = CGFloat(max(1, working.count))
                let room = (ear - 8 - (count - 1)) / (count * 1.45)
                let markSize = min(preferred, max(7, room))
                HStack(spacing: 0) {
                    HStack(spacing: 1) {
                        ForEach(working) { provider in
                            NotchAgentGlyph(provider: provider, size: markSize)
                        }
                    }
                    .frame(width: ear, height: height, alignment: .center)

                    Color.clear
                        .frame(width: notchWidth)

                    Text(live.started, style: .timer)
                        .font(.system(size: 15, weight: .medium))
                        .monospacedDigit()
                        .foregroundStyle(working.first?.tint ?? live.provider.tint)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .allowsTightening(true)
                        .frame(width: ear, height: height, alignment: .center)
                }
                .frame(width: width, height: height)
            } else {
                LiveActivityStrip(state: state, activity: activity, width: width, height: height, notchWidth: notchWidth)
            }
        }
        .frame(width: width, height: height)
        .animation(nil, value: hud)
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
    private func mediaMark(side: CGFloat) -> some View {
        if prefersSourceIcon, let icon = mediaSourceIcon {
            Image(nsImage: icon)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: side, height: side)
                .clipShape(RoundedRectangle(cornerRadius: side * 0.27, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: side * 0.27, style: .continuous)
                        .strokeBorder(.white.opacity(0.12), lineWidth: 0.5)
                }
        } else {
            compactArtwork(size: side)
                .overlay(alignment: .bottomTrailing) {
                    if let icon = mediaSourceIcon {
                        Image(nsImage: icon)
                            .resizable()
                            .interpolation(.high)
                            .scaledToFit()
                            .frame(width: side * 0.42, height: side * 0.42)
                            .clipShape(RoundedRectangle(cornerRadius: side * 0.12, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: side * 0.12, style: .continuous)
                                    .strokeBorder(.black.opacity(0.55), lineWidth: 0.5)
                            }
                            .offset(x: 2, y: 2)
                    }
                }
        }
    }

    private var mediaSourceIcon: NSImage? {
        if let icon = state.nowPlaying.selectedSource?.icon { return icon }
        guard let id = state.nowPlaying.activeTrack?.bundleIdentifier,
              let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) else { return nil }
        return NSWorkspace.shared.icon(forFile: url.path)
    }

    /// A browser reports a video's page as its now-playing source. The video
    /// thumbnail reads as a stray portrait in the strip, so the browser's own
    /// icon stands in for it. Music apps keep their cover art.
    private var prefersSourceIcon: Bool {
        guard let id = state.nowPlaying.activeTrack?.bundleIdentifier?.lowercased() else { return false }
        return ["chrome", "safari", "firefox", "edgemac", "brave", "vivaldi", "opera", "thebrowser"]
            .contains { id.contains($0) }
    }

    @ViewBuilder
    private func compactArtwork(size: CGFloat) -> some View {
        Group {
            if let artwork = state.nowPlaying.activeArtwork {
                Image(nsImage: artwork)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fill)
            } else {
                SlitMark(height: size * 0.54)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.27, style: .continuous))
    }

    /// A two-character-ish lead for the narrow calendar ear: "now", "12m",
    /// "2h" or the weekday for later events.
    private static func calendarLead(_ event: CalendarEvent) -> String {
        let now = Date()
        if event.isHappening(at: now) { return "Now" }
        let minutes = max(1, Int(event.start.timeIntervalSince(now) / 60))
        if minutes < 60 { return "\(minutes)m" }
        if minutes < 24 * 60 { return "\(minutes / 60)h" }
        return event.start.formatted(.dateTime.weekday(.abbreviated))
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
                let name = switch kind {
                case .volume: "Volume"
                case .brightness: "Brightness"
                case .keyboardLight: "Keyboard light"
                }
                return muted ? "Arrowslit. \(name) muted" : "Arrowslit. \(name) \(Int((value * 100).rounded())) percent"
            case .clipboard(let kind):
                return "Arrowslit. Copied \(kind)"
            case .track(let title, let artist):
                return "Arrowslit. Now playing \(title) by \(artist)"
            case .microphone(let muted):
                return "Arrowslit. Microphone \(muted ? "muted" : "on")"
            case .inputSource(let code, let name):
                return "Arrowslit. Keyboard \(code), \(name)"
            case .agentEvent(let provider, let title, let detail):
                return "Arrowslit. \(provider) \(title) \(detail)"
            case .systemNotification(let app, let title, _):
                return "Arrowslit. \(app) \(title)"
            case .capture(let kind):
                return "Arrowslit. \(kind)"
            case .watch(let title, let detail):
                return "Arrowslit. \(title) \(detail)"
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
        if activity == .calendar, let event = state.calendar.nextEvent {
            return "Arrowslit. \(event.title), \(Self.calendarLead(event))"
        }
        if activity == .keepAwake {
            return "Arrowslit. Keep awake on"
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
