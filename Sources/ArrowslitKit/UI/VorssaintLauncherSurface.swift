import AppKit
import SwiftUI

/// Vorssaint's expanded-island geometry, taken from `NotchLayout` and
/// `NotchQuickAccessLayout` in the reference app.
enum VorssaintWindow {
    static let panelWidth: CGFloat = 560
    static let gutter: CGFloat = 72
    static let totalWidth: CGFloat = panelWidth + gutter * 2
    static let headerHeight: CGFloat = 36
    static let horizontalInset: CGFloat = 28
    static let spacing: CGFloat = 12
    static let bottomInset: CGFloat = 16
    static let quickDiameter: CGFloat = 44
    static let quickGap: CGFloat = 12
    static let quickRowSpacing: CGFloat = 54
    static let quickCenterY: CGFloat = 66
    static let bottomChrome: CGFloat = 72
    static let cornerRadius: CGFloat = 28

    /// The reference island grows for pages that read as a vertical surface.
    /// The agent page keeps its cards on screen; every other page uses the
    /// compact strip's 180-point content budget.
    static func panelHeight(for page: VorssaintPage?) -> CGFloat {
        switch page {
        case .agents: 328
        default: 244
        }
    }

    static func contentHeight(for page: VorssaintPage?) -> CGFloat {
        panelHeight(for: page) - headerHeight - spacing - bottomInset
    }

    static func windowHeight(for page: VorssaintPage?) -> CGFloat {
        panelHeight(for: page) + bottomChrome
    }

    static func leftQuickCenter(index: Int) -> CGPoint {
        CGPoint(x: gutter - (quickGap + quickDiameter / 2),
                y: quickCenterY + CGFloat(index) * quickRowSpacing)
    }

    static func rightQuickCenter(index: Int) -> CGPoint {
        CGPoint(x: totalWidth - gutter + quickGap + quickDiameter / 2,
                y: quickCenterY + CGFloat(index) * quickRowSpacing)
    }

    static func musicCenter(for page: VorssaintPage?) -> CGPoint {
        CGPoint(x: totalWidth / 2, y: panelHeight(for: page) + quickGap + quickDiameter / 2)
    }
}

/// The whole floating layer: the centred panel plus Vorssaint's five quick
/// buttons, two on each side and the player below. The panel is 560 pt wide
/// and the window is 704 pt, so the buttons sit in the gutters exactly as the
/// reference app's `NotchQuickAccessLayout` places them.
struct VorssaintLauncherSurface: View {
    @Bindable var state: AppState
    @Environment(\.panelScale) private var scale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @State private var menuOpen = false
    @State private var revealed = false
    @State private var hoveringMenu = false
    @State private var searchOpen = false
    @State private var query = ""
    @AppStorage("arrowslit.companion.enabled") private var companionEnabled = true
    @FocusState private var searchFocused: Bool

    private var page: VorssaintPage? { state.vorssaintPage }
    private var panelHeight: CGFloat { VorssaintWindow.panelHeight(for: page) }
    private var windowHeight: CGFloat { VorssaintWindow.windowHeight(for: page) }

    var body: some View {
        ZStack(alignment: .topLeading) {
            panel
                .frame(width: VorssaintWindow.panelWidth, height: panelHeight, alignment: .top)
                .position(x: VorssaintWindow.totalWidth / 2, y: panelHeight / 2)

            quickButton(
                symbol: page == nil ? "square.grid.2x2" : "arrow.uturn.backward",
                title: page == nil ? "Explore" : "Back to Explore",
                selected: page == nil,
                revealX: 44,
                action: {
                    if page != nil { state.closeVorssaintPage() }
                }
            )
            .position(VorssaintWindow.leftQuickCenter(index: 0))

            quickButton(
                symbol: "timer",
                title: "Timer",
                selected: page == .timer,
                revealX: 44,
                action: { state.openVorssaint(.timer) }
            )
            .position(VorssaintWindow.leftQuickCenter(index: 1))

            quickButton(
                symbol: "gearshape.fill",
                title: "Settings",
                selected: false,
                revealX: -44,
                action: {
                    state.collapse()
                    state.onOpenSettings?()
                }
            )
            .position(VorssaintWindow.rightQuickCenter(index: 0))

            quickButton(
                symbol: "speaker.wave.2.fill",
                title: "Volume mixer",
                selected: page == .mixer,
                revealX: -44,
                action: { state.openVorssaint(.mixer) }
            )
            .position(VorssaintWindow.rightQuickCenter(index: 1))

            quickButton(
                symbol: state.nowPlaying.isVisible && (state.nowPlaying.activeTrack?.isPlaying ?? false)
                    ? "waveform" : "music.note",
                title: "Now Playing",
                selected: page == .music,
                revealX: 0,
                revealY: -44,
                action: { state.openVorssaint(.music) }
            )
            .position(VorssaintWindow.musicCenter(for: page))

            if menuOpen {
                menu
                    .frame(width: 200)
                    .position(
                        x: VorssaintWindow.totalWidth - VorssaintWindow.gutter - VorssaintWindow.horizontalInset - 100,
                        y: 44 + 63
                    )
                    .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .topTrailing)))
                    .zIndex(10)
            }
        }
        .frame(width: VorssaintWindow.totalWidth, height: windowHeight)
        .onAppear {
            guard !reduceMotion else { revealed = true; return }
            withAnimation(.spring(duration: 0.38, bounce: 0.12)) { revealed = true }
        }
        .animation(reduceMotion ? nil : .spring(duration: 0.24, bounce: 0.1), value: menuOpen)
        .animation(reduceMotion ? nil : .spring(duration: 0.24, bounce: 0.1), value: searchOpen)
        .animation(reduceMotion ? nil : .spring(duration: 0.34, bounce: 0.14), value: page)
        .accessibilityIdentifier("vorssaint.launcher")
    }

    // MARK: - Panel

    private var panel: some View {
        VStack(spacing: 0) {
            header
            pageContent
                .padding(.horizontal, VorssaintWindow.horizontalInset)
                .padding(.top, VorssaintWindow.spacing)
                .padding(.bottom, VorssaintWindow.bottomInset)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(width: VorssaintWindow.panelWidth, height: panelHeight, alignment: .top)
        .background {
            VorssaintPanelBackground(
                opaque: state.settings.appearance.pitchBlack || reduceTransparency
            )
        }
        .clipShape(RoundedRectangle(cornerRadius: VorssaintWindow.cornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: VorssaintWindow.cornerRadius, style: .continuous)
                .stroke(Color.white.opacity(0.09), lineWidth: 0.75)
        }
        .shadow(color: .black.opacity(0.4), radius: 30, y: 10)
    }

    private var header: some View {
        HStack(spacing: 8) {
            if page == nil {
                Button {
                    state.collapse()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.55))
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(NookPressStyle(pressedScale: 0.92))
                .help("Close")

                if searchOpen {
                    HStack(spacing: 5) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 10.5, weight: .medium))
                            .foregroundStyle(.white.opacity(0.45))
                        TextField("Search", text: $query)
                            .textFieldStyle(.plain)
                            .font(.system(size: 11.5))
                            .foregroundStyle(.white.opacity(0.9))
                            .focused($searchFocused)
                            .frame(width: 150)
                            .onSubmit { searchOpen = false }
                        if !query.isEmpty {
                            Button {
                                query = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.white.opacity(0.3))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 9)
                    .frame(height: 26)
                    .background(Capsule().fill(Color.white.opacity(0.08)))
                    .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .leading)))
                } else {
                    Button {
                        withAnimation(.smooth(duration: 0.2)) { searchOpen = true }
                        searchFocused = true
                    } label: {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 12.5, weight: .medium))
                            .foregroundStyle(.white.opacity(0.55))
                            .frame(width: 24, height: 24)
                    }
                    .buttonStyle(NookPressStyle(pressedScale: 0.92))
                    .help("Search pages")
                }
            } else {
                Text(page?.title ?? "Explore")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.96))
                    .lineLimit(1)
            }
            Spacer(minLength: 8)

            pageHeaderTools

            Button {
                menuOpen.toggle()
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(menuOpen ? 1 : 0.78))
                    .frame(width: 30, height: 30)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(menuOpen ? Color.white.opacity(0.11) : .clear)
                    )
                    .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(NookPressStyle(pressedScale: 0.94))
            .help("Menu")
            .accessibilityLabel("Menu")
            .accessibilityIdentifier("vorssaint.menu")
        }
        .padding(.horizontal, VorssaintWindow.horizontalInset)
        .frame(height: VorssaintWindow.headerHeight)
    }

    @ViewBuilder private var pageHeaderTools: some View {
        switch page {
        case .controls:
            VorssaintCompanion(enabled: $companionEnabled)
                .scaleEffect(0.62, anchor: .trailing)
                .frame(width: 42, height: 28, alignment: .trailing)
        case .notifications:
            Button("Clear") {
                NotchNotificationService.shared.clearAll()
                state.clearAlertHistory()
            }
            .buttonStyle(.plain)
            .font(.system(size: 10.5, weight: .semibold))
            .foregroundStyle(.white.opacity(0.6))
        case .agents:
            Menu {
                Button("Today") { UserDefaults.standard.set(AgentPeriod.today.rawValue, forKey: "arrowslit.agents.period") }
                Button("7 days") { UserDefaults.standard.set(AgentPeriod.week.rawValue, forKey: "arrowslit.agents.period") }
                Button("30 days") { UserDefaults.standard.set(AgentPeriod.month.rawValue, forKey: "arrowslit.agents.period") }
            } label: {
                HStack(spacing: 3) {
                    Text(agentPeriodLabel)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 7.5, weight: .bold))
                }
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(.white.opacity(0.48))
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        default:
            EmptyView()
        }
    }

    private var agentPeriodLabel: String {
        switch AgentPeriod(rawValue: UserDefaults.standard.string(forKey: "arrowslit.agents.period") ?? "") ?? .today {
        case .today: "Today"
        case .week: "7 days"
        case .month: "30 days"
        }
    }

    @ViewBuilder private var pageContent: some View {
        Group {
            if let page {
                VorssaintPageView(state: state, page: page)
            } else {
                VorssaintExplorePane(state: state, query: query)
            }
        }
        .environment(\.vorssaintEmbedded, true)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: - Quick access

    private func quickButton(symbol: String, title: String, selected: Bool,
                             revealX: CGFloat = 0, revealY: CGFloat = 0,
                             action: @escaping () -> Void) -> some View {
        VorssaintQuickButton(
            symbol: symbol,
            title: title,
            selected: selected,
            revealX: revealX,
            revealY: revealY,
            revealed: revealed,
            action: action
        )
    }

    // MARK: - Menu

    private var menu: some View {
        VStack(spacing: 0) {
            menuRow(symbol: menuOpen && state.vorssaintPinned ? "pin.fill" : "pin",
                    title: state.vorssaintPinned ? "Let close" : "Keep open",
                    selected: state.vorssaintPinned) {
                state.toggleVorssaintPinned()
                menuOpen = false
            }
            menuRow(symbol: "gearshape", title: "Settings…") {
                menuOpen = false
                state.collapse()
                state.onOpenSettings?()
            }
            menuRow(symbol: "chevron.up", title: "Collapse") {
                menuOpen = false
                state.collapse()
            }
        }
        .padding(6)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(white: 0.16))
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 0.75)
        }
        .shadow(color: .black.opacity(0.35), radius: 18, y: 8)
    }

    private func menuRow(symbol: String, title: String, selected: Bool = false,
                         action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: symbol)
                    .font(.system(size: 13, weight: .medium))
                    .frame(width: 17)
                Text(title)
                    .font(.system(size: 12.5, weight: .medium))
                Spacer(minLength: 0)
                if selected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
            .foregroundStyle(.white.opacity(0.92))
            .padding(.horizontal, 10)
            .frame(height: 38)
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(NookMenuRowStyle())
    }
}

/// A hover row inside the ellipsis menu.
private struct NookMenuRowStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(configuration.isPressed ? Color.white.opacity(0.12) : Color.clear)
            )
    }
}

/// Smoked glass under the Vorssaint panel. The reference app is translucent:
/// over the dark wallpaper in the recordings it reads as black, while the
/// desktop still shows through the tiles. Reduce Transparency and the
/// pitch-black Arrowslit appearance fall back to the solid surface.
struct VorssaintPanelBackground: View {
    let opaque: Bool

    var body: some View {
        ZStack {
            if opaque {
                Color.black
            } else {
                VorssaintBackdropBlur()
                    .allowsHitTesting(false)
                Color.black.opacity(0.62)
                LinearGradient(
                    colors: [.white.opacity(0.045), .clear],
                    startPoint: .top,
                    endPoint: .center
                )
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct VorssaintBackdropBlur: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .hudWindow
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {}
}

// MARK: - Embedded pages

private struct VorssaintEmbeddedKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    /// True inside the Vorssaint floating layer, where the launcher draws the
    /// page title and ellipsis once instead of every page drawing its own row.
    var vorssaintEmbedded: Bool {
        get { self[VorssaintEmbeddedKey.self] }
        set { self[VorssaintEmbeddedKey.self] = newValue }
    }
}


/// One of the five floating circles beside the panel. It lifts a little on
/// hover, keeps the reference's 44-point size, and springs out from behind
/// the panel when the island opens.
private struct VorssaintQuickButton: View {
    let symbol: String
    let title: String
    let selected: Bool
    let revealX: CGFloat
    let revealY: CGFloat
    let revealed: Bool
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: VorssaintWindow.quickDiameter, height: VorssaintWindow.quickDiameter)
                .background(
                    Circle().fill(hovering ? Color(white: 0.08) : Color.black)
                )
                .overlay {
                    Circle().strokeBorder(
                        .white.opacity(selected ? 0.6 : (hovering ? 0.26 : 0.16)),
                        lineWidth: 0.75
                    )
                }
                .contentShape(Circle())
        }
        .buttonStyle(NookPressStyle(pressedScale: 0.92))
        .scaleEffect(revealed ? (hovering ? 1.04 : 1) : 0.4)
        .offset(x: revealed ? 0 : revealX, y: revealed ? 0 : revealY)
        .opacity(revealed ? 1 : 0)
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.14), value: hovering)
        .help(title)
        .accessibilityLabel(title)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
