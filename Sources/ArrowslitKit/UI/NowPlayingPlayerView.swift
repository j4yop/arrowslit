import AppKit
import SwiftUI

/// The Apple Music-style now-playing nudge: a wide, short black card with large artwork,
/// transport controls and a scrubber. It floats just below the camera housing.
struct NowPlayingPlayerView: View {
    @Bindable var state: AppState

    private var service: NowPlayingService { state.nowPlaying }
    private var track: NowPlayingTrack? { service.track }
    private var lyrics: SyncedLyrics? { state.lyrics.current }

    private var height: CGFloat {
        lyrics == nil ? NotchPanelMetrics.playerSize.height : NotchPanelMetrics.playerLyricsSize.height
    }

    var body: some View {
        VStack(spacing: 0) {
            if let track, track.hasContent {
                player(track)
            } else {
                empty
            }
        }
        .padding(15)
        .frame(width: NotchPanelMetrics.playerSize.width, height: height, alignment: .top)
        .background(ArrowTheme.ink)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 0.5)
        }
        .shadow(color: .black.opacity(0.35), radius: 18, y: 8)
        .onAppear { updateLyrics() }
        .onChange(of: service.track) { _, _ in updateLyrics() }
        .onChange(of: state.settings.lyricsEnabled) { _, _ in updateLyrics() }
        .accessibilityElement(children: .contain)
    }

    private func player(_ track: NowPlayingTrack) -> some View {
        HStack(alignment: .top, spacing: 14) {
            artwork
                .frame(width: 110, height: 110)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

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

                    MusicBars(
                        isPlaying: track.isPlaying,
                        color: service.accent.color,
                        height: 16,
                        width: 18
                    )
                }

                if let lyrics {
                    lyricLine(track, lyrics: lyrics)
                        .padding(.top, 2)
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
        .frame(height: lyrics == nil ? 110 : 136, alignment: .top)
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
                    SlitMark(height: 28, color: ArrowTheme.amber.opacity(0.8))
                }
            }
        }
    }

    private func lyricLine(_ track: NowPlayingTrack, lyrics: SyncedLyrics) -> some View {
        TimelineView(.animation(minimumInterval: 0.2, paused: !track.isPlaying)) { context in
            let index = track.elapsed(at: context.date).flatMap { lyrics.index(at: $0 + 0.3) }
            let text = index.flatMap { lyrics.lines[$0].text } ?? ""
            ZStack {
                Text(text.isEmpty ? "♪" : text)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(text.isEmpty ? ArrowTheme.muted : ArrowTheme.bone)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .id(index ?? -1)
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .move(edge: .top).combined(with: .opacity)
                    ))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .clipped()
            .animation(.smooth(duration: 0.35), value: index)
        }
        .frame(height: 20)
        .accessibilityElement()
        .accessibilityLabel("Lyrics")
    }

    private var empty: some View {
        VStack(spacing: 8) {
            Image(systemName: "music.note")
                .font(.system(size: 22, weight: .regular))
                .foregroundStyle(ArrowTheme.faint)
            Text(service.isAvailable ? "Nothing is playing" : "Media access is unavailable")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(ArrowTheme.muted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func updateLyrics() {
        state.lyrics.update(for: service.track, enabled: state.settings.lyricsEnabled)
    }
}

struct PlayerProgressRow: View {
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
            VStack(spacing: 3) {
                PlayerScrubBar(progress: progress, isEnabled: duration != nil) { value, ended in
                    scrubProgress = ended ? nil : value
                    if ended, let duration {
                        service.seek(to: value * duration)
                    }
                }
                HStack {
                    Text(ClockFormat.clock(shownElapsed))
                    Spacer()
                    Text(duration.map { "-" + ClockFormat.clock(max(0, $0 - shownElapsed), roundingUp: true) } ?? "--:--")
                }
                .font(.system(size: 10, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(ArrowTheme.muted)
            }
        }
    }
}

struct PlayerScrubBar: View {
    var progress: Double
    var isEnabled: Bool
    var onScrub: (Double, Bool) -> Void
    @State private var isDragging = false

    var body: some View {
        GeometryReader { geometry in
            let width = max(geometry.size.width, 1)
            let clamped = min(max(progress, 0), 1)
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.18))
                Capsule()
                    .fill(Color(red: 0.04, green: 0.52, blue: 1))
                    .frame(width: width * clamped)
            }
            .frame(height: isDragging ? 6 : 4)
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
        .frame(height: 8)
        .accessibilityElement()
        .accessibilityLabel("Playback position")
        .accessibilityValue("\(Int(min(max(progress, 0), 1) * 100)) percent")
    }
}

struct PlayerGlyphButton: View {
    let symbol: String
    let size: CGFloat
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size, weight: .semibold))
                .foregroundStyle(.white.opacity(0.9))
                .frame(width: size * 1.8, height: size * 1.4)
                .contentTransition(.symbolEffect(.replace))
                .contentShape(Rectangle())
        }
        .buttonStyle(PlayerPressStyle())
        .accessibilityLabel(Text(label))
    }
}

struct PlayerPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1)
            .opacity(configuration.isPressed ? 0.7 : 1)
            .animation(.spring(duration: 0.2, bounce: 0.4), value: configuration.isPressed)
    }
}
