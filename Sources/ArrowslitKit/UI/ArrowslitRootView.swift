import SwiftUI

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

    private var ear: CGFloat { max(0, (width - notchWidth) / 2) }
    private var showsWordmark: Bool { ear >= 100 }

    var body: some View {
        HStack(spacing: 0) {
            HStack(spacing: 7) {
                SlitMark(height: 13)
                if showsWordmark {
                    Text("ARROWSLIT")
                        .font(.system(size: 8, weight: .semibold))
                        .tracking(1.8)
                        .foregroundStyle(ArrowTheme.bone.opacity(0.88))
                        .lineLimit(1)
                        .fixedSize()
                }
            }
            .padding(.leading, 12)
            .frame(width: ear, alignment: .leading)
            .clipped()

            Color.clear
                .frame(width: notchWidth)

            HStack(spacing: 4) {
                VStack(alignment: .trailing, spacing: 0) {
                    Text(state.compactValue)
                        .font(.system(size: 11, weight: .semibold, design: state.timer.isActive ? .monospaced : .default))
                        .monospacedDigit()
                        .foregroundStyle(state.timer.isActive ? ArrowTheme.amber : ArrowTheme.bone)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .truncationMode(.tail)
                    Text(state.compactLabel)
                        .font(.system(size: 7, weight: .bold))
                        .tracking(0.9)
                        .foregroundStyle(ArrowTheme.faint)
                        .lineLimit(1)
                }
                .frame(width: max(24, ear - 26), alignment: .trailing)

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
                .stroke(ArrowTheme.hairline, lineWidth: 0.5)
        }
        .contentShape(SlitShape(radius: 12))
        .onTapGesture { state.expand(.home) }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Arrowslit. \(state.compactLabel) \(state.compactValue)")
        .accessibilityAddTraits(.isButton)
    }
}
