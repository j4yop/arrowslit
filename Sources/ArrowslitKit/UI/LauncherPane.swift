import SwiftUI

/// DynamicLedge-style feature launcher: five columns, two rows per page, page dots on the
/// right, live/on dots on tiles, and hold-to-edit for the shortcuts beside Home.
struct LauncherPane: View {
    @Bindable var state: AppState
    @State private var hoveredTab: WorkbenchTab?
    @State private var page = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let columns = 5
    private static let rowsPerPage = 2
    private static let tileHeight: CGFloat = 76
    private static let tileGap: CGFloat = 10

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
            HStack(spacing: 6) {
                ZStack {
                    LazyVGrid(
                        columns: Array(
                            repeating: GridItem(.flexible(), spacing: Self.tileGap),
                            count: Self.columns
                        ),
                        spacing: Self.tileGap
                    ) {
                        ForEach(pages[safe: page] ?? []) { tab in
                            tile(tab)
                        }
                    }
                    .frame(height: Self.tileHeight * 2 + Self.tileGap, alignment: .top)
                    .id(page)
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .move(edge: .top).combined(with: .opacity)
                    ))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 24).onEnded { value in
                        if value.translation.height < -30 {
                            turn(to: min(page + 1, pages.count - 1))
                        } else if value.translation.height > 30 {
                            turn(to: max(page - 1, 0))
                        }
                    }
                )

                pageDots
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onChange(of: pages.count) { _, count in
                if page >= count {
                    page = max(0, count - 1)
                }
            }
        }
    }

    private func tile(_ tab: WorkbenchTab) -> some View {
        Button {
            if state.isEditingShortcuts {
                state.toggleShortcut(tab)
            } else {
                state.select(tab)
            }
        } label: {
            VStack(spacing: 6) {
                Image(systemName: tab.symbol)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(tint(tab))
                Text(tab.title)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(ArrowTheme.bone)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(hoveredTab == tab ? 0.10 : 0.06))
            )
            .overlay(alignment: .topTrailing) {
                if state.isEditingShortcuts {
                    shortcutBadge(for: tab)
                        .padding(7)
                } else if isLive(tab) {
                    Circle()
                        .fill(tint(tab))
                        .frame(width: 5, height: 5)
                        .padding(8)
                        .accessibilityHidden(true)
                }
            }
            .overlay {
                if state.isEditingShortcuts, state.settings.isShortcut(tab) {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color(red: 0.20, green: 0.55, blue: 1).opacity(0.75), lineWidth: 1.5)
                }
            }
            .opacity(state.isEditingShortcuts && !state.settings.isShortcut(tab) ? 0.45 : 1)
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(NookPressStyle())
        .onHover { hoveredTab = $0 ? tab : nil }
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.45).onEnded { _ in
                state.isEditingShortcuts = true
            }
        )
        .help(state.isEditingShortcuts ? "Toggle shortcut" : tab.title)
        .accessibilityLabel(tab.title)
        .accessibilityIdentifier("launcher.\(tab.rawValue)")
        .accessibilityAddTraits(state.settings.isShortcut(tab) ? .isSelected : [])
    }

    private var pageDots: some View {
        VStack(spacing: 6) {
            ForEach(pages.indices, id: \.self) { index in
                Circle()
                    .fill(index == page ? ArrowTheme.bone : ArrowTheme.bone.opacity(0.25))
                    .frame(width: 5, height: 5)
                    .frame(width: 12, height: 12)
            }
        }
        .frame(width: 12)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Page \(page + 1) of \(max(pages.count, 1))")
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

    private func turn(to newPage: Int) {
        guard newPage != page else { return }
        withAnimation(NookMotion.reducing(.spring(duration: 0.32, bounce: 0.12), reduceMotion: reduceMotion)) {
            page = newPage
        }
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

    private func tint(_ tab: WorkbenchTab) -> Color {
        switch tab {
        case .nowPlaying: Color(red: 1, green: 0.27, blue: 0.4)
        case .timer: ArrowTheme.amber
        case .calendar: Color(red: 1, green: 0.27, blue: 0.23)
        case .mirror: Color(red: 0.75, green: 0.55, blue: 1)
        case .clipboard, .tray: Color(red: 0.35, green: 0.68, blue: 1)
        case .stats: ArrowTheme.green
        case .sports: Color(red: 0.28, green: 0.78, blue: 0.52)
        case .reminders: Color(red: 0.30, green: 0.60, blue: 1)
        case .notes: Color(red: 1, green: 0.84, blue: 0.35)
        case .stopwatch: Color(red: 1, green: 0.62, blue: 0.23)
        case .keepAwake: Color(red: 1, green: 0.84, blue: 0.30)
        case .home, .launcher: ArrowTheme.bone
        case .call: ArrowTheme.green
        case .download: Color(red: 0.04, green: 0.52, blue: 1)
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
