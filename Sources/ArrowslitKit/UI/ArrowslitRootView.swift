import SwiftUI
import UniformTypeIdentifiers

struct ArrowslitRootView: View {
    @Bindable var state: AppState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let geometry = ScreenReader.current
        let presentation = state.presentation
        let size = NotchPanelMetrics.size(for: presentation, geometry: geometry)

        ZStack(alignment: .top) {
            switch presentation {
            case .alert(let alert):
                NotchAlertView(state: state, alert: alert)
                    .transition(.opacity.combined(with: .scale(scale: 0.99, anchor: .top)))
            case .expanded(.nowPlaying):
                NowPlayingPlayerView(state: state)
                    .transition(.opacity.combined(with: .scale(scale: 0.99, anchor: .top)))
            case .expanded:
                NookView(state: state)
                    .transition(.opacity.combined(with: .scale(scale: 0.99, anchor: .top)))
            case .compact:
                CompactBar(
                    state: state,
                    width: geometry.compactWidth,
                    notchWidth: geometry.notchWidth
                )
                .transition(.opacity)
            }
        }
        .frame(width: size.width, height: size.height, alignment: .top)
        .animation(NookMotion.reducing(NookMotion.open, reduceMotion: reduceMotion), value: presentation)
        .environment(\.colorScheme, .dark)
    }
}

/// The closed strip. Everything is laid out in the two ears beside the camera
/// housing, so nothing can disappear under the notch on any Mac.
private struct CompactBar: View {
    @Bindable var state: AppState
    let width: CGFloat
    let notchWidth: CGFloat
    @State private var isDropTargeted = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var ear: CGFloat { max(0, (width - notchWidth) / 2) }

    private var isLiveClock: Bool {
        if state.timer.isActive || state.timer.justFinished { return false }
        if state.nowPlaying.isVisible,
           let title = state.nowPlaying.track?.title,
           !title.isEmpty { return false }
        return true
    }

    private var musicTrack: NowPlayingTrack? {
        guard state.nowPlaying.isVisible, let track = state.nowPlaying.track, track.hasContent else { return nil }
        return track
    }

    var body: some View {
        HStack(spacing: 0) {
            if let track = musicTrack {
                compactArtwork
                    .padding(.leading, 10)
                    .frame(width: ear, alignment: .leading)

                Color.clear
                    .frame(width: notchWidth)

                MusicBars(
                    isPlaying: track.isPlaying,
                    color: state.nowPlaying.accent.color,
                    height: 15,
                    width: 20
                )
                .padding(.trailing, 10)
                .frame(width: ear, alignment: .trailing)
            } else {
                HStack(spacing: 7) {
                    SlitMark(height: 14)
                }
                .padding(.leading, 12)
                .frame(width: ear, alignment: .leading)

                Color.clear
                    .frame(width: notchWidth)

                HStack(spacing: 5) {
                    compactValue

                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(ArrowTheme.bone.opacity(0.6))
                        .frame(width: 10)
                        .accessibilityHidden(true)
                }
                .padding(.trailing, 8)
                .frame(width: ear, alignment: .trailing)
            }
        }
        .frame(width: width, height: 32)
        .background(ArrowTheme.ink)
        .clipShape(SlitShape(radius: 12))
        .overlay {
            SlitShape(radius: 12)
                .stroke(isDropTargeted ? Color(red: 0.20, green: 0.55, blue: 1) : ArrowTheme.hairline, lineWidth: isDropTargeted ? 1.5 : 0.5)
                .animation(NookMotion.reducing(NookMotion.hover, reduceMotion: reduceMotion), value: isDropTargeted)
        }
        .contentShape(SlitShape(radius: 12))
        .onTapGesture { state.expandDefault() }
        .onDrop(of: [.fileURL, .url], isTargeted: $isDropTargeted) { providers in
            Task { @MainActor in
                let urls = await FileDrop.urls(from: providers)
                if state.tray.add(urls) > 0 {
                    state.expand(.tray)
                }
            }
            return true
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(.isButton)
    }

    @ViewBuilder
    private var compactArtwork: some View {
        Group {
            if let artwork = state.nowPlaying.artwork {
                Image(nsImage: artwork)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fill)
            } else {
                SlitMark(height: 14)
            }
        }
        .frame(width: 26, height: 26)
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
    }

    @ViewBuilder
    private var compactValue: some View {
        if isLiveClock {
            TimelineView(.everyMinute) { context in
                timeText(ClockFormat.wallClockIST(context.date), color: ArrowTheme.bone)
            }
        } else {
            timeText(
                state.compactValue,
                color: state.timer.isActive ? ArrowTheme.amber : ArrowTheme.bone
            )
        }
    }

    private func timeText(_ value: String, color: Color) -> some View {
        Text(value)
            .font(.system(size: 13, weight: .semibold))
            .monospacedDigit()
            .foregroundStyle(color)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .truncationMode(.tail)
            .frame(width: max(24, ear - 27), alignment: .trailing)
    }

    private var accessibilityLabel: String {
        if let track = musicTrack {
            return "Arrowslit. Now playing \(track.title) by \(track.artist)"
        }
        return state.compactLabel == "Ready"
            ? "Arrowslit. \(state.compactValue)"
            : "Arrowslit. \(state.compactLabel) \(state.compactValue)"
    }
}
