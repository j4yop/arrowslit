import AppKit
import SwiftUI

struct NotesPane: View {
    @Bindable var state: AppState
    @State private var controller = RichTextController()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            PaneHeader("Scratchpad", detail: "Saved as you type, with formatting kept across launches.") {
                HStack(spacing: 10) {
                    Text(state.notes.isSaved ? "Saved" : "Saving…")
                        .font(ArrowTheme.caption)
                        .foregroundStyle(state.notes.isSaved ? ArrowTheme.green : ArrowTheme.amber)
                    Button("Clear") { state.notes.clear() }
                        .buttonStyle(NookPressStyle())
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(ArrowTheme.muted)
                }
            }

            NoteCard(
                state: state,
                controller: controller,
                fontSize: 13,
                focusOnAppear: true
            )
        }
        .onDisappear { state.notes.save() }
    }
}

/// The note in a soft card, with a colour dot and A, B, I and U along the bottom.
struct NoteCard: View {
    @Bindable var state: AppState
    let controller: RichTextController
    let fontSize: CGFloat
    var focusOnAppear = false

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .topLeading) {
                if state.notes.text.isEmpty {
                    Text("Jot something down…")
                        .font(.system(size: fontSize))
                        .foregroundStyle(ArrowTheme.muted)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .allowsHitTesting(false)
                }
                RichTextEditor(
                    notes: state.notes,
                    controller: controller,
                    fontSize: fontSize,
                    focusOnAppear: focusOnAppear,
                    onFocus: { state.isTypingInNook = $0 },
                    onEscape: { state.collapse() }
                )
                .accessibilityLabel("Notes")
            }
            HStack(spacing: 2) {
                Button { controller.nextColor() } label: {
                    Circle()
                        .fill(controller.colorIndex == 0 ? Color.accentColor : controller.currentColor)
                        .frame(width: 11, height: 11)
                        .frame(width: 22, height: 22)
                        .contentShape(Rectangle())
                }
                .buttonStyle(NookPressStyle())
                .help("Text colour")
                .accessibilityLabel("Change text colour")
                Spacer(minLength: 0)
                FormatButton(label: "A", help: "Bigger text") { controller.toggleSize() }
                FormatButton(label: "B", weight: .heavy, help: "Bold") { controller.toggleBold() }
                FormatButton(label: "I", italic: true, help: "Italic") { controller.toggleItalic() }
                FormatButton(label: "U", underline: true, help: "Underline") { controller.toggleUnderline() }
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 3)
        }
        .padding(.top, 6)
        .padding(.horizontal, 4)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.08))
        )
    }
}

private struct FormatButton: View {
    let label: String
    var weight: Font.Weight = .semibold
    var italic = false
    var underline = false
    let help: String
    let action: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 11, weight: weight))
                .italic(italic)
                .underline(underline)
                .foregroundStyle(ArrowTheme.bone.opacity(0.75))
                .frame(width: 22, height: 22)
                .background(Circle().fill(Color.white.opacity(isHovering ? 0.14 : 0)))
                .contentShape(Circle())
        }
        .buttonStyle(NookPressStyle())
        .onHover { isHovering = $0 }
        .help(help)
        .accessibilityLabel(help)
    }
}
