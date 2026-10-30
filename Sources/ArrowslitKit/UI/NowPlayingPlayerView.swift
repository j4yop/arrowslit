import AppKit
import SwiftUI

/// The expanded music activity: the notch-sized player from Dynamic Ledge's layout, built with
/// Arrowslit's own SwiftUI and animation code.
struct NowPlayingPlayerView: View {
    @Bindable var state: AppState

    private var service: NowPlayingService { state.nowPlaying }
    private var track: NowPlayingTrack? { service.track }

    var body: some View {
        VStack(spacing: 0) {
            header
            if let track, track.hasContent {
                player(track, lyrics: state.lyrics.current)
            } else {
                empty
            }
            Spacer(minLength: 0)
        }
        .padding(.bottom, 14)
        .frame(width: NotchPanelMetrics.playerSize.width, height: NotchPanelMetrics.playerSize.height)
        .background(ArrowTheme.ink)
        .clipShape(SlitShape(radius: 18))
        .overlay {
            SlitShape(radius: 18)
                .stroke(ArrowTheme.hairline, lineWidth: 0.5)
        }
        .onAppear { updateLyrics() }
        .onChange(of: service.track) { _, _ in updateLyrics() }
        .onChange(of: state.settings.lyricsEnabled) { _, _ in updateLyrics() }
        .accessibilityElement(children: .contain)
    }

    private var header: some View {
        HStack {
            Button {
                state.expand(.home)
            } label: {
                Image(systemName: "chevron.backward")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PlayerPressStyle())
            .help("Home")
            .accessibilityLabel("Back to Home")
            Spacer()
        }
        .padding(.leading, 14)
        .frame(height: 32)
    }

    private func player(_ track: NowPlayingTrack, lyrics: SyncedLyrics?) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                artwork
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(track.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(ArrowTheme.bone)
                        .lineLimit(1)
                    Text(track.artist.isEmpty ? "Unknown artist" : track.artist)
                        .font(.system(size: 13))
                        .foregroundStyle(ArrowTheme.muted)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                MusicBars(
                    isPlaying: track.isPlaying,
                    color: service.accent.color,
                    height: 18,
                    width: 20
                )
            }
            .frame(height: 56)

            lyricsLine(track, lyrics: lyrics)
                .padding(.top, 8)
                .frame(height: 34)

            PlayerProgressRow(state: state)
                .padding(.top, 10)

            HStack(spacing: 30) {
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
            .padding(.top, 4)
        }
        .padding(.horizontal, 22)
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
                    ArrowTheme.panel
                    SlitMark(height: 26, color: ArrowTheme.amber.opacity(0.8))
                }
            }
        }
    }

    private func lyricsLine(_ track: NowPlayingTrack, lyrics: SyncedLyrics?) -> some View {
        TimelineView(.animation(minimumInterval: 0.2, paused: !track.isPlaying)) { context in
            let index = track.elapsed(at: context.date).flatMap { elapsed in
                lyrics?.index(at: elapsed + 0.3)
            }
            let text = index.flatMap { lyrics?.lines[$0].text } ?? ""
            ZStack {
                Text(text.isEmpty ? "♪" : text)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(text.isEmpty ? ArrowTheme.muted : ArrowTheme.bone)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .multilineTextAlignment(.center)
                    .id(index ?? -1)
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .move(edge: .top).combined(with: .opacity)
                    ))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
            .animation(.smooth(duration: 0.35), value: index)
        }
        .accessibilityElement()
        .accessibilityLabel("Lyrics")
    }

    private var empty: some View {
        VStack(spacing: 8) {
            Image(systemName: "music.note")
                .font(.system(size: 24, weight: .regular))
                .foregroundStyle(ArrowTheme.faint)
            Text(service.isAvailable ? "Nothing is playing" : "Media access is unavailable")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(ArrowTheme.muted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func updateLyrics() {
        state.lyrics.update(for: service.track, enabled: state.settings.lyricsEnabled)
    }
}

private struct PlayerProgressRow: View {
    @Bindable var state: AppState
    @State private var scrubProgress: Double?

    private var service: NowPlayingService { state.nowPlaying }

    var body: some View {
        let track = service.track
        TimelineView(.animation(minimumInterval: 0.5, paused: track?.isPlaying != true)) { context in
            let duration = track?.duration
            let elapsed = track?.elapsed(at: context.date) ?? 0
            let shownElapsed = scrubProgress.flatMap { value in duration.map { $0 * value } } ?? elapsed
            let progress = scrubProgress ?? track?.progress(at: context.date) ?? 0
            HStack(spacing: 10) {
                Text(ClockFormat.clock(shownElapsed))
                    .frame(width: 40, alignment: .leading)
                PlayerScrubBar(progress: progress, isEnabled: duration != nil) { value, ended in
                    scrubProgress = ended ? nil : value
                    if ended, let duration {
                        service.seek(to: value * duration)
                    }
                }
                Text(duration.map { "-" + ClockFormat.clock(max(0, $0 - shownElapsed), roundingUp: true) } ?? "--:--")
                    .frame(width: 44, alignment: .trailing)
            }
            .font(.system(size: 11, weight: .medium))
            .monospacedDigit()
            .foregroundStyle(ArrowTheme.muted)
        }
    }
}

private struct PlayerScrubBar: View {
    var progress: Double
    var isEnabled: Bool
    var onScrub: (Double, Bool) -> Void
    @State private var isDragging = false

    var body: some View {
        GeometryReader { geometry in
            let width = max(geometry.size.width, 1)
            let clamped = min(max(progress, 0), 1)
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.2))
                Capsule()
                    .fill(Color.white)
                    .frame(width: width * clamped)
            }
            .frame(height: isDragging ? 8 : 5)
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard isEnabled else { return }
                        isDragging = true
                        onScrub(min(max(value.location.x / width, 0), 1), false)
                    }
                    .onEnded { value in
                        guard isEnabled else { return }
                        isDragging = false
                        onScrub(min(max(value.location.x / width, 0), 1), true)
                    }
            )
            .animation(.spring(duration: 0.25, bounce: 0.3), value: isDragging)
        }
        .frame(height: 14)
        .accessibilityElement()
        .accessibilityLabel("Playback position")
        .accessibilityValue("\(Int(min(max(progress, 0), 1) * 100)) percent")
    }
}

private struct PlayerGlyphButton: View {
    let symbol: String
    let size: CGFloat
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: size * 1.8, height: size * 1.6)
                .contentTransition(.symbolEffect(.replace))
                .contentShape(Rectangle())
        }
        .buttonStyle(PlayerPressStyle())
        .accessibilityLabel(Text(label))
    }
}

private struct PlayerPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1)
            .opacity(configuration.isPressed ? 0.7 : 1)
            .animation(.spring(duration: 0.2, bounce: 0.4), value: configuration.isPressed)
    }
}
