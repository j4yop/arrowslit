import SwiftUI

struct VorssaintControlsPane: View {
    @Bindable var state: AppState
    @AppStorage("arrowslit.companion.enabled") private var companion = true

    private var track: NowPlayingTrack? {
        guard state.nowPlaying.isVisible, let track = state.nowPlaying.activeTrack, track.hasContent else { return nil }
        return track
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            PaneHeader("Controls") {
                VorssaintCompanion(enabled: $companion)
                    .scaleEffect(0.78, anchor: .topTrailing)
                    .frame(width: 58, height: 44)
            }

            HStack(alignment: .top, spacing: 10) {
                musicCard
                    .frame(width: 214)

                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3),
                    spacing: 8
                ) {
                    VorssaintActionTile(
                        symbol: state.microphone.isMuted ? "mic.slash.fill" : "mic.fill",
                        title: state.microphone.isMuted ? "Mic muted" : "Microphone",
                        detail: state.microphone.canMute ? (state.microphone.isMuted ? "Click to unmute" : "Click to mute") : "Unavailable",
                        tint: state.microphone.isMuted ? ArrowTheme.red : ArrowTheme.green,
                        active: state.microphone.isMuted
                    ) {
                        state.microphone.toggle()
                        NookHaptics.perform(enabled: state.settings.hapticFeedback)
                    }

                    VorssaintActionTile(
                        symbol: "speaker.wave.2.fill",
                        title: "Volume",
                        detail: "System audio",
                        tint: .white
                    ) {
                        state.openVorssaint(.mixer)
                    }

                    VorssaintActionTile(
                        symbol: state.keepAwake.isOn ? "cup.and.heat.waves.fill" : "cup.and.saucer",
                        title: "Keep awake",
                        detail: state.keepAwake.isOn ? "On" : "Off",
                        tint: ArrowTheme.yellow,
                        active: state.keepAwake.isOn
                    ) {
                        state.keepAwake.toggle()
                        NookHaptics.perform(enabled: state.settings.hapticFeedback)
                    }

                    VorssaintActionTile(
                        symbol: "gauge.with.dots.needle.33percent",
                        title: "Stats",
                        detail: state.stats.hasReading ? "CPU \(Int((state.stats.cpu * 100).rounded()))%" : "Live",
                        tint: ArrowTheme.green,
                        active: state.stats.isRunning
                    ) {
                        state.setStatsEnabled(!state.settings.statsEnabled)
                    }

                    VorssaintActionTile(
                        symbol: "timer",
                        title: "Timer",
                        detail: state.timer.isActive ? "Running" : "Ready",
                        tint: ArrowTheme.amber,
                        active: state.timer.isActive
                    ) {
                        state.openVorssaint(.timer)
                    }

                    VorssaintActionTile(
                        symbol: "doc.on.clipboard",
                        title: "Clipboard",
                        detail: state.clipboard.entries.count == 1 ? "1 clip" : "\(state.clipboard.entries.count) clips",
                        tint: .white
                    ) {
                        state.openVorssaint(.clipboard)
                    }
                }
            }
            .frame(maxHeight: .infinity)
        }
        .padding(.top, 2)
    }

    private var musicCard: some View {
        VorssaintCard(padding: 11) {
            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 9) {
                    artwork
                        .frame(width: 48, height: 48)
                        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(track?.title ?? "Nothing playing")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.94))
                            .lineLimit(1)
                        Text(track?.artist ?? "Start something in Music, Podcasts or a browser")
                            .font(.system(size: 9.5, weight: .medium))
                            .foregroundStyle(.white.opacity(0.45))
                            .lineLimit(1)
                    }
                }

                if let track {
                    ProgressView(value: track.progress(at: Date()) ?? 0)
                        .tint(state.nowPlaying.activeAccent.color)
                        .scaleEffect(y: 0.8)
                    HStack(spacing: 12) {
                        Button { state.nowPlaying.previous() } label: {
                            Image(systemName: "backward.fill")
                        }
                        Button { state.nowPlaying.toggle() } label: {
                            Image(systemName: track.isPlaying ? "pause.fill" : "play.fill")
                                .frame(width: 22, height: 22)
                                .background(Circle().fill(.white.opacity(0.12)))
                        }
                        Button { state.nowPlaying.next() } label: {
                            Image(systemName: "forward.fill")
                        }
                        Spacer()
                        Text(track.isPlaying ? "Playing" : "Paused")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(track.isPlaying ? ArrowTheme.green : .white.opacity(0.4))
                    }
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.8))
                    .buttonStyle(.plain)
                } else {
                    Spacer(minLength: 2)
                    HStack {
                        Spacer(minLength: 0)
                        Button("Open Now Playing") { state.openVorssaint(.music) }
                            .buttonStyle(.plain)
                            .font(.system(size: 9.5, weight: .semibold))
                            .foregroundStyle(ArrowTheme.amber)
                        Spacer(minLength: 0)
                    }
                }
            }
        }
    }

    private var artwork: some View {
        Group {
            if let image = state.nowPlaying.activeArtwork {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fill)
            } else {
                ZStack {
                    Color.white.opacity(0.08)
                    Image(systemName: "music.note")
                        .font(.system(size: 18, weight: .light))
                        .foregroundStyle(.white.opacity(0.55))
                }
            }
        }
    }
}
