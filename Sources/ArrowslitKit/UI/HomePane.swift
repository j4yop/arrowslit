import AppKit
import SwiftUI

/// Home: up to three sections side by side, split by hairlines, like Notch Shell's standard
/// nook. The live media card only takes a section while something is playing; otherwise the
/// calendar and timer share the full width.
struct HomePane: View {
    @Bindable var state: AppState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private enum Section: String, CaseIterable, Identifiable {
        case live
        case calendar
        case timer
        case shortcuts

        var id: String { rawValue }
    }

    private var showsMedia: Bool {
        state.settings.isTabEnabled(.nowPlaying) && state.nowPlaying.activeTrack?.hasContent == true
    }

    private var showsCalendar: Bool {
        state.settings.isTabEnabled(.calendar)
    }

    private var showsTimer: Bool {
        state.settings.isTabEnabled(.timer)
    }

    private var showsShortcuts: Bool {
        state.settings.shortcutsEnabled && !state.settings.favoriteShortcuts.isEmpty
    }

    private var sections: [Section] {
        var result: [Section] = []
        if showsMedia { result.append(.live) }
        if showsCalendar { result.append(.calendar) }
        if showsTimer { result.append(.timer) }
        if showsShortcuts, result.count < 3 { result.append(.shortcuts) }
        return result
    }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(Array(sections.enumerated()), id: \.element) { index, section in
                if index > 0 {
                    Rectangle()
                        .fill(ArrowTheme.hairline)
                        .frame(width: 1)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                }
                view(for: section)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .transition(.scale(scale: 0.96, anchor: .leading).combined(with: .opacity))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .overlay {
            if sections.isEmpty {
                Text("Nothing live right now")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(ArrowTheme.muted)
            }
        }
        .animation(NookMotion.reducing(.spring(duration: 0.35, bounce: 0.15), reduceMotion: reduceMotion), value: sections)
    }

    @ViewBuilder
    private func view(for section: Section) -> some View {
        switch section {
        case .live:
            HomeMediaCard(state: state)
                .frame(width: 196)
        case .calendar:
            HomeCalendarColumn(state: state)
        case .timer:
            HomeTimerColumn(state: state)
        case .shortcuts:
            HomeShortcutsColumn(state: state)
        }
    }
}

// MARK: Media

private struct HomeMediaCard: View {
    @Bindable var state: AppState
    var width: CGFloat = 196
    private var service: NowPlayingService { state.nowPlaying }
    @State private var isHovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let track = service.activeTrack, track.hasContent {
                playing(track)
            } else {
                empty
            }
        }
        .padding(8)
        .frame(width: width, height: 120, alignment: .top)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.07))
        )
        .overlay(alignment: .topTrailing) {
            if service.activeTrack?.hasContent == true {
                MediaCardExpandButton {
                    state.expand(.nowPlaying)
                }
                .padding(4)
                .opacity(isHovering ? 1 : 0)
            }
        }
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.12)) { isHovering = hovering }
        }
        .onAppear { updateLyrics() }
        .onChange(of: service.activeTrack) { _, _ in updateLyrics() }
        .onChange(of: state.settings.lyricsEnabled) { _, _ in updateLyrics() }
    }

    private func playing(_ track: NowPlayingTrack) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top, spacing: 9) {
                artwork
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .contentShape(Rectangle())
                    .onTapGesture { state.expand(.nowPlaying) }
                    .help("Open Now Playing")

                VStack(alignment: .leading, spacing: 2) {
                    MediaTitle(title: track.title, isPlaying: track.isPlaying, fontSize: 15)
                        .foregroundStyle(ArrowTheme.bone)
                    Text(track.artist.isEmpty ? "Unknown artist" : track.artist)
                        .font(.system(size: 12))
                        .foregroundStyle(ArrowTheme.muted)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture { state.expand(.nowPlaying) }
                .help("Open Now Playing")
            }

            TimelineView(.animation(minimumInterval: 0.2, paused: !track.isPlaying)) { context in
                Text(lyric(at: context.date, track: track) ?? (track.album.isEmpty ? " " : track.album))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(ArrowTheme.bone)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            progress(track)

            HStack(spacing: 14) {
                PlayerGlyphButton(symbol: "backward.fill", size: 16, label: "Previous Track") {
                    service.previous()
                }
                PlayerGlyphButton(
                    symbol: track.isPlaying ? "pause.fill" : "play.fill",
                    size: 22,
                    label: track.isPlaying ? "Pause" : "Play"
                ) {
                    service.toggle()
                }
                PlayerGlyphButton(symbol: "forward.fill", size: 16, label: "Next Track") {
                    service.next()
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var artwork: some View {
        Group {
            if let artwork = service.activeArtwork {
                Image(nsImage: artwork)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fill)
            } else {
                ZStack {
                    ArrowTheme.ink
                    SlitMark(height: 22, color: ArrowTheme.amber.opacity(0.8))
                }
            }
        }
    }

    private func progress(_ track: NowPlayingTrack) -> some View {
        TimelineView(.animation(minimumInterval: 0.5, paused: !track.isPlaying)) { context in
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.2))
                    Capsule()
                        .fill(Color.white.opacity(0.85))
                        .frame(width: max(0, geometry.size.width * CGFloat(track.progress(at: context.date) ?? 0)))
                }
            }
        }
        .frame(height: 3)
        .accessibilityHidden(true)
    }

    private func lyric(at date: Date, track: NowPlayingTrack) -> String? {
        guard state.settings.lyricsEnabled,
              let lyrics = state.lyrics.current,
              let elapsed = track.elapsed(at: date),
              let index = lyrics.index(at: elapsed + 0.3) else { return nil }
        let text = lyrics.lines[index].text
        return text.isEmpty ? nil : text
    }

    private func updateLyrics() {
        state.lyrics.update(for: service.activeTrack, enabled: state.settings.lyricsEnabled)
    }

    private var empty: some View {
        VStack(spacing: 6) {
            SlitMark(height: 24, color: ArrowTheme.faint)
            Text("Nothing playing")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(ArrowTheme.bone)
            Text("Play something to begin")
                .font(.system(size: 10.5))
                .foregroundStyle(ArrowTheme.muted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// The small expand affordance appears when the pointer is over the media card.
private struct MediaCardExpandButton: View {
    let action: () -> Void
    @State private var isHovering = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
            Image(systemName: "arrow.up.left.and.arrow.down.right")
                .font(.system(size: 9.5, weight: .semibold))
                .foregroundStyle(isHovering ? ArrowTheme.bone : ArrowTheme.muted)
                .frame(width: 20, height: 20)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(isHovering ? Color.white.opacity(0.12) : Color.black.opacity(0.35))
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(NookPressStyle(pressedScale: 0.94))
        .onHover { hovering in
            withAnimation(NookMotion.reducing(NookMotion.hover, reduceMotion: reduceMotion)) {
                isHovering = hovering
            }
        }
        .help("Open Now Playing")
        .accessibilityLabel("Open Now Playing")
    }
}

// MARK: Shortcuts

private struct HomeShortcutsColumn: View {
    @Bindable var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                Text("Shortcuts")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(ArrowTheme.bone)
                Spacer(minLength: 0)
            }
            ForEach(state.settings.favoriteShortcuts.prefix(3), id: \.self) { name in
                let isRunning = state.shortcuts.running.contains(name)
                Button { state.shortcuts.run(name) } label: {
                    HStack(spacing: 6) {
                        if isRunning {
                            ProgressView().controlSize(.mini)
                        }
                        Text(name)
                            .font(.system(size: 11.5, weight: .medium))
                            .foregroundStyle(ArrowTheme.bone)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 8)
                    .frame(height: 26)
                    .background(Capsule().fill(Color.white.opacity(0.09)))
                    .contentShape(Capsule())
                }
                .buttonStyle(NookPressStyle())
                .disabled(isRunning)
                .help("Run \(name)")
                .accessibilityLabel("Run shortcut \(name)")
            }
            Spacer(minLength: 0)
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .onAppear { state.shortcuts.reload() }
    }
}

// MARK: Calendar

private struct HomeCalendarColumn: View {
    @Bindable var state: AppState
    private var calendar: CalendarService { state.calendar }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button { state.select(.calendar) } label: {
                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color(red: 1, green: 0.27, blue: 0.23))
                    Text("Calendar")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(ArrowTheme.bone)
                    Image(systemName: "chevron.forward")
                        .font(.system(size: 8.5, weight: .bold))
                        .foregroundStyle(ArrowTheme.faint)
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(NookPressStyle())
            .help("Open Calendar")

            switch calendar.access {
            case .notAsked:
                Button("Connect") { calendar.requestAccess() }
                    .buttonStyle(HomeQuickActionStyle(tint: Color(red: 1, green: 0.27, blue: 0.23)))
            case .denied, .limited:
                Button("Allow Access") { calendar.openPrivacySettings() }
                    .buttonStyle(HomeQuickActionStyle(tint: Color(red: 1, green: 0.27, blue: 0.23)))
            case .granted:
                if let event = calendar.nextEvent {
                    Button { state.select(.calendar) } label: {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: eventSymbol(event))
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(ArrowTheme.bone)
                                .frame(width: 18)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(event.title)
                                    .font(.system(size: 14.5, weight: .semibold))
                                    .foregroundStyle(ArrowTheme.bone)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                                Text(event.start.formatted(date: .omitted, time: .shortened))
                                    .font(.system(size: 13))
                                    .foregroundStyle(ArrowTheme.muted)
                                    .lineLimit(1)
                            }
                            Spacer(minLength: 0)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(NookPressStyle())
                    .help("Open Calendar")
                } else {
                    Text("No more events this week")
                        .font(.system(size: 12))
                        .foregroundStyle(ArrowTheme.muted)
                }
            }

            Spacer(minLength: 0)
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private func eventSymbol(_ event: CalendarEvent) -> String {
        let title = event.title.lowercased()
        let sports = ["fc", "real", "sevilla", "madrid", "atlético", "atletico", "racing", "elche", "valencia", "deportivo"]
        return sports.contains(where: title.contains) ? "soccerball" : "calendar"
    }
}

// MARK: Timer

private struct HomeTimerColumn: View {
    @Bindable var state: AppState
    private var timer: TimerService { state.timer }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button { state.select(.timer) } label: {
                HStack(spacing: 6) {
                    Image(systemName: "timer")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(ArrowTheme.amber)
                    Text("Timer")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(ArrowTheme.bone)
                    Image(systemName: "chevron.forward")
                        .font(.system(size: 8.5, weight: .bold))
                        .foregroundStyle(ArrowTheme.faint)
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(NookPressStyle())
            .help("Open Timer")

            HStack(spacing: 6) {
                ForEach([5, 10, 15], id: \.self) { minutes in
                    Button("\(minutes)m") { state.startTimer(minutes: minutes) }
                        .buttonStyle(HomeQuickActionStyle(tint: ArrowTheme.amber, width: 40))
                        .accessibilityLabel("Start \(minutes) minute timer")
                }
            }

            Button { state.startFocus() } label: {
                Label("Focus \(timer.focusMinutes)m", systemImage: "hand.raised.fill")
                    .labelStyle(.titleAndIcon)
            }
            .buttonStyle(HomeQuickActionStyle(tint: ArrowTheme.amber))
            .accessibilityLabel("Start a \(timer.focusMinutes) minute focus session")

            Spacer(minLength: 0)
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }
}

/// The elongated Home: one long, short row of widgets split by hairlines and scrolled
/// sideways, following Notch Shell's 1240 pt layout.
struct ElongatedHomePane: View {
    @Bindable var state: AppState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private enum Widget: Hashable {
        case media
        case calendar
        case timer
        case notes
        case sports
        case todos

        var width: CGFloat {
            switch self {
            case .media: 290
            case .calendar: 300
            case .timer: 250
            case .notes: 230
            case .sports: 280
            case .todos: 230
            }
        }
    }

    private var widgets: [Widget] {
        var result: [Widget] = []
        if state.settings.isTabEnabled(.nowPlaying), state.nowPlaying.activeTrack?.hasContent == true {
            result.append(.media)
        }
        if state.settings.isTabEnabled(.calendar) { result.append(.calendar) }
        if state.settings.isTabEnabled(.timer) { result.append(.timer) }
        result.append(.todos)
        if state.settings.isTabEnabled(.notes) { result.append(.notes) }
        if state.settings.isTabEnabled(.sports) { result.append(.sports) }
        return result
    }

    var body: some View {
        let scale = state.settings.appearance.size.scale
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(Array(widgets.enumerated()), id: \.element) { index, widget in
                    if index > 0 {
                        Rectangle()
                            .fill(ArrowTheme.hairline)
                            .frame(width: 1)
                            .padding(.vertical, 10)
                    }
                    view(for: widget)
                        .frame(width: widget.width * scale)
                        .frame(maxHeight: .infinity)
                        .padding(.leading, index == 0 ? 0 : 16)
                        .padding(.trailing, index == widgets.count - 1 ? 0 : 16)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .overlay {
            if widgets.isEmpty {
                Text("Nothing live right now")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(ArrowTheme.muted)
            }
        }
        .animation(NookMotion.reducing(.spring(duration: 0.35, bounce: 0.15), reduceMotion: reduceMotion), value: widgets)
    }

    @ViewBuilder
    private func view(for widget: Widget) -> some View {
        switch widget {
        case .media:
            HomeMediaCard(state: state, width: 290)
        case .calendar:
            HomeCalendarColumn(state: state)
        case .timer:
            HomeTimerColumn(state: state)
        case .notes:
            ElongatedNotesWidget(state: state)
        case .sports:
            ElongatedSportsWidget(state: state)
        case .todos:
            ElongatedTodosWidget(state: state)
        }
    }
}

private struct ElongatedTodosWidget: View {
    @Bindable var state: AppState
    @State private var draft = ""
    @FocusState private var isTyping: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "plus.circle")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(isTyping ? Color.accentColor : ArrowTheme.muted)
                TextField("New task…", text: $draft)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(ArrowTheme.bone)
                    .focused($isTyping)
                    .onSubmit {
                        withAnimation(.snappy(duration: 0.3)) { state.todos.add(draft) }
                        draft = ""
                    }
            }
            .padding(.horizontal, 8)
            .frame(height: 26)
            .background(Capsule().fill(Color.white.opacity(isTyping ? 0.12 : 0.07)))
            .onChange(of: isTyping) { _, typing in state.isTypingInNook = typing }

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(state.todos.ordered) { item in
                        TodoRow(item: item) {
                            withAnimation(.snappy(duration: 0.3)) { state.todos.toggle(item.id) }
                        } remove: {
                            withAnimation(.snappy(duration: 0.3)) { state.todos.remove(item.id) }
                        }
                    }
                }
            }
            .frame(maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.top, 2)
    }
}

private struct TodoRow: View {
    let item: TodoStore.Item
    let toggle: () -> Void
    let remove: () -> Void
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 6) {
            Button(action: toggle) {
                Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 12))
                    .foregroundStyle(item.isDone ? Color.accentColor : ArrowTheme.muted)
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(item.isDone ? "Mark \(item.title) as not done" : "Complete \(item.title)")

            Text(item.title)
                .font(.system(size: 10.5, weight: .medium))
                .strikethrough(item.isDone, color: ArrowTheme.muted)
                .foregroundStyle(item.isDone ? ArrowTheme.muted : ArrowTheme.bone)
                .lineLimit(1)

            Spacer(minLength: 2)
            if isHovering {
                Button(action: remove) {
                    Image(systemName: "xmark")
                        .font(.system(size: 7.5, weight: .bold))
                        .foregroundStyle(ArrowTheme.muted)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Delete \(item.title)")
            }
        }
        .frame(height: 19)
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
    }
}

private struct ElongatedNotesWidget: View {
    @Bindable var state: AppState

    var body: some View {
        Button { state.select(.notes) } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "note.text")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color(red: 1, green: 0.84, blue: 0.35))
                    Text("Notes")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(ArrowTheme.bone)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.forward")
                        .font(.system(size: 8.5, weight: .bold))
                        .foregroundStyle(ArrowTheme.faint)
                }
                Text(state.notes.isEmpty ? "A quick note, saved as you type." : state.notes.text)
                    .font(.system(size: 12))
                    .foregroundStyle(state.notes.isEmpty ? ArrowTheme.muted : ArrowTheme.bone)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .contentShape(Rectangle())
        }
        .buttonStyle(NookPressStyle())
        .help("Open Notes")
        .accessibilityLabel("Open Notes")
    }
}

private struct ElongatedSportsWidget: View {
    @Bindable var state: AppState

    private var match: SportsMatch? { state.sports.availableMatches.first }

    var body: some View {
        Button { state.select(.sports) } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "soccerball")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color(red: 0.28, green: 0.78, blue: 0.52))
                    Text("Sports")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(ArrowTheme.bone)
                    Spacer(minLength: 0)
                    if state.sports.liveCount > 0 {
                        Text("\(state.sports.liveCount) live")
                            .font(.system(size: 9.5, weight: .semibold))
                            .foregroundStyle(ArrowTheme.green)
                    }
                    Image(systemName: "chevron.forward")
                        .font(.system(size: 8.5, weight: .bold))
                        .foregroundStyle(ArrowTheme.faint)
                }
                if let match {
                    Text("\(match.home.shortName)  \(match.homeScore.map(String.init) ?? "–")  –  \(match.awayScore.map(String.init) ?? "–")  \(match.away.shortName)")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(ArrowTheme.bone)
                        .lineLimit(1)
                    Text(SportsFormat.shortStatus(match))
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(match.state.isLive ? ArrowTheme.green : ArrowTheme.muted)
                } else {
                    Text("No matches in your competitions.")
                        .font(.system(size: 12))
                        .foregroundStyle(ArrowTheme.muted)
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .contentShape(Rectangle())
        }
        .buttonStyle(NookPressStyle())
        .help("Open Sports")
        .accessibilityLabel("Open Sports")
    }
}

/// Soft grey capsule, tinted label, hover lift and a spring press — the Home quick actions.
private struct HomeQuickActionStyle: ButtonStyle {
    var tint: Color
    var width: CGFloat?

    func makeBody(configuration: Configuration) -> some View {
        HomeQuickActionBody(configuration: configuration, tint: tint, width: width)
    }
}

private struct HomeQuickActionBody: View {
    let configuration: ButtonStyleConfiguration
    let tint: Color
    let width: CGFloat?
    @State private var isHovering = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .monospacedDigit()
            .lineLimit(1)
            .foregroundStyle(tint)
            .padding(.horizontal, 9)
            .frame(minWidth: width, minHeight: 28, maxHeight: 28)
            .background(
                Capsule()
                    .fill(Color.white.opacity(configuration.isPressed ? 0.20 : (isHovering ? 0.14 : 0.09)))
            )
            .contentShape(Capsule())
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(NookMotion.reducing(.spring(duration: 0.2, bounce: 0.3), reduceMotion: reduceMotion), value: configuration.isPressed)
            .animation(NookMotion.reducing(.easeOut(duration: 0.12), reduceMotion: reduceMotion), value: isHovering)
            .onHover { isHovering = $0 }
            .fixedSize(horizontal: width == nil, vertical: true)
    }
}
