import SwiftUI

struct ClipboardPane: View {
    @Bindable var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("CLIPBOARD")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(1.4)
                        .foregroundStyle(ArrowTheme.faint)
                    Text("Last \(ClipboardRules.capacity) text copies. Private items are skipped.")
                        .font(.system(size: 11))
                        .foregroundStyle(ArrowTheme.muted)
                }
                Spacer()
                if !state.clipboard.entries.isEmpty {
                    Button("Clear") { state.clipboard.clear() }
                        .buttonStyle(.plain)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(ArrowTheme.muted)
                }
            }

            if state.clipboard.entries.isEmpty {
                empty
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 6) {
                        ForEach(state.clipboard.entries) { entry in
                            ClipboardRow(
                                entry: entry,
                                copied: state.clipboard.lastCopiedID == entry.id
                            ) {
                                state.clipboard.copy(entry)
                            }
                        }
                    }
                }
            }
        }
    }

    private var empty: some View {
        VStack(spacing: 8) {
            SlitMark(height: 24, color: ArrowTheme.faint)
            Text("Copy something and it will land here.")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(ArrowTheme.muted)
            Text("Arrowslit never writes clipboard history to disk.")
                .font(.system(size: 10))
                .foregroundStyle(ArrowTheme.faint)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct ClipboardRow: View {
    let entry: ClipboardEntry
    let copied: Bool
    let action: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: copied ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(copied ? ArrowTheme.green : ArrowTheme.amber)
                    .frame(width: 14)

                VStack(alignment: .leading, spacing: 4) {
                    Text(ClipboardRules.preview(entry.text))
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(ArrowTheme.bone)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    HStack(spacing: 6) {
                        if let appName = entry.appName {
                            Text(appName).lineLimit(1)
                            Text("·")
                        }
                        Text(ClockFormat.age(entry.copiedAt))
                    }
                    .font(.system(size: 9.5))
                    .foregroundStyle(ArrowTheme.faint)
                }

                Spacer(minLength: 6)
                if copied {
                    Text("COPIED")
                        .font(.system(size: 8, weight: .bold))
                        .tracking(1)
                        .foregroundStyle(ArrowTheme.green)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.white.opacity(isHovering ? 0.075 : 0.04))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .help("Copy again")
    }
}
