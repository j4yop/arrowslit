import SwiftUI

/// A coding assistant asking to run a tool. The full request is visible; nothing is allowed
/// unless the user presses Allow.
struct AgentRequestView: View {
    @Bindable var state: AppState
    let request: AgentRequest
    @Environment(\.panelGeometry) private var geometry

    private var size: CGSize { state.panelSize(for: .alert(.agentRequest(request)), geometry: geometry) }

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "terminal.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(ArrowTheme.amber)
                Text(request.agent)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(ArrowTheme.bone)
                if !request.project.isEmpty {
                    Text(request.project)
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(ArrowTheme.muted)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Spacer(minLength: 4)
                Text(request.title)
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(ArrowTheme.muted)
                    .lineLimit(1)
            }

            ScrollView(.vertical, showsIndicators: true) {
                Text(verbatim: request.reviewDetail.isEmpty ? request.toolName : request.visibleReviewDetail)
                    .font(.system(size: 11.5, design: .monospaced))
                    .foregroundStyle(ArrowTheme.bone.opacity(0.9))
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
            }
            .id(request.id)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.white.opacity(0.07))
            )
            .accessibilityLabel("Full request. Scroll to review all details.")

            HStack(spacing: 8) {
                Button("Ask in \(request.agent)") { state.answerAgent(.ask) }
                    .buttonStyle(.plain)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(ArrowTheme.muted)
                    .accessibilityHint("Closes this and answers in the assistant's own window")
                Spacer(minLength: 0)
                button("Deny", tint: ArrowTheme.red) { state.answerAgent(.deny) }
                button("Allow", tint: ArrowTheme.green, prominent: true) { state.answerAgent(.allow) }
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .frame(width: size.width, height: size.height)
        .background(NotchSurfaceBackground(
            appearance: state.settings.appearance,
            radius: 16,
            flare: 6,
            notchBand: geometry.notch?.height ?? 0
        ))
        .clipShape(SlitShape(radius: 16, flare: 6))
        .overlay {
            SlitShape(radius: 16, flare: 6)
                .stroke(ArrowTheme.amber.opacity(0.25), lineWidth: 0.5)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(request.agent) wants to \(request.title.lowercased())")
    }

    private func button(_ title: String, tint: Color, prominent: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(prominent ? ArrowTheme.ink : ArrowTheme.bone)
                .padding(.horizontal, 12)
                .frame(height: 26)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(prominent ? tint : Color.white.opacity(0.08))
                )
                .overlay {
                    if !prominent {
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .stroke(tint.opacity(0.3), lineWidth: 0.5)
                    }
                }
        }
        .buttonStyle(NookPressStyle())
        .nookHitSlop()
    }
}
