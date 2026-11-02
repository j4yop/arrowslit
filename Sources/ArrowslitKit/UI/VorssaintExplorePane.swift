import SwiftUI

/// Vorssaint's Explore surface: five columns, two rows, three pages, with
/// the sixteen Dynamic Island pages and an extra page for Arrowslit's own
/// features. Page dots and the wheel both move one grid at a time.
struct VorssaintExplorePane: View {
    @Bindable var state: AppState
    var query: String = ""
    @State private var pageIndex = 0
    @State private var hovered: String?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.panelScale) private var scale

    private static let columns = 5
    private static let gap: CGFloat = 8
    private static let tileHeight: CGFloat = 86
    private static let pageHeight: CGFloat = 180

    private var pages: [[VorssaintTile]] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let matches: (VorssaintPage) -> Bool = { page in
            needle.isEmpty
                || page.title.lowercased().contains(needle)
                || page.shortcutKey.lowercased().contains(needle)
        }
        let filtered = VorssaintPage.exploreOrder.filter(matches)
        let pages = stride(from: 0, to: filtered.count, by: Self.columns * 2)
            .map { start in
                Array(filtered[start..<min(start + Self.columns * 2, filtered.count)])
                    .map(VorssaintTile.page)
            }
        let extras = VorssaintPage.arrowslitExtras
            .filter { needle.isEmpty || $0.title.lowercased().contains(needle) }
            .map(VorssaintTile.extra)
        let all = pages + (extras.isEmpty ? [] : [extras])
        return all.isEmpty ? [[]] : all
    }

    private var currentTiles: [VorssaintTile] {
        pages.indices.contains(pageIndex) ? pages[pageIndex] : []
    }

    var body: some View {
        HStack(spacing: 10) {
            ZStack(alignment: .topLeading) {
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: Self.gap), count: Self.columns),
                    spacing: Self.gap
                ) {
                    ForEach(currentTiles) { tile in
                        tileView(tile)
                    }
                }
                .frame(height: Self.pageHeight, alignment: .top)
                .id(pageIndex)
                .transition(.asymmetric(
                    insertion: .move(edge: .bottom).combined(with: .opacity),
                    removal: .move(edge: .top).combined(with: .opacity)
                ))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            pageDots
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background {
            ExploreScrollMonitor { direction in
                movePage(direction)
            }
        }
        .onChange(of: query) { _, _ in
            pageIndex = 0
        }
        .overlay {
            if currentTiles.isEmpty {
                VorssaintPageEmpty(symbol: "magnifyingglass", title: "No matches",
                                   detail: "Try a page name or a shortcut letter.")
            }
        }
        .accessibilityIdentifier("vorssaint.explore")
    }

    private func tileView(_ tile: VorssaintTile) -> some View {
        let selected = tile.page == .music && state.nowPlaying.isVisible
        let live = tile.page.map(isLive) ?? false
        return Button {
            activate(tile)
        } label: {
            VStack(spacing: 0) {
                Image(systemName: tile.symbol)
                    .font(.system(size: 20 * scale, weight: .regular))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(tile.page?.accent ?? (tile.tab == .sports ? ArrowTheme.green : .white))
                    .frame(height: 25 * scale)
                Text(tile.title)
                    .font(.system(size: 11.5 * scale, weight: .medium))
                    .foregroundStyle(.white.opacity(0.92))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .padding(.top, 7 * scale)
                if !tile.shortcut.isEmpty {
                    Text(tile.shortcut)
                        .font(.system(size: 9.5 * scale, weight: .regular))
                        .kerning(0.5 * scale)
                        .foregroundStyle(Color.white.opacity(0.38))
                        .padding(.top, 2 * scale)
                }
            }
            .padding(.horizontal, 5 * scale)
            .frame(maxWidth: .infinity)
            .frame(height: Self.tileHeight * scale)
            .background(
                RoundedRectangle(cornerRadius: 14 * scale, style: .continuous)
                    .fill(hovered == tile.id ? VorssaintTheme.cardHover : VorssaintTheme.tile)
            )
            .overlay(alignment: .topTrailing) {
                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 13 * scale, weight: .semibold))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, Color.white.opacity(0.55))
                        .padding(7 * scale)
                } else if live {
                    Circle()
                        .fill(tile.page?.accent ?? ArrowTheme.green)
                        .frame(width: 5 * scale, height: 5 * scale)
                        .padding(9 * scale)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: 14 * scale, style: .continuous))
        }
        .buttonStyle(NookPressStyle())
        .onHover { isHovering in
            hovered = isHovering ? tile.id : nil
        }
        .animation(NookMotion.reducing(.easeOut(duration: 0.15), reduceMotion: reduceMotion), value: hovered)
        .help(tile.title)
        .accessibilityLabel(tile.title)
        .accessibilityIdentifier("vorssaint.tile.\(tile.id)")
    }

    private var pageDots: some View {
        VStack(spacing: 8 * scale) {
            ForEach(pages.indices, id: \.self) { index in
                Button {
                    goToPage(index)
                } label: {
                    Circle()
                        .fill(Color.white.opacity(pageIndex == index ? 0.9 : 0.3))
                        .frame(width: 6 * scale, height: 6 * scale)
                        .frame(width: 14 * scale, height: 14 * scale)
                        .contentShape(Rectangle())
                }
                .buttonStyle(NookPressStyle())
                .accessibilityLabel("Page \(index + 1) of \(pages.count)")
            }
        }
        .frame(maxHeight: .infinity)
    }

    private func goToPage(_ index: Int) {
        guard pages.indices.contains(index), index != pageIndex else { return }
        withAnimation(.smooth(duration: 0.28)) { pageIndex = index }
        NookHaptics.perform(enabled: state.settings.hapticFeedback)
    }

    private func movePage(_ direction: Int) {
        goToPage(min(max(pageIndex + direction, 0), max(0, pages.count - 1)))
    }

    private func activate(_ tile: VorssaintTile) {
        if let page = tile.page {
            state.openVorssaint(page)
        } else if let tab = tile.tab {
            state.select(tab)
        }
        NookHaptics.perform(enabled: state.settings.hapticFeedback)
    }

    private func isLive(_ page: VorssaintPage) -> Bool {
        switch page {
        case .music: state.nowPlaying.isVisible
        case .timer: state.timer.isActive
        case .downloads: !state.downloadProgress.items.isEmpty
        case .system: state.stats.isRunning
        case .calendar: state.calendar.nextEvent != nil
        default: false
        }
    }
}

/// Watches the wheel over the grid without taking clicks away from the tiles.
private struct ExploreScrollMonitor: NSViewRepresentable {
    let onPage: (Int) -> Void

    func makeNSView(context: Context) -> ExploreMonitorView {
        let view = ExploreMonitorView()
        view.onPage = onPage
        view.install()
        return view
    }

    func updateNSView(_ view: ExploreMonitorView, context: Context) {
        view.onPage = onPage
    }

    static func dismantleNSView(_ view: ExploreMonitorView, coordinator: ()) {
        view.remove()
    }
}

final class ExploreMonitorView: NSView {
    var onPage: ((Int) -> Void)?
    private var monitor: Any?
    private var accumulated: CGFloat = 0

    func install() {
        monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            guard let self, self.window != nil else { return event }
            let point = self.convert(event.locationInWindow, from: nil)
            guard self.bounds.contains(point) else { return event }
            self.accumulated += event.scrollingDeltaY
            let threshold: CGFloat = event.hasPreciseScrollingDeltas ? 18 : 1
            if abs(self.accumulated) >= threshold {
                let direction = self.accumulated > 0 ? -1 : 1
                self.accumulated = 0
                self.onPage?(direction)
            }
            return nil
        }
    }

    func remove() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
    }
}

private struct VorssaintTile: Identifiable {
    let id: String
    let title: String
    let symbol: String
    let shortcut: String
    let page: VorssaintPage?
    let tab: WorkbenchTab?

    static func page(_ page: VorssaintPage) -> VorssaintTile {
        VorssaintTile(
            id: page.rawValue,
            title: page.title,
            symbol: page.symbol,
            shortcut: page.shortcutLabel,
            page: page,
            tab: nil
        )
    }

    static func extra(_ item: (title: String, symbol: String, shortcut: String, tab: WorkbenchTab)) -> VorssaintTile {
        VorssaintTile(
            id: "arrowslit.\(item.tab.rawValue)",
            title: item.title,
            symbol: item.symbol,
            shortcut: item.shortcut,
            page: nil,
            tab: item.tab
        )
    }
}
