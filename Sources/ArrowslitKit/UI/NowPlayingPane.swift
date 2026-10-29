import SwiftUI

struct NowPlayingPane: View {
    @Bindable var state: AppState
    private var service: NowPlayingService { state.nowPlaying }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("NOW PLAYING")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(1.4)
                        .foregroundStyle(ArrowTheme.faint)
                    Text("Whatever is playing on this Mac.")
                        .font(.system(size: 11))
                        .foregroundStyle(ArrowTheme.muted)
                }
                Spacer()
                if service.isVisible {
                    Circle().fill(ArrowTheme.green).frame(width: 5, height: 5)
                    Text("LIVE")
                        .font(.system(size: 8, weight: .bold))
                        .tracking(1)
                        .foregroundStyle(ArrowTheme.green)
                }
            }

            if let track = service.track, track.hasContent {
                player(track)
            } else if !service.isAvailable {
                empty(
                    symbol: "waveform.slash",
                    title: "Media bridge unavailable",
                    detail: "System media access is blocked on this Mac. Everything else still works."
                )
            } else {
                empty(
                    symbol: "music.note",
                    title: "Play something",
                    detail: "Music, a podcast, a video — Arrowslit will show it here."
                )
            }
        }
    }

    private func player(_ track: NowPlayingTrack) -> some View {
        HStack(alignment: .top, spacing: 18) {
            artwork
                .frame(width: 150, height: 150)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            VStack(alignment: .leading, spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(track.title)
                        .font(.system(size: 21, weight: .semibold))
                        .foregroundStyle(ArrowTheme.bone)
                        .lineLimit(1)
                    Text(track.artist.isEmpty ? "Unknown artist" : track.artist)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(ArrowTheme.muted)
                        .lineLimit(1)
                    if !track.album.isEmpty {
                        Text(track.album)
                            .font(.system(size: 10))
                            .foregroundStyle(ArrowTheme.faint)
                            .lineLimit(1)
                    }
                }

                TimelineView(.animation(minimumInterval: 0.5, paused: !track.isPlaying)) { context in
                    let elapsed = track.elapsed(at: context.date) ?? 0
                    VStack(spacing: 4) {
                        ProgressBar(progress: track.progress(at: context.date) ?? 0)
                        HStack {
                            Text(ClockFormat.clock(elapsed))
                            Spacer()
                            Text(track.duration.map { "-" + ClockFormat.clock(max(0, $0 - elapsed), roundingUp: true) } ?? "--:--")
                        }
                        .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                        .foregroundStyle(ArrowTheme.faint)
                    }
                }

                HStack(spacing: 18) {
                    MediaButton(symbol: "backward.fill", size: 15) { service.previous() }
                    MediaButton(symbol: track.isPlaying ? "pause.fill" : "play.fill", size: 22, filled: true) {
                        service.toggle()
                    }
                    MediaButton(symbol: "forward.fill", size: 15) { service.next() }
                    Spacer()
                    Text(track.isPlaying ? "PLAYING" : "PAUSED")
                        .font(.system(size: 8, weight: .bold))
                        .tracking(1.1)
                        .foregroundStyle(track.isPlaying ? ArrowTheme.green : ArrowTheme.faint)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var artwork: some View {
        Group {
            if let image = service.artwork {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fill)
            } else {
                ZStack {
                    ArrowTheme.panel
                    SlitMark(height: 34, color: ArrowTheme.amber.opacity(0.8))
                }
            }
        }
        .frame(width: 150, height: 150)
    }

    private func empty(symbol: String, title: String, detail: String) -> some View {
        VStack(spacing: 9) {
            Image(systemName: symbol)
                .font(.system(size: 26, weight: .regular))
                .foregroundStyle(ArrowTheme.faint)
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(ArrowTheme.muted)
            Text(detail)
                .font(.system(size: 10.5))
                .foregroundStyle(ArrowTheme.faint)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct ProgressBar: View {
    let progress: Double

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.08))
                Capsule()
                    .fill(ArrowTheme.amber)
                    .frame(width: max(3, geometry.size.width * CGFloat(progress)))
            }
        }
        .frame(height: 4)
    }
}

private struct MediaButton: View {
    let symbol: String
    let size: CGFloat
    var filled = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size * 0.6, weight: .semibold))
                .foregroundStyle(filled ? ArrowTheme.ink : ArrowTheme.bone.opacity(0.85))
                .frame(width: size * 1.8, height: size * 1.8)
                .background(
                    Circle().fill(filled ? ArrowTheme.amber : Color.white.opacity(0.07))
                )
                .contentShape(Circle())
        }
        .buttonStyle(NookPressStyle())
    }
}
