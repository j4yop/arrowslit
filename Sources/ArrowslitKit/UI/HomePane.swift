import AppKit
import SwiftUI

/// Home: the compact media card, the next calendar event, and quick timer actions, separated
/// by a hairline like the Notch Shell Home row.
struct HomePane: View {
    @Bindable var state: AppState

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            HomeMediaCard(state: state)
                .frame(width: 196)

            HomeCalendarColumn(state: state)
                .frame(width: 156)

            Rectangle()
                .fill(ArrowTheme.hairline)
                .frame(width: 1)
                .padding(.vertical, 2)

            HomeTimerColumn(state: state)
                .frame(width: 148)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: Media

private struct HomeMediaCard: View {
    @Bindable var state: AppState
    private var service: NowPlayingService { state.nowPlaying }
    @State private var isHovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let track = service.track, track.hasContent {
                playing(track)
            } else {
                empty
            }
        }
        .padding(9)
        .frame(width: 196, height: 132, alignment: .top)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.07))
        )
        .overlay(alignment: .topTrailing) {
            if service.track?.hasContent == true {
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
        .onChange(of: service.track) { _, _ in updateLyrics() }
        .onChange(of: state.settings.lyricsEnabled) { _, _ in updateLyrics() }
    }

    private func playing(_ track: NowPlayingTrack) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 9) {
                artwork
                    .frame(width: 52, height: 52)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .contentShape(Rectangle())
                    .onTapGesture { state.expand(.nowPlaying) }
                    .help("Open Now Playing")

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
                PlayerGlyphButton(symbol: "backward.fill", size: 18, label: "Previous Track") {
                    service.previous()
                }
                PlayerGlyphButton(
                    symbol: track.isPlaying ? "pause.fill" : "play.fill",
                    size: 25,
                    label: track.isPlaying ? "Pause" : "Play"
                ) {
                    service.toggle()
                }
                PlayerGlyphButton(symbol: "forward.fill", size: 18, label: "Next Track") {
                    service.next()
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var artwork: some View {
        Group {
            if let artwork = service.artwork {
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
        state.lyrics.update(for: service.track, enabled: state.settings.lyricsEnabled)
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
