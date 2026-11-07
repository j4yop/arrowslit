import SwiftUI
import UniformTypeIdentifiers

/// The 560 x 178 notch panel: a wide, short surface with a horizontal tab strip.
struct NookView: View {
    @Bindable var state: AppState
    @State private var isDropTargeted = false
    @State private var dropPoint: CGPoint = .zero
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.panelGeometry) private var geometry
    @Environment(\.panelScale) private var scale

    private var size: CGSize { state.panelSize(for: .expanded(state.activeTab), geometry: geometry) }

    var body: some View {
        VStack(spacing: 0) {
            NookHeader(state: state, notchWidth: ParityLayout.notch(in: geometry).width)
            Group {
                switch state.activeTab {
                case .home:
                    if state.settings.appearance.nookLayout == .elongated {
                        ElongatedHomePane(state: state)
                    } else {
                        HomePane(state: state)
                    }
                case .call: CallPane(state: state)
                case .download: DownloadPane(state: state)
                case .nowPlaying: CompactNowPlaying(state: state)
                case .timer, .stopwatch: ClockPane(state: state)
                case .calendar: CalendarPanelBody(state: state)
                case .tray: CompactTray(state: state)
                case .mirror: CompactMirror(state: state)
                case .clipboard: CompactClipboard(state: state)
                case .notes: CompactNotes(state: state)
                case .stats: CompactStats(state: state)
                case .sports: SportsPane(state: state)
                case .reminders: CompactReminders(state: state)
                case .agents: AgentsPane(state: state)
                case .keepAwake: CompactKeepAwake(state: state)
                case .launcher: LauncherPane(state: state)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(.horizontal, 24 * scale)
            .padding(.top, 10 * scale)
            .padding(.bottom, 16 * scale)
            .overlay {
                if isDropTargeted {
                    NookDropOverlay(tray: state.tray, point: dropPoint, split: 336)
                        .transition(.opacity.combined(with: .scale(scale: 0.99, anchor: .top)))
                }
            }
        }
        .frame(width: size.width, height: size.height)
        .background(NotchSurfaceBackground(appearance: state.settings.appearance, radius: 30, flare: 10, notchBand: geometry.notch?.height ?? 0))
        .clipShape(SlitShape(radius: 30, flare: 10))
        .overlay {
            if !state.settings.appearance.pitchBlack {
                SlitShape(radius: 30, flare: 10).stroke(ArrowTheme.hairline, lineWidth: 0.5)
            }
        }
        .shadow(
            color: state.settings.appearance.pitchBlack ? .clear : .black.opacity(0.4),
            radius: 18,
            y: 8
        )
        .onDrop(
            of: [.fileURL, .url],
            delegate: NookDropDelegate(
                isTargeted: $isDropTargeted,
                point: $dropPoint,
                split: 336,
                onFiles: { providers in
                    Task { @MainActor in
                        let urls = await FileDrop.urls(from: providers)
                        if state.tray.add(urls) > 0 { state.select(.tray) }
                    }
                },
                onAirDrop: { providers in
                    Task { @MainActor in
                        state.tray.airDrop(await FileDrop.urls(from: providers))
                    }
                }
            )
        )
        .animation(NookMotion.reducing(NookMotion.quick, reduceMotion: reduceMotion), value: isDropTargeted)
    }
}

private struct NookHeader: View {
    @Bindable var state: AppState
    let notchWidth: CGFloat
    @AppStorage("arrowslit.agents.period") private var agentsPeriod = AgentPeriod.today.rawValue
    @Environment(\.panelScale) private var scale

    private var shortcuts: [WorkbenchTab] {
        state.settings.shortcutTabs
            .compactMap(WorkbenchTab.init(rawValue:))
            .filter { state.settings.isTabEnabled($0) }
    }

    private var usesShortcutBar: Bool {
        switch state.activeTab {
        case .home, .tray, .clipboard, .launcher: true
        default: false
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            Group {
                if usesShortcutBar {
                    shortcutBar
                } else {
                    panelTitle
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Color.clear
                .frame(width: notchWidth + 12)

            HStack(spacing: 4) {
                if state.isEditingShortcuts {
                    Text("\(state.settings.shortcutTabs.count) of \(SettingsStore.shortcutLimit)")
                        .font(.system(size: 11, weight: .medium))
                        .monospacedDigit()
                        .foregroundStyle(ArrowTheme.muted)
                        .padding(.trailing, 4)
                        .help("Click features to add them beside Home, or a ticked one to remove it")
                    Button("Done") { state.isEditingShortcuts = false }
                        .buttonStyle(NookPressStyle())
                        .font(.system(size: 11 * scale, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10 * scale)
                        .frame(height: 22 * scale)
                        .background(Capsule().fill(ArrowTheme.blue))
                        .accessibilityLabel("Done editing shortcuts")
                } else {
                    NookIconButton(symbol: "square.grid.2x2", title: "All features", selected: state.activeTab == .launcher) {
                        if state.activeTab == .launcher { state.select(.home) } else { state.select(.launcher) }
                    }
                    NookIconButton(symbol: "gearshape.fill", title: "Settings") {
                        state.collapse()
                        state.onOpenSettings?()
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, 30 * scale)
        .frame(height: 32 * scale)
    }

    private var shortcutBar: some View {
        HStack(spacing: 3 * scale) {
            NookShortcutButton(
                symbol: "house.fill",
                title: "Home",
                isSelected: state.activeTab == .home,
                badge: 0,
                isEditing: false,
                onTap: { state.select(.home) },
                onRemove: nil
            )
            ForEach(shortcuts) { tab in
                NookShortcutButton(
                    symbol: tab == .keepAwake && state.keepAwake.isOn ? "cup.and.heat.waves.fill" : tab.symbol,
                    title: tab.title,
                    isSelected: state.activeTab == tab,
                    badge: tab == .tray ? state.tray.items.count : 0,
                    isEditing: state.isEditingShortcuts,
                    onTap: {
                        if state.isEditingShortcuts {
                            if state.toggleShortcut(tab) {
                                NookHaptics.perform(enabled: state.settings.hapticFeedback)
                            }
                        } else {
                            state.select(tab)
                        }
                    },
                    onRemove: {
                        state.toggleShortcut(tab)
                        state.isEditingShortcuts = false
                    }
                )
            }
        }
        .padding(2 * scale)
        .background(Capsule().fill(Color.white.opacity(0.055)))
        .contentShape(Capsule())
        .animation(.spring(duration: 0.3, bounce: 0.2), value: shortcuts)
        .accessibilityIdentifier("feature-shortcuts")
    }

    private var panelTitle: some View {
        HStack(spacing: 3 * scale) {
            Button { state.select(.home) } label: {
                Image(systemName: "chevron.backward")
                    .font(.system(size: 13 * scale, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))
                    .frame(width: 24 * scale, height: 24 * scale)
                    .background(Circle().fill(Color.white.opacity(0)))
                    .contentShape(Circle())
            }
            .buttonStyle(NookPressStyle())
            .help("Home")
            .accessibilityLabel("Back to Home")
            if state.activeTab == .agents {
                agentPeriodMenu
            } else {
                Text(state.activeTab.title)
                    .font(.system(size: 13 * scale, weight: .semibold))
                    .foregroundStyle(ArrowTheme.bone)
                    .lineLimit(1)
            }
        }
    }

    private var agentPeriodTitle: String {
        switch AgentPeriod(rawValue: agentsPeriod) ?? .today {
        case .today: "Today"
        case .week: "7 days"
        case .month: "30 days"
        }
    }

    private var agentPeriodMenu: some View {
        Menu {
            ForEach(AgentPeriod.allCases) { period in
                Button {
                    agentsPeriod = period.rawValue
                    NookHaptics.perform(enabled: state.settings.hapticFeedback)
                } label: {
                    if period.rawValue == agentsPeriod {
                        Label(agentPeriodTitle(period), systemImage: "checkmark")
                    } else {
                        Text(agentPeriodTitle(period))
                    }
                }
            }
        } label: {
            HStack(spacing: 4 * scale) {
                Text(agentPeriodTitle)
                    .font(.system(size: 13 * scale, weight: .semibold))
                    .foregroundStyle(ArrowTheme.bone)
                Image(systemName: "chevron.down")
                    .font(.system(size: 9 * scale, weight: .bold))
                    .foregroundStyle(ArrowTheme.muted)
            }
            .lineLimit(1)
            .fixedSize()
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .accessibilityLabel("AI Agents period")
    }

    private func agentPeriodTitle(_ period: AgentPeriod) -> String {
        switch period {
        case .today: "Today"
        case .week: "7 days"
        case .month: "30 days"
        }
    }
}

private struct NookShortcutButton: View {
    let symbol: String
    let title: String
    let isSelected: Bool
    let badge: Int
    let isEditing: Bool
    let onTap: () -> Void
    let onRemove: (() -> Void)?
    @State private var isHovering = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.panelScale) private var scale

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Button(action: onTap) {
                Image(systemName: symbol)
                    .font(.system(size: 11 * scale, weight: .semibold))
                    .foregroundStyle(isSelected ? .white : ArrowTheme.muted)
                    .frame(width: 24 * scale, height: 22 * scale)
                    .background(
                        Circle().fill(
                            isSelected ? Color.white.opacity(0.18)
                                : (isHovering ? Color.white.opacity(0.08) : .clear)
                        )
                    )
                    .contentShape(Circle())
            }
            .buttonStyle(NookPressStyle())
            .onHover { isHovering = $0 }
            .help(isEditing ? "Remove \(title)" : title)
            .accessibilityLabel(title)
            .accessibilityAddTraits(isSelected ? .isSelected : [])

            if isEditing, let onRemove {
                Button(action: onRemove) {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 10 * scale, weight: .bold))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, ArrowTheme.red)
                        .frame(width: 14 * scale, height: 14 * scale)
                        .background(Circle().fill(Color.black.opacity(0.8)))
                }
                .buttonStyle(.plain)
                .offset(x: 3 * scale, y: -3 * scale)
                .accessibilityLabel("Remove \(title)")
            } else if badge > 0 {
                Text("\(min(badge, 99))")
                    .font(.system(size: 8 * scale, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .padding(.horizontal, 3 * scale)
                    .frame(minWidth: 12 * scale, minHeight: 12 * scale)
                    .background(Capsule().fill(ArrowTheme.blue))
                    .offset(x: 3 * scale, y: -2 * scale)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
        .animation(NookMotion.reducing(NookMotion.hover, reduceMotion: reduceMotion), value: isHovering)
    }
}

private struct NookIconButton: View {
    let symbol: String
    let title: String
    var selected = false
    let action: () -> Void
    @State private var isHovering = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.panelScale) private var scale

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 12 * scale, weight: .semibold))
                .foregroundStyle(selected ? .white : ArrowTheme.muted)
                .frame(width: (selected ? 26 : 22) * scale, height: 22 * scale)
                .background(
                    RoundedRectangle(cornerRadius: 6 * scale, style: .continuous)
                        .fill(selected ? Color.white.opacity(0.18) : (isHovering ? Color.white.opacity(0.08) : .clear))
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(NookPressStyle())
        .onHover { isHovering = $0 }
        .animation(NookMotion.reducing(NookMotion.hover, reduceMotion: reduceMotion), value: isHovering)
        .help(title)
        .accessibilityLabel(title)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

// MARK: - Compact panes

private struct CompactTimer: View {
    @Bindable var state: AppState
    private var timer: TimerService { state.timer }

    private var seconds: TimeInterval {
        timer.countdown == nil ? TimeInterval(timer.lastMinutes * 60) : timer.remaining
    }

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 1) {
                Text(timer.justFinished ? "Complete" : (timer.isPaused ? "Paused" : (timer.isActive ? "Running" : "Ready")))
                    .font(ArrowTheme.label)
                    .foregroundStyle(timer.isActive ? ArrowTheme.amber : ArrowTheme.muted)
                Text(ClockFormat.clock(seconds, roundingUp: true))
                    .font(.system(size: 42, weight: .light))
                    .monospacedDigit()
                    .foregroundStyle(timer.justFinished ? ArrowTheme.amber : ArrowTheme.bone)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(width: 190, alignment: .leading)

            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 5) {
                    ForEach([5, 10, 25, 50], id: \.self) { minutes in
                        Button(ClockFormat.presetLabel(minutes: minutes)) {
                            state.startTimer(minutes: minutes)
                        }
                        .buttonStyle(NookPressStyle())
                        .font(.system(size: 10, weight: .medium))
                        .monospacedDigit()
                        .foregroundStyle(timer.lastMinutes == minutes && !timer.isActive ? ArrowTheme.ink : ArrowTheme.bone.opacity(0.8))
                        .frame(width: 42, height: 24)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(timer.lastMinutes == minutes && !timer.isActive ? ArrowTheme.amber : Color.white.opacity(0.06))
                        )
                    }
                }
                HStack(spacing: 6) {
                    if timer.isActive {
                        SmallAction(title: timer.isPaused ? "Resume" : "Pause", symbol: timer.isPaused ? "play.fill" : "pause.fill", filled: true) {
                            state.toggleTimer()
                        }
                        SmallAction(title: "Reset", symbol: "arrow.counterclockwise", filled: false) {
                            state.resetTimer()
                        }
                    } else if timer.justFinished {
                        SmallAction(
                            title: timer.lastWasFocus ? "Break 5m" : "Focus 25m",
                            symbol: "play.fill",
                            filled: true
                        ) {
                            if timer.lastWasFocus { state.startBreak() } else { state.startFocus() }
                        }
                    } else {
                        SmallAction(title: "Start \(timer.lastMinutes)m", symbol: "play.fill", filled: true) {
                            state.startTimer(minutes: timer.lastMinutes)
                        }
                        SmallAction(title: "Focus", symbol: "hand.raised.fill", filled: false) {
                            state.startFocus()
                        }
                    }
                }
                ProgressView(value: timer.progress)
                    .progressViewStyle(.linear)
                    .tint(ArrowTheme.amber)
                    .frame(width: 270)
            }
            Spacer(minLength: 0)
        }
        .frame(maxHeight: .infinity, alignment: .center)
    }
}

private struct SmallAction: View {
    let title: String
    let symbol: String
    let filled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: symbol).font(.system(size: 8.5, weight: .bold))
                Text(title).font(.system(size: 10, weight: .semibold))
            }
            .foregroundStyle(filled ? ArrowTheme.ink : ArrowTheme.bone.opacity(0.85))
            .padding(.horizontal, 11)
            .frame(height: 26)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(filled ? ArrowTheme.amber : Color.white.opacity(0.07))
            )
            .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .buttonStyle(NookPressStyle())
    }
}

private struct CompactNowPlaying: View {
    @Bindable var state: AppState
    private var service: NowPlayingService { state.nowPlaying }

    var body: some View {
        if let track = service.activeTrack, track.hasContent {
            HStack(spacing: 12) {
                Group {
                    if let image = service.activeArtwork {
                        Image(nsImage: image).resizable().interpolation(.high).aspectRatio(contentMode: .fill)
                    } else {
                        ZStack { ArrowTheme.panel; SlitMark(height: 20) }
                    }
                }
                .frame(width: 78, height: 78)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(track.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(ArrowTheme.bone)
                        .lineLimit(1)
                    Text(track.artist.isEmpty ? "Unknown artist" : track.artist)
                        .font(.system(size: 10.5))
                        .foregroundStyle(ArrowTheme.muted)
                        .lineLimit(1)
                    TimelineView(.animation(minimumInterval: 0.5, paused: !track.isPlaying)) { context in
                        VStack(spacing: 2) {
                            GeometryReader { geometry in
                                ZStack(alignment: .leading) {
                                    Capsule().fill(Color.white.opacity(0.08))
                                    Capsule().fill(ArrowTheme.amber)
                                        .frame(width: max(3, geometry.size.width * CGFloat(track.progress(at: context.date) ?? 0)))
                                }
                            }
                            .frame(height: 3)
                            HStack {
                                Text(ClockFormat.clock(track.elapsed(at: context.date) ?? 0))
                                Spacer()
                                Text(track.duration.map { "-" + ClockFormat.clock(max(0, $0 - (track.elapsed(at: context.date) ?? 0)), roundingUp: true) } ?? "--:--")
                            }
                            .font(.system(size: 8, weight: .medium))
                            .monospacedDigit()
                            .foregroundStyle(ArrowTheme.faint)
                        }
                    }
                    .frame(width: 280)
                    HStack(spacing: 12) {
                        MediaGlyph(symbol: "backward.fill", size: 12) { service.previous() }
                        MediaGlyph(symbol: track.isPlaying ? "pause.fill" : "play.fill", size: 16, filled: true) { service.toggle() }
                        MediaGlyph(symbol: "forward.fill", size: 12) { service.next() }
                    }
                }
                Spacer(minLength: 0)
            }
            .frame(maxHeight: .infinity, alignment: .center)
        } else {
            CompactEmpty(
                symbol: "music.note",
                title: service.isAvailable ? "Play something" : "Media bridge unavailable",
                detail: service.isAvailable ? "Music, a podcast or a video will appear here." : "Everything else still works."
            )
        }
    }
}

private struct MediaGlyph: View {
    let symbol: String
    let size: CGFloat
    var filled = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size * 0.65, weight: .semibold))
                .foregroundStyle(filled ? ArrowTheme.ink : ArrowTheme.bone.opacity(0.85))
                .frame(width: size * 1.8, height: size * 1.8)
                .background(Circle().fill(filled ? ArrowTheme.amber : Color.white.opacity(0.07)))
                .contentShape(Circle())
        }
        .buttonStyle(NookPressStyle())
    }
}

private struct CompactCalendar: View {
    @Bindable var state: AppState
    private var calendar: CalendarService { state.calendar }

    var body: some View {
        switch calendar.access {
        case .notAsked:
            CompactPrompt(symbol: "calendar", text: "Show your next event without opening Calendar.", button: "Connect Calendar") { calendar.requestAccess() }
        case .denied, .limited:
            CompactPrompt(symbol: "calendar", text: "Calendar access is off for Arrowslit.", button: "Open Privacy Settings") { calendar.openPrivacySettings() }
        case .granted:
            if let event = calendar.nextEvent {
                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 1.5).fill(ArrowTheme.amber).frame(width: 3, height: 50)

                    Button { calendar.open(event) } label: {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(event.title).font(.system(size: 14, weight: .semibold)).foregroundStyle(ArrowTheme.bone).lineLimit(1)
                            Text(CalendarRules.timeRange(for: event, at: Date())).font(.system(size: 10, weight: .medium)).monospacedDigit()
                                .foregroundStyle(event.isHappening(at: Date()) ? ArrowTheme.green : ArrowTheme.muted)
                            Text(event.start.formatted(date: .complete, time: .omitted)).font(.system(size: 9)).foregroundStyle(ArrowTheme.faint)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(NookPressStyle())

                    if let url = event.joinURL {
                        Button(joinTitle(event)) {
                            NSWorkspace.shared.open(url)
                        }
                        .buttonStyle(NookPressStyle())
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(ArrowTheme.ink)
                        .padding(.horizontal, 10)
                        .frame(height: 26)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(ArrowTheme.amber)
                        )
                    } else {
                        Image(systemName: "arrow.up.forward").font(.system(size: 10, weight: .semibold)).foregroundStyle(ArrowTheme.faint)
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(ArrowTheme.panel))
            } else {
                CompactEmpty(symbol: "calendar.badge.checkmark", title: "Nothing this week", detail: "Your next event will appear here.")
            }
        }
    }

    private func joinTitle(_ event: CalendarEvent) -> String {
        guard let provider = event.joinProvider else { return "Join" }
        return "Join \(provider.displayName)"
    }
}

private struct CompactTray: View {
    @Bindable var state: AppState
    @State private var isTargeted = false
    @Environment(\.panelScale) private var scale

    private var isWide: Bool { state.settings.appearance.nookLayout == .elongated }

    var body: some View {
        VStack(spacing: 6) {
            if state.tray.items.isEmpty {
                Group {
                    if isWide {
                        HStack(spacing: 18 * scale) {
                            Image(systemName: "tray.and.arrow.down.fill")
                                .font(.system(size: 34 * scale, weight: .semibold))
                                .foregroundStyle(isTargeted ? ArrowTheme.amber : ArrowTheme.muted)
                                .frame(width: 58 * scale, height: 58 * scale)
                                .background(Circle().fill(Color.white.opacity(0.05)))
                            VStack(alignment: .leading, spacing: 5 * scale) {
                                Text("Drag files onto the notch to keep them here")
                                    .font(.system(size: 16 * scale, weight: .semibold))
                                    .foregroundStyle(isTargeted ? ArrowTheme.amber : ArrowTheme.bone.opacity(0.92))
                                Text("They stay until you quit, or pin one to keep it. Your originals aren't touched.")
                                    .font(.system(size: 12 * scale))
                                    .foregroundStyle(ArrowTheme.muted)
                            }
                            Spacer(minLength: 0)
                            AddFilesButton(state: state)
                        }
                        .padding(.horizontal, 18 * scale)
                    } else {
                        VStack(spacing: 7 * scale) {
                            Image(systemName: "tray.and.arrow.down.fill")
                                .font(.system(size: 22 * scale, weight: .semibold))
                                .foregroundStyle(isTargeted ? ArrowTheme.amber : ArrowTheme.muted)
                            Text("Drag files onto the notch to keep them here")
                                .font(.system(size: 13 * scale, weight: .medium))
                                .foregroundStyle(isTargeted ? ArrowTheme.amber : ArrowTheme.bone.opacity(0.9))
                            Text("They stay until you quit, or pin one to keep it. Your originals aren't touched.")
                                .font(.system(size: 10 * scale))
                                .foregroundStyle(ArrowTheme.muted)
                                .multilineTextAlignment(.center)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(isTargeted ? ArrowTheme.amber.opacity(0.04) : .clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(
                            isTargeted ? ArrowTheme.amber.opacity(0.7) : Color.white.opacity(0.2),
                            style: StrokeStyle(lineWidth: 1.2, dash: [5, 4])
                        )
                )
                .animation(.easeOut(duration: 0.15), value: isTargeted)
            } else {
                HStack(spacing: 8 * scale) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8 * scale) {
                            ForEach(state.tray.items) { item in
                                CompactTrayItem(state: state, item: item)
                            }
                        }
                    }
                    .nookScrollEdgeFade()
                    .nookScrollBounce()
                    Button { state.tray.airDrop(state.tray.items) } label: {
                        Image(systemName: "wifi")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color(red: 0.35, green: 0.68, blue: 1))
                            .frame(width: 26 * scale, height: 26 * scale)
                            .background(Circle().fill(Color(red: 0.06, green: 0.22, blue: 0.36)))
                    }
                    .buttonStyle(NookPressStyle())
                    .help("Send with AirDrop")

                    Button { state.tray.clear() } label: {
                        Image(systemName: "xmark.bin.fill")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(ArrowTheme.muted)
                            .frame(width: 26 * scale, height: 26 * scale)
                            .background(Circle().fill(Color.white.opacity(0.07)))
                    }
                    .buttonStyle(NookPressStyle())
                    .help("Clear")
                }
                .frame(maxHeight: .infinity)
            }
        }
        .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
            Task { @MainActor in
                var urls: [URL] = []
                for provider in providers {
                    if let url = await provider.arrowslitFileURL() { urls.append(url) }
                }
                state.tray.add(urls)
            }
            return true
        }
    }
}

private struct AddFilesButton: View {
    @Bindable var state: AppState
    @Environment(\.panelScale) private var scale

    var body: some View {
        Button {
            let panel = NSOpenPanel()
            panel.allowsMultipleSelection = true
            panel.canChooseFiles = true
            panel.canChooseDirectories = false
            if panel.runModal() == .OK { state.tray.add(panel.urls) }
        } label: {
            Label("Add files", systemImage: "plus")
                .font(.system(size: 10 * scale, weight: .semibold))
                .foregroundStyle(ArrowTheme.ink)
                .padding(.horizontal, 10 * scale)
                .frame(height: 26 * scale)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(ArrowTheme.amber)
                )
        }
        .buttonStyle(NookPressStyle())
    }
}

private struct CompactTrayItem: View {
    @Bindable var state: AppState
    let item: TrayItem
    @State private var isHovering = false
    @Environment(\.panelScale) private var scale

    private var isWide: Bool { state.settings.appearance.nookLayout == .elongated }
    private var iconSize: CGFloat { (isWide ? 54 : 48) * scale }
    private var nameWidth: CGFloat { (isWide ? 84 : 72) * scale }

    var body: some View {
        VStack(spacing: 5) {
            Image(nsImage: state.tray.icon(for: item))
                .resizable().interpolation(.high).aspectRatio(contentMode: .fit)
                .frame(width: iconSize, height: iconSize)
            Text(item.name)
                .font(.system(size: 10 * scale, weight: .medium))
                .foregroundStyle(.white.opacity(0.85))
                .lineLimit(1).truncationMode(.middle)
                .frame(width: nameWidth)
        }
        .padding(.horizontal, 8 * scale)
        .padding(.vertical, 8 * scale)
        .background(
            RoundedRectangle(cornerRadius: 12 * scale, style: .continuous)
                .fill(Color.white.opacity(isHovering ? 0.12 : (item.isPinned ? 0.06 : 0)))
        )
        .overlay(alignment: .topLeading) {
            if item.isPinned || isHovering {
                Button { state.tray.togglePin(item.id) } label: {
                    Image(systemName: item.isPinned ? "pin.fill" : "pin")
                        .font(.system(size: 9.5 * scale, weight: .bold))
                        .foregroundStyle(item.isPinned ? ArrowTheme.amber : .white.opacity(0.85))
                        .frame(width: 18 * scale, height: 18 * scale)
                        .background(Circle().fill(Color.black.opacity(0.75)))
                        .frame(width: 22 * scale, height: 22 * scale)
                        .contentShape(Circle())
                }
                .buttonStyle(NookPressStyle())
                .padding([.top, .leading], 3 * scale)
                .help(item.isPinned ? "Unpin" : "Pin, so it stays after you quit")
                .accessibilityLabel(item.isPinned ? "Unpin \(item.name)" : "Pin \(item.name)")
            }
        }
        .overlay(alignment: .topTrailing) {
            if isHovering {
                Button { state.tray.remove(item.id) } label: {
                    ZStack {
                        Circle().fill(Color.black.opacity(0.75)).frame(width: 18 * scale, height: 18 * scale)
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 15 * scale))
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, Color(white: 0.35))
                    }
                    .frame(width: 22 * scale, height: 22 * scale)
                    .contentShape(Circle())
                }
                .buttonStyle(NookPressStyle())
                .padding([.top, .trailing], 3 * scale)
                .accessibilityLabel("Remove \(item.name)")
            }
        }
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
        .onTapGesture(count: 2) { state.tray.open(item) }
        .onDrag {
            NSItemProvider(contentsOf: item.url) ?? NSItemProvider()
        }
        .contextMenu {
            Button("Open") { state.tray.open(item) }
            Button("Show in Finder") { state.tray.reveal(item) }
            Button("Send with AirDrop") { state.tray.airDrop([item]) }
            Divider()
            Button(item.isPinned ? "Unpin" : "Pin to keep") { state.tray.togglePin(item.id) }
            Button("Remove") { state.tray.remove(item.id) }
        }
        .help(item.name)
    }
}

private struct CompactMirror: View {
    @Bindable var state: AppState
    private var camera: CameraAccess { state.camera }

    var body: some View {
        switch camera.state {
        case .notAsked:
            CompactPrompt(symbol: "person.crop.square", text: "Show a local camera preview before a call.", button: "Turn On Camera") { camera.request() }
        case .denied:
            CompactPrompt(symbol: "camera.slash", text: "Camera access is off for Arrowslit.", button: "Open Privacy Settings") { camera.openPrivacySettings() }
        case .noCamera:
            CompactEmpty(symbol: "video.slash", title: "No camera found", detail: "This Mac has no camera available.")
        case .granted:
            HStack(spacing: 12) {
                Group {
                    if camera.isCameraOff {
                        ZStack { RoundedRectangle(cornerRadius: 10).fill(ArrowTheme.panel); Image(systemName: "camera.slash").font(.system(size: 20)).foregroundStyle(ArrowTheme.faint) }
                    } else {
                        CameraPreview(
                            deviceID: state.settings.cameraDeviceID,
                            mirrored: state.settings.cameraMirrored,
                            quality: state.settings.cameraQuality
                        )
                        .id("\(state.settings.cameraDeviceID ?? "default")-\(state.settings.cameraMirrored)-\(state.settings.cameraQuality)")
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                }
                .aspectRatio(16 / 9, contentMode: .fit)
                .frame(maxWidth: 190, maxHeight: .infinity)
                VStack(alignment: .leading, spacing: 8) {
                    Text(camera.isCameraOff ? "Camera preview is off." : "Check how you look before a call.")
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(ArrowTheme.bone)
                    Button(camera.isCameraOff ? "Turn On Camera" : "Turn Off Camera") { camera.toggle() }
                        .buttonStyle(NookPressStyle())
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(ArrowTheme.ink)
                        .padding(.horizontal, 10)
                        .frame(height: 26)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(ArrowTheme.amber)
                        )
                }
                Spacer()
            }
            .frame(maxHeight: .infinity)
        }
    }
}

private struct CompactClipboard: View {
    @Bindable var state: AppState
    @State private var query = ""
    @FocusState private var searchFocused: Bool
    @Environment(\.panelScale) private var scale

    private var isWide: Bool { state.settings.appearance.nookLayout == .elongated }
    private var isSearching: Bool { state.isSearchingClipboard }
    private var filtered: [ClipboardEntry] {
        state.clipboard.matching(isSearching ? query : "")
    }

    var body: some View {
        if state.clipboard.entries.isEmpty {
            CompactEmpty(symbol: "doc.on.clipboard", title: "Copy something", detail: "Text you copy appears here; passwords are skipped. Pin a clip to keep it after quitting.")
        } else {
            VStack(spacing: 0) {
                HStack(alignment: .center, spacing: 8 * scale) {
                    ZStack {
                        if filtered.isEmpty {
                            VStack(spacing: 4) {
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 16, weight: .semibold))
                                Text("No clips match “\(query)”")
                                    .font(.system(size: 12, weight: .medium))
                                    .lineLimit(1)
                            }
                            .foregroundStyle(ArrowTheme.muted)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8 * scale) {
                                    ForEach(filtered) { entry in
                                        CompactClipCard(state: state, entry: entry, wide: isWide)
                                            .transition(.scale(scale: 0.9).combined(with: .opacity))
                                    }
                                }
                            }
                            .frame(maxHeight: .infinity)
                            .nookScrollEdgeFade()
                            .nookScrollBounce()
                        }
                    }
                    .frame(maxHeight: .infinity)

                    VStack(spacing: 6 * scale) {
                        ClipboardSideButton(
                            symbol: "magnifyingglass",
                            label: isSearching ? "Close search" : "Search clips",
                            isOn: isSearching
                        ) {
                            if isSearching { closeSearch() } else { openSearch() }
                        }
                        ClipboardSideButton(
                            symbol: "xmark.bin.fill",
                            label: state.clipboard.pinnedCount > 0 ? "Clear the history (pinned clips stay)" : "Clear the history"
                        ) {
                            withAnimation(.snappy(duration: 0.25)) { state.clipboard.clear() }
                        }
                        .disabled(state.clipboard.entries.allSatisfy(\.isPinned))
                        .opacity(state.clipboard.entries.allSatisfy(\.isPinned) ? 0.4 : 1)
                    }
                }
                .frame(maxHeight: .infinity)

                if isSearching {
                    searchField
                        .padding(.top, 10 * scale)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.snappy(duration: 0.25), value: isSearching)
            .animation(.snappy(duration: 0.25), value: filtered.map(\.id))
            .onDisappear {
                state.isSearchingClipboard = false
                state.isTypingInNook = false
            }
        }
    }

    private var searchField: some View {
        HStack(spacing: 7) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11 * scale, weight: .semibold))
                .foregroundStyle(searchFocused ? .white : ArrowTheme.muted)
            TextField("Search clips", text: $query)
                .textFieldStyle(.plain)
                .font(.system(size: 12.5 * scale, weight: .medium))
                .foregroundStyle(.white)
                .focused($searchFocused)
                .onSubmit {
                    if let first = filtered.first { state.clipboard.copy(first) }
                }
                .onKeyPress(.escape) {
                    closeSearch()
                    return .handled
                }
            if !query.isEmpty {
                Text("\(state.clipboard.matching(query).count)")
                    .font(.system(size: 11, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(ArrowTheme.muted)
                    .contentTransition(.numericText())
                    .accessibilityLabel("\(state.clipboard.matching(query).count) matches")
            }
            Button { closeSearch() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(ArrowTheme.muted)
                    .contentShape(Circle())
            }
            .buttonStyle(NookPressStyle())
            .help("Close search")
            .accessibilityLabel("Close search")
        }
        .padding(.horizontal, 12 * scale)
        .frame(height: 28 * scale)
        .background(Capsule().fill(Color.white.opacity(searchFocused ? 0.12 : 0.07)))
        .overlay(Capsule().strokeBorder(Color.white.opacity(searchFocused ? 0.16 : 0), lineWidth: 1))
        .animation(.easeOut(duration: 0.15), value: searchFocused)
        .task {
            try? await Task.sleep(for: .milliseconds(80))
            searchFocused = true
        }
        .onChange(of: searchFocused) { _, focused in state.isTypingInNook = focused }
    }

    private func openSearch() {
        withAnimation(.snappy(duration: 0.25)) { state.isSearchingClipboard = true }
    }

    private func closeSearch() {
        searchFocused = false
        withAnimation(.snappy(duration: 0.25)) {
            query = ""
            state.isSearchingClipboard = false
        }
    }
}

private struct ClipboardSideButton: View {
    let symbol: String
    let label: String
    var isOn = false
    let action: () -> Void
    @State private var isHovering = false
    @Environment(\.panelScale) private var scale

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 12 * scale, weight: .semibold))
                .foregroundStyle(isOn ? .black : (isHovering ? .white : ArrowTheme.muted))
                .frame(width: 28 * scale, height: 28 * scale)
                .background(
                    Circle().fill(
                        isOn ? .white
                            : (isHovering ? Color.white.opacity(0.18) : Color.white.opacity(0.18))
                    )
                )
                .contentShape(Circle())
        }
        .buttonStyle(NookPressStyle())
        .onHover { isHovering = $0 }
        .animation(.easeOut(duration: 0.15), value: isOn)
        .animation(.easeOut(duration: 0.12), value: isHovering)
        .help(label)
        .accessibilityLabel(label)
    }
}

private struct CompactClipCard: View {
    @Bindable var state: AppState
    let entry: ClipboardEntry
    var wide = false
    @State private var isHovering = false
    @Environment(\.panelScale) private var scale

    private var copied: Bool { state.clipboard.lastCopiedID == entry.id }

    var body: some View {
        Button { state.clipboard.copy(entry) } label: {
            VStack(alignment: .leading, spacing: 6 * scale) {
                Text(ClipboardRules.preview(entry.text, limit: wide ? 220 : 110))
                    .font(.system(size: 12 * scale, weight: .medium))
                    .foregroundStyle(.white)
                    .lineLimit(4)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                HStack(spacing: 4) {
                    if copied {
                        Image(systemName: "checkmark")
                        Text("Copied")
                    } else {
                        if entry.isPinned {
                            Image(systemName: "pin.fill")
                                .foregroundStyle(ArrowTheme.amber)
                                .accessibilityLabel("Pinned")
                        }
                        if let app = entry.appName {
                            Text(app).lineLimit(1)
                            Text("·")
                        }
                        Text(ClockFormat.age(entry.copiedAt))
                            .lineLimit(1)
                    }
                }
                .font(.system(size: 10 * scale, weight: .medium))
                .foregroundStyle(copied ? ArrowTheme.green : ArrowTheme.muted)
                .padding(.trailing, isHovering ? 42 * scale : 0)
            }
            .padding(10 * scale)
            .frame(width: (wide ? 220 : 150) * scale)
            .frame(maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 14 * scale, style: .continuous)
                    .fill(Color.white.opacity(isHovering ? 0.13 : 0.07))
            )
            .overlay {
                if entry.isPinned {
                    RoundedRectangle(cornerRadius: 14 * scale, style: .continuous)
                        .strokeBorder(ArrowTheme.amber.opacity(0.35), lineWidth: 1)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(NookPressStyle())
        .overlay(alignment: .bottomTrailing) {
            if isHovering {
                HStack(spacing: 4 * scale) {
                    ClipboardCardButton(
                        symbol: entry.isPinned ? "pin.slash" : "pin",
                        label: entry.isPinned ? "Unpin" : "Pin, so it stays after you quit",
                        isEnabled: entry.isPinned || state.clipboard.canPin
                    ) {
                        withAnimation(.snappy(duration: 0.25)) { state.clipboard.togglePin(entry) }
                    }
                    ClipboardCardButton(symbol: "trash", label: "Remove from history") {
                        withAnimation(.snappy(duration: 0.25)) { state.clipboard.remove(entry.id) }
                    }
                }
                .padding(.trailing, 7 * scale)
                .padding(.bottom, 7 * scale)
            }
        }
        .onHover { isHovering = $0 }
        .contextMenu {
            Button("Copy") { state.clipboard.copy(entry) }
            Button(entry.isPinned ? "Unpin" : "Pin") { state.clipboard.togglePin(entry) }
                .disabled(!entry.isPinned && !state.clipboard.canPin)
            Divider()
            Button("Remove from History") { state.clipboard.remove(entry.id) }
        }
        .help("Click to copy")
        .accessibilityLabel("Copy \(ClipboardRules.preview(entry.text, limit: 60))")
    }
}

private struct ClipboardCardButton: View {
    let symbol: String
    let label: String
    var isEnabled = true
    let action: () -> Void
    @Environment(\.panelScale) private var scale

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 10 * scale, weight: .semibold))
                .foregroundStyle(ArrowTheme.muted)
                .frame(width: 18 * scale, height: 18 * scale)
                .background(Circle().fill(Color.white.opacity(0.1)))
                .contentShape(Circle())
        }
        .buttonStyle(NookPressStyle())
        .disabled(!isEnabled)
        .help(label)
        .accessibilityLabel(label)
    }
}

private struct CompactNotes: View {
    @Bindable var state: AppState
    @State private var controller = RichTextController()

    var body: some View {
        NoteCard(
            state: state,
            controller: controller,
            fontSize: 11.5,
            focusOnAppear: true
        )
        .overlay(alignment: .bottomTrailing) {
            Text(state.notes.isSaved ? "Saved" : "Saving…")
                .font(.system(size: 8.5, weight: .medium))
                .foregroundStyle(state.notes.isSaved ? ArrowTheme.green : ArrowTheme.amber)
                .padding(.trailing, 8)
                .padding(.bottom, 25)
                .allowsHitTesting(false)
        }
        .onDisappear { state.notes.save() }
    }
}

private struct CompactStats: View {
    @Bindable var state: AppState

    var body: some View {
        StatsGrid(state: state)
    }
}

private struct CompactReminders: View {
    @Bindable var state: AppState
    private var reminders: RemindersService { state.reminders }

    var body: some View {
        switch reminders.access {
        case .notAsked:
            CompactPrompt(
                symbol: "checklist",
                text: "See today's to-dos from Reminders here.",
                button: "Connect Reminders"
            ) {
                reminders.requestAccess()
            }
        case .denied:
            CompactPrompt(
                symbol: "checklist",
                text: "Reminders access is off for Arrowslit.",
                button: "Open Privacy Settings"
            ) {
                reminders.openPrivacySettings()
            }
        case .granted:
            if reminders.items.isEmpty {
                CompactEmpty(
                    symbol: "checkmark.circle",
                    title: "Nothing due today",
                    detail: "Today's reminders will appear here."
                )
            } else {
                VStack(spacing: 4) {
                    ForEach(reminders.items.prefix(3)) { item in
                        Button { reminders.complete(item) } label: {
                            HStack(spacing: 8) {
                                Image(systemName: item.completed ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 12, weight: .regular))
                                    .foregroundStyle(item.completed ? ArrowTheme.green : ArrowTheme.blue)
                                Text(item.title)
                                    .font(.system(size: 11.5, weight: .medium))
                                    .foregroundStyle(ArrowTheme.bone)
                                    .lineLimit(1)
                                Spacer()
                                if let due = item.due {
                                    Text(due.formatted(date: .omitted, time: .shortened))
                                        .font(.system(size: 9))
                                        .monospacedDigit()
                                        .foregroundStyle(ArrowTheme.faint)
                                }
                            }
                            .padding(.horizontal, 9)
                            .frame(height: 28)
                            .background(RoundedRectangle(cornerRadius: 7).fill(Color.white.opacity(0.045)))
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(NookPressStyle())
                    }
                }
                .frame(maxHeight: .infinity, alignment: .top)
                .onAppear { reminders.refresh() }
            }
        }
    }
}

private struct CompactStopwatch: View {
    @Bindable var state: AppState
    private var stopwatch: StopwatchService { state.stopwatch }

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 1) {
                Text(stopwatch.isRunning ? "Running" : (stopwatch.elapsed > 0 ? "Paused" : "Ready"))
                    .font(ArrowTheme.label)
                    .foregroundStyle(stopwatch.isRunning ? ArrowTheme.amber : ArrowTheme.muted)
                Text(ClockFormat.clock(stopwatch.elapsed, tenths: true))
                    .font(.system(size: 42, weight: .light))
                    .foregroundStyle(ArrowTheme.bone)
                    .monospacedDigit()
            }
            .frame(width: 190, alignment: .leading)

            HStack(spacing: 8) {
                SmallAction(
                    title: stopwatch.isRunning ? "Pause" : "Start",
                    symbol: stopwatch.isRunning ? "pause.fill" : "play.fill",
                    filled: true
                ) {
                    stopwatch.toggle()
                }
                SmallAction(title: "Reset", symbol: "arrow.counterclockwise", filled: false) {
                    stopwatch.reset()
                }
            }
            Spacer(minLength: 0)
        }
        .frame(maxHeight: .infinity, alignment: .center)
    }
}

private struct CompactKeepAwake: View {
    @Bindable var state: AppState
    private var keepAwake: KeepAwakeService { state.keepAwake }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "cup.and.saucer.fill")
                .font(.system(size: 24, weight: .light))
                .foregroundStyle(keepAwake.isOn ? ArrowTheme.amber : ArrowTheme.faint)
            VStack(alignment: .leading, spacing: 2) {
                Text(keepAwake.isOn ? "This Mac stays awake." : "Keep this Mac awake.")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(ArrowTheme.bone)
                Text("Display sleep is still allowed.")
                    .font(.system(size: 9.5))
                    .foregroundStyle(ArrowTheme.faint)
            }
            Spacer()
            Button(keepAwake.isOn ? "Turn Off" : "Turn On") {
                keepAwake.toggle()
            }
            .buttonStyle(NookPressStyle())
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(ArrowTheme.ink)
            .padding(.horizontal, 12)
            .frame(height: 27)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(ArrowTheme.amber)
            )
        }
        .frame(maxHeight: .infinity)
    }
}

private struct CompactPrompt: View {
    let symbol: String
    let text: String
    let button: String
    let action: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol).font(.system(size: 22, weight: .light)).foregroundStyle(ArrowTheme.amber)
            Text(text).font(.system(size: 11.5)).foregroundStyle(ArrowTheme.muted).lineLimit(2)
            Spacer()
            Button(button, action: action)
                .buttonStyle(NookPressStyle())
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(ArrowTheme.ink)
                .padding(.horizontal, 11)
                .frame(height: 26)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(ArrowTheme.amber)
                )
        }
        .frame(maxHeight: .infinity)
    }
}

private struct CompactEmpty: View {
    let symbol: String
    let title: String
    let detail: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbol).font(.system(size: 20, weight: .light)).foregroundStyle(ArrowTheme.faint)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.system(size: 12, weight: .semibold)).foregroundStyle(ArrowTheme.muted)
                Text(detail).font(.system(size: 9.5)).foregroundStyle(ArrowTheme.faint)
            }
            Spacer()
        }
        .frame(maxHeight: .infinity)
    }
}
