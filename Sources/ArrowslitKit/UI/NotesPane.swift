import SwiftUI

struct NotesPane: View {
    @Bindable var state: AppState
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            PaneHeader("Scratchpad") {
                HStack(spacing: 12) {
                    Text(state.notes.isSaved ? "Saved" : "Saving…")
                        .font(ArrowTheme.caption)
                        .foregroundStyle(state.notes.isSaved ? ArrowTheme.green : ArrowTheme.amber)
                    Button("Clear") { state.notes.clear() }
                        .buttonStyle(NookPressStyle())
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(ArrowTheme.muted)
                }
            }

            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(ArrowTheme.panel)

                if state.notes.isEmpty {
                    Text("Start typing.")
                        .font(.system(size: 13))
                        .foregroundStyle(ArrowTheme.faint)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .allowsHitTesting(false)
                }

                TextEditor(text: Binding(
                    get: { state.notes.text },
                    set: { state.notes.setText($0) }
                ))
                .font(.system(size: 13))
                .foregroundStyle(ArrowTheme.bone)
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .padding(7)
                .focused($isFocused)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(ArrowTheme.hairline, lineWidth: 0.5)
            }
        }
        .onAppear { isFocused = true }
        .onDisappear { state.notes.save() }
    }
}
