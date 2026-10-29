import SwiftUI

/// Corbel-style feature launcher: large tiles, two rows, five across.
struct LauncherPane: View {
    @Bindable var state: AppState

    private var items: [WorkbenchTab] {
        [.nowPlaying, .timer, .stopwatch, .calendar, .keepAwake,
         .clipboard, .tray, .notes, .mirror, .reminders]
            .filter { state.settings.isTabEnabled($0) }
    }

    var body: some View {
        if items.isEmpty {
            VStack(spacing: 4) {
                Text("No features selected")
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(ArrowTheme.muted)
                Text("Choose features in Settings.")
                    .font(.system(size: 9.5))
                    .foregroundStyle(ArrowTheme.faint)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 5),
                spacing: 8
            ) {
                ForEach(items) { tab in
                    Button {
                        if state.isEditingShortcuts {
                            state.toggleShortcut(tab)
                        } else {
                            state.select(tab)
                        }
                    } label: {
                        VStack(spacing: 5) {
                            Image(systemName: tab.symbol)
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(tint(tab))
                            Text(tab.title)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(ArrowTheme.bone)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.white.opacity(0.055))
                        )
                        .overlay(alignment: .topTrailing) {
                            if state.isEditingShortcuts {
                                shortcutBadge(for: tab)
                                    .padding(6)
                            }
                        }
                        .overlay {
                            if state.isEditingShortcuts, state.settings.isShortcut(tab) {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .strokeBorder(Color(red: 0.20, green: 0.55, blue: 1).opacity(0.7), lineWidth: 1.5)
                            }
                        }
                        .opacity(state.isEditingShortcuts && !state.settings.isShortcut(tab) ? 0.45 : 1)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help(state.isEditingShortcuts ? "Toggle shortcut" : tab.title)
                }
            }
            .frame(maxHeight: .infinity, alignment: .top)
        }
    }

    @ViewBuilder
    private func shortcutBadge(for tab: WorkbenchTab) -> some View {
        let selected = state.settings.isShortcut(tab)
        let hasRoom = state.settings.shortcutTabs.count < SettingsStore.shortcutLimit
        Image(systemName: selected ? "checkmark" : "plus")
            .font(.system(size: 8, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 16, height: 16)
            .background(
                Circle().fill(
                    selected || hasRoom
                        ? Color(red: 0.04, green: 0.52, blue: 1)
                        : Color.white.opacity(0.14)
                )
            )
    }

    private func tint(_ tab: WorkbenchTab) -> Color {
        switch tab {
        case .nowPlaying: Color(red: 1, green: 0.27, blue: 0.4)
        case .timer: ArrowTheme.amber
        case .calendar: Color(red: 1, green: 0.27, blue: 0.23)
        case .mirror: Color(red: 0.75, green: 0.55, blue: 1)
        case .clipboard, .tray: Color(red: 0.35, green: 0.68, blue: 1)
        case .stats: ArrowTheme.green
        case .reminders: Color(red: 0.30, green: 0.60, blue: 1)
        case .notes: Color(red: 1, green: 0.84, blue: 0.35)
        case .stopwatch: Color(red: 1, green: 0.62, blue: 0.23)
        case .keepAwake: Color(red: 1, green: 0.84, blue: 0.30)
        case .home, .launcher: ArrowTheme.bone
        }
    }
}
