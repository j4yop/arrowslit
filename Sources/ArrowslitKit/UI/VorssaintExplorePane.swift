import SwiftUI

/// Vorssaint's Explore surface: five columns, two rows, three pages, with
/// the sixteen Dynamic Island pages and an extra page for Arrowslit's own
/// features. The recording's black tiles, 20-ish radius, shortcut labels and
/// page dots are reproduced here.
struct VorssaintExplorePane: View {
    @Bindable var state: AppState
    @State private var page: Int? = 0
    @State private var hovered: String?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.panelScale) private var scale

    private static let columns = 5
    private static let rows = 2
    private static let gap: CGFloat = 8 * 0.9
    private static let tileHeight: CGFloat = 88

    private var pages: [[VorssaintTile]] {
        let pages = stride(from: 0, to: VorssaintPage.exploreOrder.count, by: Self.columns * Self.rows)
            .map { start in
                Array(VorssaintPage.exploreOrder[start..<min(start + Self.columns * Self.rows,
                                                             VorssaintPage.exploreOrder.count)])
                    .map(VorssaintTile.page)
            }
        let extras = VorssaintPage.arrowslitExtras.map(VorssaintTile.extra)
        return pages + [extras]
    }

    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 10) {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 0) {
                        ForEach(pages.indices, id: \.self) { index in
                            LazyVGrid(
                                columns: Array(
                                    repeating: GridItem(.flexible(), spacing: Self.gap),
                                    count: Self.columns
                                ),
                                spacing: Self.gap
                            ) {
                                ForEach(pages[index]) { tile in
                                    tileView(tile)
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

                pageDots
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
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
                RoundedRectangle(cornerRadius: 17 * scale, style: .continuous)
                    .fill(Color.white.opacity(hovered == tile.id ? 0.10 : 0.055))
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
            .contentShape(RoundedRectangle(cornerRadius: 17 * scale, style: .continuous))
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
                    withAnimation(.smooth(duration: 0.3)) { page = index }
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
