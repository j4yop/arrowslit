import SwiftUI

struct NotesPane: View {
    @Bindable var state: AppState
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("SCRATCHPAD")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(1.4)
                        .foregroundStyle(ArrowTheme.faint)
                    Text("A local note, saved as you type.")
                        .font(.system(size: 11))
                        .foregroundStyle(ArrowTheme.muted)
                }
                Spacer()
                Text(state.notes.isSaved ? "SAVED" : "SAVING…")
                    .font(.system(size: 8, weight: .bold))
                    .tracking(1)
                    .foregroundStyle(state.notes.isSaved ? ArrowTheme.green : ArrowTheme.amber)
            }

            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(ArrowTheme.panel)

                if state.notes.isEmpty {
                    Text("Jot a thought, a number, a next step…")
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

            HStack {
                Text("Escape closes the workbench")
                    .font(.system(size: 9.5))
                    .foregroundStyle(ArrowTheme.faint)
                Spacer()
                Button("Clear") { state.notes.clear() }
                    .buttonStyle(NookPressStyle())
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(ArrowTheme.muted)
            }
        }
        .onAppear { isFocused = true }
        .onDisappear { state.notes.save() }
    }
}
