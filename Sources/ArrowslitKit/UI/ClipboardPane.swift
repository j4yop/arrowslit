import SwiftUI

struct ClipboardPane: View {
    @Bindable var state: AppState
    @State private var query = ""
    @FocusState private var searchFocused: Bool

    private var allEntries: [ClipboardEntry] { state.clipboard.entries }
    private var filtered: [ClipboardEntry] { state.clipboard.matching(query) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            PaneHeader("Clipboard", detail: "Pinned clips stay after quitting. Passwords are skipped.") {
                if !allEntries.isEmpty {
                    Button("Clear") { state.clipboard.clear() }
                        .buttonStyle(NookPressStyle())
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(ArrowTheme.muted)
                        .disabled(allEntries.allSatisfy(\.isPinned))
                }
            }

            if allEntries.isEmpty {
                empty
            } else {
                searchField
                if filtered.isEmpty {
                    noMatches
                } else {
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 6) {
                            ForEach(filtered) { entry in
                                ClipboardRow(
                                    entry: entry,
                                    copied: state.clipboard.lastCopiedID == entry.id,
                                    pin: { state.clipboard.togglePin(entry) }
                                ) {
                                    state.clipboard.copy(entry)
                                }
                            }
                        }
                    }
                    .nookScrollBounce()
                }
            }
        }
        .onAppear {
            state.isSearchingClipboard = true
            DispatchQueue.main.async { searchFocused = true }
        }
        .onDisappear { state.isSearchingClipboard = false }
    }

    private var searchField: some View {
        HStack(spacing: 7) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(searchFocused ? ArrowTheme.bone : ArrowTheme.muted)
            TextField("Search clips", text: $query)
                .textFieldStyle(.plain)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(ArrowTheme.bone)
                .focused($searchFocused)
                .onSubmit {
                    if let first = filtered.first { state.clipboard.copy(first) }
                }
            if !query.isEmpty {
                Text("\(filtered.count)")
                    .font(.system(size: 10.5, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(ArrowTheme.muted)
                    .accessibilityLabel("\(filtered.count) matches")
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(ArrowTheme.muted)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 28)
        .background(
            Capsule().fill(Color.white.opacity(searchFocused ? 0.11 : 0.06))
        )
        .overlay(
            Capsule().strokeBorder(Color.white.opacity(searchFocused ? 0.14 : 0), lineWidth: 1)
        )
    }

    private var noMatches: some View {
        VStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(ArrowTheme.faint)
            Text("No clips match “\(query)”")
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(ArrowTheme.muted)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var empty: some View {
        VStack(spacing: 8) {
            SlitMark(height: 24, color: ArrowTheme.faint)
            Text("Copy something and it will land here.")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(ArrowTheme.muted)
            Text("Pin a clip to keep it after you quit. Arrowslit never writes unpinned history to disk.")
                .font(.system(size: 10))
                .foregroundStyle(ArrowTheme.faint)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct ClipboardRow: View {
    let entry: ClipboardEntry
    let copied: Bool
    let pin: () -> Void
    let action: () -> Void
    @State private var isHovering = false

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Button(action: action) {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: copied ? "checkmark" : (entry.isPinned ? "pin.fill" : entry.kind.symbol))
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(copied ? ArrowTheme.green : (entry.isPinned ? ArrowTheme.amber : ArrowTheme.muted))
                        .frame(width: 14)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(entry.previewText)
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
                        Text("Copied")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(ArrowTheme.green)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Copy again")

            Button(action: pin) {
                Image(systemName: entry.isPinned ? "pin.fill" : "pin")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(entry.isPinned ? ArrowTheme.amber : ArrowTheme.muted)
                    .frame(width: 24, height: 24)
                    .background(Circle().fill(Color.white.opacity(isHovering ? 0.09 : 0.04)))
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .help(entry.isPinned ? "Unpin clip" : "Pin clip")
            .accessibilityLabel(entry.isPinned ? "Unpin clip" : "Pin clip")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white.opacity(entry.isPinned ? 0.065 : (isHovering ? 0.075 : 0.04)))
        )
        .overlay {
            if entry.isPinned {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(ArrowTheme.amber.opacity(0.2), lineWidth: 0.5)
            }
        }
        .onHover { isHovering = $0 }
    }
}
