import SwiftUI

/// Notch Shell-style feature launcher: five columns, two rows per page, a paged vertical
/// scroll view and page dots on the right. Tiles keep their own icons, live dots and hold-to-
/// edit shortcut selection.
struct LauncherPane: View {
    @Bindable var state: AppState
    @State private var hoveredTab: WorkbenchTab?
    @State private var page: Int? = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.panelScale) private var scale

    private static let columns = 5
    private static let rowsPerPage = 2
    private var tileHeight: CGFloat { 76 * scale }
    private var tileGap: CGFloat { 10 * scale }

    private var items: [WorkbenchTab] {
        [.nowPlaying, .timer, .stopwatch, .calendar, .sports, .reminders,
         .clipboard, .tray, .notes, .mirror, .keepAwake, .stats]
            .filter { state.settings.isTabEnabled($0) }
    }

    private var pages: [[WorkbenchTab]] {
        LauncherPaging.pages(items, columns: Self.columns, rows: Self.rowsPerPage)
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
            GeometryReader { geometry in
                HStack(spacing: 10) {
                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVStack(spacing: 0) {
                            ForEach(pages.indices, id: \.self) { index in
                                LazyVGrid(
                                    columns: Array(
                                        repeating: GridItem(.flexible(), spacing: tileGap),
                                        count: Self.columns
                                    ),
                                    spacing: tileGap
                                ) {
                                    ForEach(pages[index]) { tab in
                                        tile(tab)
                                    }
                                }
                                .frame(height: geometry.size.height, alignment: .top)
                                .id(index)
                            }
                        }
                        .scrollTargetLayout()
                    }
                    .scrollTargetBehavior(.paging)
                    .scrollPosition(id: $page)

                    if pages.count > 1 {
                        pageDots
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .onChange(of: pages.count) { _, count in
                if let current = page, current >= count {
                    page = max(0, count - 1)
                } else if page == nil {
                    page = 0
                }
            }
        }
    }

    private func tile(_ tab: WorkbenchTab) -> some View {
        let selected = state.settings.isShortcut(tab)
        let atCapacity = state.settings.shortcutTabs.count >= SettingsStore.shortcutLimit
        let live = isLive(tab)
        let editing = state.isEditingShortcuts

        return VStack(spacing: 0) {
            Image(systemName: symbol(tab, live: live))
                .font(.system(size: 19 * scale, weight: .regular))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(tint(tab))
                .frame(height: 24 * scale)
            Text(tab.title)
                .font(.system(size: 11.5 * scale, weight: .medium))
                .foregroundStyle(.white.opacity(0.92))
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .padding(.top, 7 * scale)
            if state.settings.keyboardShortcutsEnabled, let label = tab.shortcutLabel {
                Text(label)
                    .font(.system(size: 9.5 * scale, weight: .regular))
                    .kerning(0.5 * scale)
                    .foregroundStyle(Color.white.opacity(0.38))
                    .padding(.top, 2 * scale)
            }
        }
        .padding(.horizontal, 6 * scale)
        .frame(maxWidth: .infinity)
        .frame(height: tileHeight)
        .background(
            RoundedRectangle(cornerRadius: 16 * scale, style: .continuous)
                .fill(Color.white.opacity(hoveredTab == tab ? 0.1 : 0.055))
        )
        .overlay(alignment: .topTrailing) {
            if editing {
                if selected || !atCapacity {
                    Image(systemName: selected ? "checkmark.circle.fill" : "plus.circle.fill")
                        .font(.system(size: 15 * scale, weight: .semibold))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, ArrowTheme.blue)
                        .padding(6 * scale)
                }
            } else if live {
                Circle()
                    .fill(tint(tab))
                    .frame(width: 6 * scale, height: 6 * scale)
                    .padding(9 * scale)
                    .accessibilityHidden(true)
            }
        }
        .opacity(editing && atCapacity && !selected ? 0.5 : 1)
        .contentShape(RoundedRectangle(cornerRadius: 16 * scale, style: .continuous))
        .animation(.easeOut(duration: 0.15), value: hoveredTab)
        .modifier(ClickNotHold(onHold: startEditing) {
            activate(tab)
        })
        .onHover { hovering in
            hoveredTab = hovering ? tab : nil
        }
        .help(editing
              ? (selected ? "Remove \(tab.title) from the shortcuts" : (atCapacity ? "Remove a shortcut before adding another" : "Add \(tab.title) beside Home"))
              : "\(tab.title). Hold to pick your shortcuts.")
        .accessibilityLabel(tab.title)
        .accessibilityValue(editing ? (selected ? "In shortcuts" : "") : (live ? "On" : ""))
    }

    private var pageDots: some View {
        VStack(spacing: 8 * scale) {
            ForEach(pages.indices, id: \.self) { index in
                Button {
                    withAnimation(.smooth(duration: 0.35)) { page = index }
                } label: {
                    Circle()
                        .fill(Color.white.opacity(page == index ? 0.9 : 0.3))
                        .frame(width: 6 * scale, height: 6 * scale)
                        .frame(width: 14 * scale, height: 14 * scale)
                        .contentShape(Rectangle())
                }
                .buttonStyle(NookPressStyle())
                .accessibilityLabel("Page \(index + 1) of \(pages.count)")
            }
        }
        .frame(maxHeight: .infinity)
        .animation(.smooth(duration: 0.25), value: page)
    }

    private func startEditing() {
        guard !state.isEditingShortcuts else { return }
        state.isEditingShortcuts = true
        NookHaptics.perform(enabled: state.settings.hapticFeedback)
    }

    private func activate(_ tab: WorkbenchTab) {
        guard state.isEditingShortcuts else {
            state.select(tab)
            return
        }
        if state.toggleShortcut(tab) {
            NookHaptics.perform(enabled: state.settings.hapticFeedback)
        }
    }

    private func symbol(_ tab: WorkbenchTab, live: Bool) -> String {
        tab == .keepAwake && live ? "cup.and.heat.waves.fill" : tab.symbol
    }

    private func isLive(_ tab: WorkbenchTab) -> Bool {
        switch tab {
        case .nowPlaying: state.nowPlaying.isVisible
        case .timer: state.timer.isActive
        case .stopwatch: state.stopwatch.isActive
        case .sports: state.sports.notchMatch != nil
        case .keepAwake: state.keepAwake.isOn
        case .stats: state.stats.isRunning
        default: false
        }
    }

    /// Notch Shell's launcher palette: colour marks the feature category, while the
    /// utility surfaces (Clipboard, Files, Scratchpad, Camera) stay white.
    private func tint(_ tab: WorkbenchTab) -> Color {
        switch tab {
        case .nowPlaying: Color(red: 1, green: 0.27, blue: 0.4)
        case .timer, .stopwatch: ArrowTheme.amber
        case .calendar: ArrowTheme.red
        case .reminders: ArrowTheme.blue
        case .keepAwake: ArrowTheme.yellow
        case .stats: ArrowTheme.green
        case .sports: ArrowTheme.green
        default: .white
        }
    }
}
