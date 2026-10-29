import SwiftUI
import UniformTypeIdentifiers

/// The 560 x 178 notch panel: a wide, short surface with a horizontal tab strip.
struct NookView: View {
    @Bindable var state: AppState
    @State private var isDropTargeted = false
    @State private var dropPoint: CGPoint = .zero

    var body: some View {
        VStack(spacing: 0) {
            NookHeader(state: state, notchWidth: ScreenReader.current.housing.width)
            Group {
                switch state.activeTab {
                case .home: HomePane(state: state)
                case .nowPlaying: CompactNowPlaying(state: state)
                case .timer: CompactTimer(state: state)
                case .calendar: CompactCalendar(state: state)
                case .tray: CompactTray(state: state)
                case .mirror: CompactMirror(state: state)
                case .clipboard: CompactClipboard(state: state)
                case .notes: CompactNotes(state: state)
                case .stats: CompactStats(state: state)
                case .stopwatch: CompactStopwatch(state: state)
                case .keepAwake: CompactKeepAwake(state: state)
                case .launcher: LauncherPane(state: state)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(.horizontal, 14)
            .padding(.top, 10)
            .padding(.bottom, 16)
            .overlay {
                if isDropTargeted {
                    NookDropOverlay(point: dropPoint, split: 336)
                        .transition(.opacity)
                }
            }
        }
        .frame(width: 560, height: 178)
        .background(ArrowTheme.ink)
        .clipShape(SlitShape(radius: 18))
        .overlay {
            SlitShape(radius: 18).stroke(ArrowTheme.hairline, lineWidth: 0.5)
        }
        .shadow(color: .black.opacity(0.4), radius: 18, y: 8)
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
        .animation(.easeOut(duration: 0.12), value: isDropTargeted)
    }
}

private struct NookHeader: View {
    @Bindable var state: AppState
    let notchWidth: CGFloat

    private var sideWidth: CGFloat {
        // Keep a small buffer around the camera housing so no control touches it.
        let gap = min(260, notchWidth + 12)
        return max(120, (560 - gap) / 2)
    }

    var body: some View {
        HStack(spacing: 0) {
            HStack(spacing: 3) {
                if state.activeTab.isPrimaryTab {
                    NookTabButton(symbol: "house", title: "Home", isSelected: state.activeTab == .home) { state.select(.home) }
                    if state.settings.isTabEnabled(.tray) {
                        NookTabButton(symbol: "tray.full", title: "Files", isSelected: state.activeTab == .tray, badge: state.tray.items.count) { state.select(.tray) }
                    }
                    if state.settings.isTabEnabled(.clipboard) {
                        NookTabButton(symbol: "doc.on.clipboard", title: "Clipboard", isSelected: state.activeTab == .clipboard) { state.select(.clipboard) }
                    }
                } else {
                    Button { state.select(.home) } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.backward").font(.system(size: 9, weight: .semibold))
                            Text(state.activeTab.title).font(.system(size: 10.5, weight: .semibold)).lineLimit(1)
                        }
                        .foregroundStyle(ArrowTheme.bone)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.leading, 10)
            .frame(width: sideWidth, alignment: .leading)

            Color.clear.frame(width: 560 - sideWidth * 2)

            HStack(spacing: 3) {
                NookIconButton(symbol: "square.grid.2x2", title: "All features", selected: state.activeTab == .launcher) {
                    if state.activeTab == .launcher { state.select(.home) } else { state.select(.launcher) }
                }
                NookIconButton(symbol: "gearshape", title: "Settings") {
                    state.collapse()
                    state.onOpenSettings?()
                }
            }
            .padding(.trailing, 10)
            .frame(width: sideWidth, alignment: .trailing)
        }
        .frame(height: 32)
    }
}

private struct NookTabButton: View {
    let symbol: String
    let title: String
    let isSelected: Bool
    var badge = 0
    let action: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: symbol)
                    .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                if isSelected {
                    Text(title)
                        .font(.system(size: 9.5, weight: .semibold))
                        .lineLimit(1)
                        .fixedSize()
                }
            }
            .foregroundStyle(isSelected ? ArrowTheme.bone : ArrowTheme.muted)
            .padding(.horizontal, isSelected ? 7 : 5)
            .frame(height: 24)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(isSelected ? Color.white.opacity(0.1) : (isHovering ? Color.white.opacity(0.06) : .clear))
            )
            .overlay(alignment: .topTrailing) {
                if badge > 0 {
                    Text("\(min(badge, 99))")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 3)
                        .frame(minWidth: 12, minHeight: 12)
                        .background(Capsule().fill(Color(red: 0.04, green: 0.52, blue: 1)))
                        .offset(x: 5, y: -4)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .help(title)
        .accessibilityLabel(title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct NookIconButton: View {
    let symbol: String
    let title: String
    var selected = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(selected ? ArrowTheme.bone : ArrowTheme.muted)
                .frame(width: 24, height: 26)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(selected ? Color.white.opacity(0.1) : .clear)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(title)
        .accessibilityLabel(title)
    }
}

private struct NookFooter: View {
    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(ArrowTheme.green).frame(width: 4, height: 4)
            Text("LOCAL / PRIVATE")
                .font(.system(size: 7, weight: .bold))
                .tracking(1.1)
                .foregroundStyle(ArrowTheme.faint)
            Spacer()
            Text("GPL-3.0")
                .font(.system(size: 7, weight: .medium, design: .monospaced))
                .foregroundStyle(ArrowTheme.faint)
        }
        .padding(.horizontal, 14)
        .frame(height: 16)
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
                Text(timer.justFinished ? "COMPLETE" : (timer.isPaused ? "PAUSED" : (timer.isActive ? "RUNNING" : "READY")))
                    .font(.system(size: 7.5, weight: .bold))
                    .tracking(1.2)
                    .foregroundStyle(timer.isActive ? ArrowTheme.amber : ArrowTheme.faint)
                Text(ClockFormat.clock(seconds, roundingUp: true))
                    .font(.system(size: 42, weight: .light, design: .monospaced))
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
                        .buttonStyle(.plain)
                        .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                        .foregroundStyle(timer.lastMinutes == minutes && !timer.isActive ? ArrowTheme.ink : ArrowTheme.bone.opacity(0.8))
                        .frame(width: 42, height: 24)
                        .background(Capsule().fill(timer.lastMinutes == minutes && !timer.isActive ? ArrowTheme.amber : Color.white.opacity(0.06)))
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
                    } else {
                        SmallAction(title: "Start \(timer.lastMinutes)m", symbol: "play.fill", filled: true) {
                            state.startTimer(minutes: timer.lastMinutes)
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
            .background(Capsule().fill(filled ? ArrowTheme.amber : Color.white.opacity(0.07)))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

private struct CompactNowPlaying: View {
    @Bindable var state: AppState
    private var service: NowPlayingService { state.nowPlaying }

    var body: some View {
        if let track = service.track, track.hasContent {
            HStack(spacing: 12) {
                Group {
                    if let image = service.artwork {
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
                            .font(.system(size: 8, weight: .medium, design: .monospaced))
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
        .buttonStyle(.plain)
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
                Button { calendar.open(event) } label: {
                    HStack(spacing: 12) {
                        RoundedRectangle(cornerRadius: 1.5).fill(ArrowTheme.amber).frame(width: 3, height: 50)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(event.title).font(.system(size: 14, weight: .semibold)).foregroundStyle(ArrowTheme.bone).lineLimit(1)
                            Text(label(event)).font(.system(size: 10, weight: .medium, design: .monospaced))
                                .foregroundStyle(event.isHappening(at: Date()) ? ArrowTheme.green : ArrowTheme.muted)
                            Text(event.start.formatted(date: .complete, time: .omitted)).font(.system(size: 9)).foregroundStyle(ArrowTheme.faint)
                        }
                        Spacer()
                        Image(systemName: "arrow.up.forward").font(.system(size: 10, weight: .semibold)).foregroundStyle(ArrowTheme.faint)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(ArrowTheme.panel))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            } else {
                CompactEmpty(symbol: "calendar.badge.checkmark", title: "Nothing this week", detail: "Your next event will appear here.")
            }
        }
    }

    private func label(_ event: CalendarEvent) -> String {
        if event.isAllDay { return "All day" }
        let end = event.end.formatted(date: .omitted, time: .shortened)
        if event.isHappening(at: Date()) { return "Now · until \(end)" }
        return event.start.formatted(date: .omitted, time: .shortened) + " – " + end
    }
}

private struct CompactTray: View {
    @Bindable var state: AppState
    @State private var isTargeted = false

    var body: some View {
        VStack(spacing: 6) {
            if state.tray.items.isEmpty {
                HStack(spacing: 10) {
                    Image(systemName: isTargeted ? "tray.and.arrow.down.fill" : "tray")
                        .font(.system(size: 18, weight: .light))
                        .foregroundStyle(isTargeted ? ArrowTheme.amber : ArrowTheme.faint)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(isTargeted ? "Drop to keep a reference" : "Drop files here")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(isTargeted ? ArrowTheme.amber : ArrowTheme.muted)
                        Text("The tray clears when Arrowslit quits.")
                            .font(.system(size: 9)).foregroundStyle(ArrowTheme.faint)
                    }
                    Spacer()
                    AddFilesButton(state: state)
                }
                .padding(.horizontal, 12)
                .frame(maxHeight: .infinity)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.025)))
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.white.opacity(0.12), style: StrokeStyle(lineWidth: 1, dash: [4, 4])))
            } else {
                HStack(spacing: 8) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(state.tray.items) { item in
                                CompactTrayItem(state: state, item: item)
                            }
                        }
                    }
                    Button { state.tray.airDrop(state.tray.items) } label: {
                        Image(systemName: "wifi")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color(red: 0.35, green: 0.68, blue: 1))
                            .frame(width: 26, height: 26)
                            .background(Circle().fill(Color(red: 0.06, green: 0.22, blue: 0.36)))
                    }
                    .buttonStyle(.plain)
                    .help("Send with AirDrop")

                    Button { state.tray.clear() } label: {
                        Image(systemName: "xmark.bin.fill")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(ArrowTheme.muted)
                            .frame(width: 26, height: 26)
                            .background(Circle().fill(Color.white.opacity(0.07)))
                    }
                    .buttonStyle(.plain)
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

    var body: some View {
        Button {
            let panel = NSOpenPanel()
            panel.allowsMultipleSelection = true
            panel.canChooseFiles = true
            panel.canChooseDirectories = false
            if panel.runModal() == .OK { state.tray.add(panel.urls) }
        } label: {
            Label("Add files", systemImage: "plus")
                .font(.system(size: 9.5, weight: .semibold))
                .foregroundStyle(ArrowTheme.ink)
                .padding(.horizontal, 10)
                .frame(height: 26)
                .background(Capsule().fill(ArrowTheme.amber))
        }
        .buttonStyle(.plain)
    }
}

private struct CompactTrayItem: View {
    @Bindable var state: AppState
    let item: TrayItem
    @State private var isHovering = false

    var body: some View {
        VStack(spacing: 3) {
            Image(nsImage: state.tray.icon(for: item))
                .resizable().interpolation(.high).aspectRatio(contentMode: .fit)
                .frame(width: 42, height: 42)
            Text(item.name)
                .font(.system(size: 8.5, weight: .medium))
                .foregroundStyle(ArrowTheme.bone.opacity(0.85))
                .lineLimit(1).truncationMode(.middle)
                .frame(width: 62)
        }
        .padding(.vertical, 5)
        .padding(.horizontal, 5)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(isHovering ? 0.07 : 0.035)))
        .overlay(alignment: .topTrailing) {
            if isHovering {
                Button { state.tray.remove(item.id) } label: {
                    Image(systemName: "xmark").font(.system(size: 6.5, weight: .bold))
                        .foregroundStyle(ArrowTheme.bone)
                        .frame(width: 14, height: 14)
                        .background(Circle().fill(Color.black.opacity(0.75)))
                }
                .buttonStyle(.plain)
                .padding(2)
            }
        }
        .onHover { isHovering = $0 }
        .onTapGesture(count: 2) { state.tray.open(item) }
        .help(item.name)
    }
}

private struct CompactMirror: View {
    @Bindable var state: AppState
    private var camera: CameraAccess { state.camera }

    var body: some View {
        switch camera.state {
        case .notAsked:
            CompactPrompt(symbol: "person.crop.square", text: "A local camera preview before a call.", button: "Turn On Camera") { camera.request() }
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
                        CameraPreview().clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                }
                .aspectRatio(16 / 9, contentMode: .fit)
                .frame(maxWidth: 190, maxHeight: .infinity)
                VStack(alignment: .leading, spacing: 8) {
                    Text(camera.isCameraOff ? "Camera preview is off." : "Check how you look before a call.")
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(ArrowTheme.bone)
                    Button(camera.isCameraOff ? "Turn On Camera" : "Turn Off Camera") { camera.toggle() }
                        .buttonStyle(.plain)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(ArrowTheme.ink)
                        .padding(.horizontal, 10)
                        .frame(height: 26)
                        .background(Capsule().fill(ArrowTheme.amber))
                }
                Spacer()
            }
            .frame(maxHeight: .infinity)
        }
    }
}

private struct CompactClipboard: View {
    @Bindable var state: AppState

    var body: some View {
        if state.clipboard.entries.isEmpty {
            CompactEmpty(symbol: "doc.on.clipboard", title: "Copy something", detail: "Text you copy appears here; passwords are skipped.")
        } else {
            HStack(spacing: 8) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(state.clipboard.entries) { entry in
                            CompactClipCard(state: state, entry: entry)
                        }
                    }
                }
                Button { state.clipboard.clear() } label: {
                    Image(systemName: "xmark.bin.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(ArrowTheme.muted)
                        .frame(width: 26, height: 26)
                        .background(Circle().fill(Color.white.opacity(0.07)))
                }
                .buttonStyle(.plain)
                .help("Clear")
            }
        }
    }
}

private struct CompactClipCard: View {
    @Bindable var state: AppState
    let entry: ClipboardEntry
    @State private var isHovering = false

    var body: some View {
        Button { state.clipboard.copy(entry) } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(ClipboardRules.preview(entry.text, limit: 120))
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(ArrowTheme.bone)
                    .lineLimit(4)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                HStack(spacing: 4) {
                    if let app = entry.appName { Text(app).lineLimit(1); Text("·") }
                    Text(ClockFormat.age(entry.copiedAt))
                }
                .font(.system(size: 8.5))
                .foregroundStyle(ArrowTheme.faint)
            }
            .padding(9)
            .frame(width: 150, height: 100)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.white.opacity(isHovering ? 0.1 : 0.05)))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .help("Copy again")
    }
}

private struct CompactNotes: View {
    @Bindable var state: AppState
    @FocusState private var focused: Bool

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 10, style: .continuous).fill(ArrowTheme.panel)
            if state.notes.isEmpty {
                Text("Jot a thought, a number, a next step…")
                    .font(.system(size: 11.5)).foregroundStyle(ArrowTheme.faint)
                    .padding(.horizontal, 10).padding(.vertical, 8).allowsHitTesting(false)
            }
            TextEditor(text: Binding(get: { state.notes.text }, set: { state.notes.setText($0) }))
                .font(.system(size: 11.5))
                .foregroundStyle(ArrowTheme.bone)
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .padding(5)
                .focused($focused)
        }
        .overlay(alignment: .bottomTrailing) {
            Text(state.notes.isSaved ? "SAVED" : "SAVING…")
                .font(.system(size: 7.5, weight: .bold)).tracking(1)
                .foregroundStyle(state.notes.isSaved ? ArrowTheme.green : ArrowTheme.amber)
                .padding(7)
        }
        .overlay { RoundedRectangle(cornerRadius: 10).stroke(ArrowTheme.hairline, lineWidth: 0.5) }
        .onAppear { focused = true }
        .onDisappear { state.notes.save() }
    }
}

private struct CompactStats: View {
    @Bindable var state: AppState

    var body: some View {
        HStack(spacing: 10) {
            CompactStat(label: "CPU", value: state.stats.hasReading ? StatsMath.percent(state.stats.cpu) : "—", detail: "\(ProcessInfo.processInfo.activeProcessorCount) cores", share: state.stats.hasReading ? state.stats.cpu : 0, level: StatsMath.level(state.stats.cpu))
            CompactStat(label: "MEMORY", value: StatsMath.percent(state.stats.memoryShare), detail: "\(StatsMath.bytes(state.stats.memoryUsed)) of \(StatsMath.bytes(state.stats.memoryTotal))", share: state.stats.memoryShare, level: state.stats.pressure)
        }
        .onAppear { state.stats.start() }
        .onDisappear { state.stats.stop() }
    }
}

private struct CompactStat: View {
    let label: String
    let value: String
    let detail: String
    let share: Double
    let level: UsageLevel

    private var color: Color {
        switch level {
        case .normal: ArrowTheme.green
        case .busy: ArrowTheme.amber
        case .high: ArrowTheme.red
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.system(size: 7.5, weight: .bold)).tracking(1).foregroundStyle(ArrowTheme.faint)
            Text(value).font(.system(size: 24, weight: .semibold, design: .rounded)).foregroundStyle(ArrowTheme.bone).monospacedDigit()
            Text(detail).font(.system(size: 8.5)).foregroundStyle(ArrowTheme.muted).lineLimit(1)
            Spacer(minLength: 0)
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.08))
                    Capsule().fill(color).frame(width: max(3, geometry.size.width * CGFloat(share)))
                }
            }
            .frame(height: 3)
        }
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: 10).fill(ArrowTheme.panel))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(ArrowTheme.hairline, lineWidth: 0.5))
    }
}

private struct CompactStopwatch: View {
    @Bindable var state: AppState
    private var stopwatch: StopwatchService { state.stopwatch }

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 1) {
                Text(stopwatch.isRunning ? "RUNNING" : (stopwatch.elapsed > 0 ? "PAUSED" : "READY"))
                    .font(.system(size: 7.5, weight: .bold))
                    .tracking(1.2)
                    .foregroundStyle(stopwatch.isRunning ? ArrowTheme.amber : ArrowTheme.faint)
                Text(ClockFormat.clock(stopwatch.elapsed, tenths: true))
                    .font(.system(size: 42, weight: .light, design: .monospaced))
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
            .buttonStyle(.plain)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(ArrowTheme.ink)
            .padding(.horizontal, 12)
            .frame(height: 27)
            .background(Capsule().fill(ArrowTheme.amber))
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
                .buttonStyle(.plain)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(ArrowTheme.ink)
                .padding(.horizontal, 11)
                .frame(height: 26)
                .background(Capsule().fill(ArrowTheme.amber))
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
