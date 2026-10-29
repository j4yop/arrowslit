import SwiftUI

struct ArrowslitRootView: View {
    @Bindable var state: AppState

    var body: some View {
        ZStack(alignment: .top) {
            if state.isExpanded {
                WorkbenchView(state: state)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            } else {
                CompactBar(state: state)
                    .transition(.opacity)
            }
        }
        .frame(
            width: state.isExpanded ? 720 : 360,
            height: state.isExpanded ? 420 : 36,
            alignment: .top
        )
        .animation(.spring(response: 0.34, dampingFraction: 0.86), value: state.isExpanded)
        .environment(\.colorScheme, .dark)
    }
}

private struct CompactBar: View {
    @Bindable var state: AppState

    var body: some View {
        HStack(spacing: 10) {
            SlitMark(height: 15)
            Text("ARROWSLIT")
                .font(.system(size: 9.5, weight: .semibold))
                .tracking(2.2)
                .foregroundStyle(ArrowTheme.bone.opacity(0.88))

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 0) {
                Text(state.compactValue)
                    .font(.system(size: 12, weight: .semibold, design: state.timer.isActive ? .monospaced : .default))
                    .foregroundStyle(state.timer.isActive ? ArrowTheme.amber : ArrowTheme.bone)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: 190, alignment: .trailing)
                Text(state.compactLabel)
                    .font(.system(size: 7.5, weight: .bold))
                    .tracking(1.1)
                    .foregroundStyle(ArrowTheme.faint)
            }

            Image(systemName: "chevron.down")
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(ArrowTheme.faint)
        }
        .padding(.horizontal, 14)
        .frame(width: 360, height: 36)
        .background(ArrowTheme.ink)
        .clipShape(SlitShape(radius: 12))
        .overlay {
            SlitShape(radius: 12)
                .stroke(ArrowTheme.hairline, lineWidth: 0.5)
        }
        .contentShape(SlitShape(radius: 12))
        .onTapGesture { state.expand(.timer) }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Arrowslit. \(state.compactLabel) \(state.compactValue)")
        .accessibilityAddTraits(.isButton)
    }
}
