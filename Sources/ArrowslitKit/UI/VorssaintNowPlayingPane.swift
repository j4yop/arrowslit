import AppKit
import SwiftUI

/// Vorssaint's player: a large cover, the song and source, a white timeline,
/// a centred transport, and the volume, output, lyrics and queue row.
struct VorssaintNowPlayingPane: View {
    @Bindable var state: AppState
    @StateObject private var mixer = AppVolumeMixer.shared
    @State private var showingLyrics = false
    @State private var showingQueue = false

    private var service: NowPlayingService { state.nowPlaying }

    var body: some View {
        Group {
            if let track = service.activeTrack, track.hasContent {
                player(track)
            } else if !service.isAvailable {
                VorssaintPageEmpty(symbol: "waveform.slash", title: "Media access is unavailable",
                                   detail: "System media access is blocked on this Mac. Everything else still works.")
            } else {
                VorssaintPageEmpty(symbol: "music.note", title: "Nothing is playing",
                                   detail: "Start something in Music, Podcasts or a browser.")
            }
        }
        .padding(.top, 2)
    }

    private func player(_ track: NowPlayingTrack) -> some View {
        HStack(alignment: .center, spacing: 16) {
            artwork
                .frame(width: 120, height: 120)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: .black.opacity(0.35), radius: 18, y: 8)

            VStack(alignment: .leading, spacing: 0) {
                header(track)
                TimelineView(.animation(minimumInterval: 0.5, paused: !track.isPlaying)) { context in
                    timeline(track, at: context.date)
                }
                transport(track)
                bottomRow(track)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(height: 160, alignment: .center)
        .overlay {
            if showingLyrics || showingQueue {
                detailOverlay(track)
            }
        }
    }

    private func header(_ track: NowPlayingTrack) -> some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                Text(track.title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.97))
                    .lineLimit(1)
                Text(track.artist.isEmpty ? (track.album.isEmpty ? "Unknown artist" : track.album) : track.artist)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(.white.opacity(0.5))
                    .lineLimit(1)
            }
            Spacer(minLength: 6)
            Menu {
                if !service.otherSources.isEmpty {
                    ForEach(service.otherSources) { source in
                        Button(source.name) { service.selectSource(source.id) }
                    }
                    Divider()
                }
                Button("Music") {
                    NSWorkspace.shared.open(URL(string: "music://")!)
                }
            } label: {
                HStack(spacing: 3) {
                    Text(sourceName(track))
                        .font(.system(size: 10.5, weight: .medium))
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 7, weight: .bold))
                }
                .foregroundStyle(.white.opacity(0.45))
            }
            .menuStyle(.borderlessButton)
            .fixedSize()

            VorssaintEqualizer(isPlaying: track.isPlaying)
                .frame(width: 20, height: 15)
        }
    }

    private func timeline(_ track: NowPlayingTrack, at date: Date) -> some View {
        let elapsed = track.elapsed(at: date) ?? 0
        let progress = track.progress(at: date) ?? 0
        return VStack(spacing: 3) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.22))
                    Capsule()
                        .fill(Color.white.opacity(0.95))
                        .frame(width: max(3, geometry.size.width * CGFloat(progress)))
                }
            }
            .frame(height: 3)
            HStack {
                Text(ClockFormat.clock(elapsed))
                Spacer()
                Text(track.duration.map { "-" + ClockFormat.clock(max(0, $0 - elapsed), roundingUp: true) } ?? "--:--")
            }
            .font(.system(size: 9, weight: .medium))
            .monospacedDigit()
            .foregroundStyle(.white.opacity(0.4))
        }
        .padding(.top, 9)
    }

    private func transport(_ track: NowPlayingTrack) -> some View {
        HStack(spacing: 0) {
            Spacer(minLength: 0)
            Button { service.previous() } label: {
                Image(systemName: "backward.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.88))
                    .frame(width: 40, height: 40)
            }
            .buttonStyle(NookPressStyle(pressedScale: 0.92))
            Button { service.toggle() } label: {
                Image(systemName: track.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.black.opacity(0.86))
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(.white.opacity(0.96)))
                    .contentShape(Circle())
            }
            .buttonStyle(NookPressStyle(pressedScale: 0.94))
            .padding(.horizontal, 28)
            Button { service.next() } label: {
                Image(systemName: "forward.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.88))
                    .frame(width: 40, height: 40)
            }
            .buttonStyle(NookPressStyle(pressedScale: 0.92))
            Spacer(minLength: 0)
        }
        .frame(height: 48)
    }

    private func bottomRow(_ track: NowPlayingTrack) -> some View {
        HStack(spacing: 10) {
            Button {
                if let muted = mixer.systemOutputMuted {
                    mixer.requestOutputAdjustment(muted: !muted)
                }
            } label: {
                Image(systemName: mixer.systemOutputMuted == true ? "speaker.slash.fill" : "speaker.wave.1.fill")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
                    .frame(width: 18, height: 18)
            }
            .buttonStyle(.plain)

            VorssaintMiniVolume(
                value: mixer.systemOutputVolume ?? 0.5,
                tint: .white
            ) { mixer.requestOutputAdjustment(volume: $0) }
            .frame(width: 78, height: 14)

            Button {
                _ = mixer.switchToNextSoundOutput(in: mixer.outputDevices.filter(\.canBeDefaultOutput).map(\.uid))
            } label: {
                HStack(spacing: 2) {
                    Image(systemName: "airplayaudio")
                        .font(.system(size: 12, weight: .medium))
                    Image(systemName: "chevron.down")
                        .font(.system(size: 7, weight: .bold))
                }
                .foregroundStyle(.white.opacity(0.55))
                .frame(height: 18)
            }
            .buttonStyle(.plain)
            .help("Output")

            Spacer(minLength: 4)

            pill("Lyrics", symbol: "quote.bubble") {
                withAnimation(.smooth(duration: 0.22)) {
                    showingLyrics.toggle()
                    showingQueue = false
                }
            }
            pill("Up next", symbol: "list.bullet") {
                withAnimation(.smooth(duration: 0.22)) {
                    showingQueue.toggle()
                    showingLyrics = false
                }
            }
        }
        .frame(height: 24)
    }

    private func pill(_ title: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: symbol)
                    .font(.system(size: 9.5, weight: .semibold))
                Text(title)
                    .font(.system(size: 10.5, weight: .medium))
            }
            .foregroundStyle(.white.opacity(0.86))
            .padding(.horizontal, 10)
            .frame(height: 24)
            .background(Capsule().fill(Color.white.opacity(0.09)))
            .contentShape(Capsule())
        }
        .buttonStyle(NookPressStyle(pressedScale: 0.95))
    }

    private func detailOverlay(_ track: NowPlayingTrack) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text(showingLyrics ? "Lyrics" : "Up next")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                Spacer()
                Button {
                    withAnimation(.smooth(duration: 0.22)) {
                        showingLyrics = false
                        showingQueue = false
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white.opacity(0.6))
                        .frame(width: 22, height: 22)
                        .background(Circle().fill(.white.opacity(0.08)))
                }
                .buttonStyle(.plain)
            }
            ScrollView {
                Text(showingLyrics
                     ? (state.lyrics.current?.lines.map(\.text).joined(separator: "\n") ?? "Lyrics are not available for this track.")
                     : (service.otherSources.isEmpty ? "Nothing queued." : service.otherSources.map(\.name).joined(separator: "\n")))
                    .font(.system(size: 10.5))
                    .foregroundStyle(.white.opacity(0.62))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.black.opacity(0.82))
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        )
    }

    private var artwork: some View {
        Group {
            if let image = service.activeArtwork {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fill)
            } else {
                ZStack {
                    LinearGradient(colors: [VorssaintTheme.pink, VorssaintTheme.purple],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                    Image(systemName: "music.note")
                        .font(.system(size: 30, weight: .medium))
                        .foregroundStyle(.white.opacity(0.85))
                }
            }
        }
    }

    private func sourceName(_ track: NowPlayingTrack) -> String {
        guard let identifier = track.bundleIdentifier,
              let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: identifier) else { return "Music" }
        return Bundle(url: url)?.localizedInfoDictionary?["CFBundleDisplayName"] as? String
            ?? FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: "")
    }
}

/// Four small bars beside the source, at rest while paused.
struct VorssaintEqualizer: View {
    let isPlaying: Bool
    @State private var phase: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.18, paused: !isPlaying || reduceMotion)) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            HStack(alignment: .bottom, spacing: 2.4) {
                ForEach(0..<4, id: \.self) { index in
                    let level = isPlaying
                        ? 0.35 + 0.65 * abs(sin(time * (1.3 + Double(index) * 0.28) + Double(index)))
                        : 0.22
                    Capsule()
                        .fill(isPlaying ? VorssaintTheme.orange : .white.opacity(0.4))
                        .frame(width: 2.3, height: 12 * level)
                }
            }
            .frame(height: 15, alignment: .bottom)
        }
    }
}

/// The compact horizontal volume used under the player.
private struct VorssaintMiniVolume: View {
    let value: Double
    let tint: Color
    let onChange: (Double) -> Void

    var body: some View {
        GeometryReader { geometry in
            let width = max(1, geometry.size.width)
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.16))
                Capsule()
                    .fill(tint.opacity(0.9))
                    .frame(width: max(2, width * CGFloat(min(max(value, 0), 1))))
            }
            .frame(maxHeight: .infinity, alignment: .center)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        onChange(min(max(gesture.location.x / width, 0), 1))
                    }
            )
        }
        .frame(height: 3)
        .accessibilityElement()
        .accessibilityLabel("Volume")
        .accessibilityValue("\(Int((value * 100).rounded())) percent")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: onChange(min(1, value + 0.05))
            case .decrement: onChange(max(0, value - 0.05))
            @unknown default: break
            }
        }
    }
}
