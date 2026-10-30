import SwiftUI

/// Corbel-style Home: a media card on the left and 30 pt rows on the right.
struct HomePane: View {
    @Bindable var state: AppState

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            MediaCard(state: state)
                .frame(width: 210)
                .frame(maxHeight: .infinity)

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
        let track = service.track
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 9) {
                Group {
                    if let image = service.artwork {
                        Image(nsImage: image).resizable().interpolation(.high).aspectRatio(contentMode: .fill)
                    } else {
                        ZStack { Color.white.opacity(0.12); Image(systemName: "music.note").font(.system(size: 16, weight: .semibold)).foregroundStyle(.white.opacity(0.7)) }
                    }
                }
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(track?.title.isEmpty == false ? track!.title : "Nothing playing")
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(ArrowTheme.bone)
                        .lineLimit(1)
                    Text(track?.artist.isEmpty == false ? track!.artist : "Play something to begin")
                        .font(.system(size: 9.5))
                        .foregroundStyle(ArrowTheme.muted)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if let track {
                    MusicBars(isPlaying: track.isPlaying, color: state.nowPlaying.accent.color, height: 16)
                        .padding(.top, 1)
                }
            }

            if let track {
                TimelineView(.animation(minimumInterval: 1, paused: !track.isPlaying)) { context in
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.white.opacity(0.18))
                            Capsule().fill(ArrowTheme.bone.opacity(0.8))
                                .frame(width: geometry.size.width * CGFloat(track.progress(at: context.date) ?? 0))
                        }
                    }
                }
                .frame(height: 3)

                HStack(spacing: 16) {
                    Button { service.previous() } label: { Image(systemName: "backward.fill").font(.system(size: 10, weight: .semibold)) }
                    Button { service.toggle() } label: { Image(systemName: track.isPlaying ? "pause.fill" : "play.fill").font(.system(size: 13, weight: .semibold)) }
                    Button { service.next() } label: { Image(systemName: "forward.fill").font(.system(size: 10, weight: .semibold)) }
                }
                .buttonStyle(NookPressStyle())
                .foregroundStyle(ArrowTheme.bone)
                .frame(maxWidth: .infinity)
            } else {
                Spacer(minLength: 0)
            }
        }
        .padding(9)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(RoundedRectangle(cornerRadius: 13, style: .continuous).fill(Color.white.opacity(0.07)))
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
                HStack(spacing: 8) {
                    Image(systemName: "timer").font(.system(size: 11, weight: .semibold)).foregroundStyle(ArrowTheme.amber).frame(width: 16)
                    Text("Timer").font(.system(size: 11, weight: .semibold)).foregroundStyle(ArrowTheme.bone)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(NookPressStyle())
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
