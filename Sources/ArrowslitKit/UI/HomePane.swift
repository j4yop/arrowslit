import SwiftUI

/// Corbel-style Home: a media card on the left and 30 pt rows on the right.
struct HomePane: View {
    @Bindable var state: AppState

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            MediaCard(state: state)
                .frame(width: 306)

            VStack(alignment: .leading, spacing: 8) {
                CalendarHomeRow(state: state)
                    .frame(height: 30)
                TimerHomeRow(state: state)
                    .frame(height: 30)
                SystemHomeRow(state: state)
                    .frame(height: 30)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
}

private struct MediaCard: View {
    @Bindable var state: AppState
    private var service: NowPlayingService { state.nowPlaying }

    var body: some View {
        VStack(spacing: 0) {
            if let track = service.track, track.hasContent {
                playing(track)
            } else {
                empty
            }
        }
        .padding(15)
        .frame(width: 306, height: 146, alignment: .top)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(ArrowTheme.panel)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(ArrowTheme.hairline, lineWidth: 0.5)
        }
    }

    private func playing(_ track: NowPlayingTrack) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Group {
                if let artwork = service.artwork {
                    Image(nsImage: artwork)
                        .resizable()
                        .interpolation(.high)
                        .aspectRatio(contentMode: .fill)
                } else {
                    ZStack {
                        ArrowTheme.ink
                        SlitMark(height: 28, color: ArrowTheme.amber.opacity(0.8))
                    }
                }
            }
            .frame(width: 110, height: 110)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .contentShape(Rectangle())
            .onTapGesture { state.expand(.nowPlaying) }
            .help("Open Now Playing")

            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top, spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(track.title)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(ArrowTheme.bone)
                            .lineLimit(1)
                        Text(track.artist.isEmpty ? "Unknown artist" : track.artist)
                            .font(.system(size: 12))
                            .foregroundStyle(ArrowTheme.muted)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .onTapGesture { state.expand(.nowPlaying) }
                    .help("Open Now Playing")

                    HStack(spacing: 6) {
                        MusicBars(
                            isPlaying: track.isPlaying,
                            color: service.accent.color,
                            height: 16,
                            width: 18
                        )

                        MediaCardExpandButton {
                            state.expand(.nowPlaying)
                        }
                    }
                }

                Spacer(minLength: 4)

                HStack(spacing: 14) {
                    PlayerGlyphButton(symbol: "backward.fill", size: 19, label: "Previous Track") {
                        service.previous()
                    }
                    PlayerGlyphButton(
                        symbol: track.isPlaying ? "pause.fill" : "play.fill",
                        size: 27,
                        label: track.isPlaying ? "Pause" : "Play"
                    ) {
                        service.toggle()
                    }
                    PlayerGlyphButton(symbol: "forward.fill", size: 19, label: "Next Track") {
                        service.next()
                    }
                }
                .frame(maxWidth: .infinity)

                PlayerProgressRow(state: state)
                    .padding(.top, 5)
            }
        }
        .frame(height: 116, alignment: .top)
    }

    private var empty: some View {
        VStack(spacing: 8) {
            SlitMark(height: 26, color: ArrowTheme.faint)
            Text("Nothing playing")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(ArrowTheme.bone)
            Text("Play something to begin")
                .font(.system(size: 11))
                .foregroundStyle(ArrowTheme.muted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// The small, always-visible affordance that opens the full Now Playing player.
private struct MediaCardExpandButton: View {
    let action: () -> Void
    @State private var isHovering = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
            Image(systemName: "arrow.up.left.and.arrow.down.right")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(isHovering ? ArrowTheme.bone : ArrowTheme.muted)
                .frame(width: 24, height: 24)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(isHovering ? Color.white.opacity(0.10) : .clear)
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

private struct CalendarHomeRow: View {
    @Bindable var state: AppState
    private var calendar: CalendarService { state.calendar }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "calendar")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color(red: 1, green: 0.27, blue: 0.23))
                .frame(width: 16)
            switch calendar.access {
            case .notAsked:
                Text("Calendar").font(.system(size: 11, weight: .semibold)).foregroundStyle(ArrowTheme.bone)
                Spacer()
                Button("Connect") { calendar.requestAccess() }.buttonStyle(HomeChipStyle())
            case .denied, .limited:
                Text("Calendar").font(.system(size: 11, weight: .semibold)).foregroundStyle(ArrowTheme.bone)
                Spacer()
                Button("Allow Access") { calendar.openPrivacySettings() }.buttonStyle(HomeChipStyle())
            case .granted:
                if let event = calendar.nextEvent {
                    Button { state.select(.calendar) } label: {
                        HStack(spacing: 6) {
                            Text(event.title).font(.system(size: 11, weight: .semibold)).foregroundStyle(ArrowTheme.bone).lineLimit(1)
                            Spacer()
                            Text(label(event)).font(.system(size: 10, weight: .medium)).monospacedDigit().foregroundStyle(event.isHappening(at: Date()) ? ArrowTheme.green : ArrowTheme.muted).lineLimit(1)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(NookPressStyle())
                } else {
                    Text("No more events this week").font(.system(size: 11)).foregroundStyle(ArrowTheme.muted)
                    Spacer()
                }
            }
        }
    }

    private func label(_ event: CalendarEvent) -> String {
        if event.isHappening(at: Date()) { return "now" }
        let minutes = Int((event.start.timeIntervalSinceNow / 60).rounded(.up))
        if minutes < 60 { return "in \(max(minutes, 1)) min" }
        if minutes < 120 { return "in 1 hr" }
        return event.start.formatted(date: .omitted, time: .shortened)
    }
}

private struct TimerHomeRow: View {
    @Bindable var state: AppState

    var body: some View {
        HStack(spacing: 6) {
            Button { state.select(.timer) } label: {
                Image(systemName: "timer")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(ArrowTheme.amber)
                    .frame(width: 16)
                    .contentShape(Rectangle())
            }
            .buttonStyle(NookPressStyle())
            .help("Timer")
            .accessibilityLabel("Timer")
            Spacer(minLength: 6)
            ForEach([5, 10, 25], id: \.self) { minutes in
                Button("\(minutes)m") { state.startTimer(minutes: minutes) }
                    .buttonStyle(HomeChipStyle())
            }
            Button { state.startFocus() } label: {
                Image(systemName: "hand.raised.fill")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(ArrowTheme.ink)
                    .frame(width: 26, height: 22)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(ArrowTheme.amber)
                    )
            }
            .buttonStyle(NookPressStyle())
            .help("Start a 25 minute focus session")
        }
    }
}

private struct SystemHomeRow: View {
    @Bindable var state: AppState

    var body: some View {
        Button { state.select(.stats) } label: {
            HStack(spacing: 8) {
                Image(systemName: "gauge.with.dots.needle.33percent")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(ArrowTheme.green)
                    .frame(width: 16)
                Text("System").font(.system(size: 11, weight: .semibold)).foregroundStyle(ArrowTheme.bone)
                Spacer()
                Text("CPU \(state.stats.hasReading ? StatsMath.percent(state.stats.cpu) : "—")")
                    .font(.system(size: 10, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(ArrowTheme.muted)
                Text("Memory \(StatsMath.percent(state.stats.memoryShare))")
                    .font(.system(size: 10, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(ArrowTheme.muted)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(NookPressStyle())
        .onAppear { state.stats.start() }
        .onDisappear { state.stats.stop() }
    }
}

private struct HomeChipStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(ArrowTheme.bone)
            .padding(.horizontal, 8)
            .frame(height: 22)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.white.opacity(configuration.isPressed ? 0.18 : 0.1))
            )
            .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}
