import SwiftUI
import UniformTypeIdentifiers

struct ArrowslitRootView: View {
    @Bindable var state: AppState

    var body: some View {
        let geometry = ScreenReader.current

        ZStack(alignment: .top) {
            if state.isExpanded {
                NookView(state: state)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            } else {
                CompactBar(
                    state: state,
                    width: geometry.compactWidth,
                    notchWidth: geometry.housing.width
                )
                .transition(.opacity)
            }
        }
        .frame(
            width: state.isExpanded ? 560 : geometry.compactWidth,
            height: state.isExpanded ? 178 : 32,
            alignment: .top
        )
        .animation(.spring(response: 0.34, dampingFraction: 0.86), value: state.isExpanded)
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

    private var ear: CGFloat { max(0, (width - notchWidth) / 2) }

    private var isLiveClock: Bool {
        if state.timer.isActive || state.timer.justFinished { return false }
        if state.nowPlaying.isVisible,
           let title = state.nowPlaying.track?.title,
           !title.isEmpty { return false }
        return true
    }

    var body: some View {
        HStack(spacing: 0) {
            SlitMark(height: 14)
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
        .frame(width: width, height: 32)
        .background(ArrowTheme.ink)
        .clipShape(SlitShape(radius: 12))
        .overlay {
            SlitShape(radius: 12)
                .stroke(isDropTargeted ? Color(red: 0.20, green: 0.55, blue: 1) : ArrowTheme.hairline, lineWidth: isDropTargeted ? 1.5 : 0.5)
        }
        .contentShape(SlitShape(radius: 12))
        .onTapGesture { state.expand(.home) }
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
            .font(.system(size: 13, weight: .semibold, design: state.timer.isActive ? .monospaced : .default))
            .monospacedDigit()
            .foregroundStyle(color)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .truncationMode(.tail)
            .frame(width: max(24, ear - 27), alignment: .trailing)
    }

    private var accessibilityLabel: String {
        state.compactLabel == "READY"
            ? "Arrowslit. \(state.compactValue)"
            : "Arrowslit. \(state.compactLabel) \(state.compactValue)"
    }
}
