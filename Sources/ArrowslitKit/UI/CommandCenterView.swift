import AppKit
import SwiftUI

enum CommandCenterTab: String, CaseIterable, Identifiable {
    case home, capture, system, custom

    var id: String { rawValue }
}

struct CommandCenterView: View {
    @Bindable var state: AppState
    let onClose: () -> Void
    let onOpenClipboard: () -> Void
    let onCapture: (CaptureMode) -> Void

    @State private var tab: CommandCenterTab

    init(state: AppState, startTab: CommandCenterTab = .home, onClose: @escaping () -> Void, onOpenClipboard: @escaping () -> Void, onCapture: @escaping (CaptureMode) -> Void) {
        self.state = state
        self.onClose = onClose
        self.onOpenClipboard = onOpenClipboard
        self.onCapture = onCapture
        _tab = State(initialValue: startTab)
    }
    @State private var showAddTiles = false

    private var customTiles: [CommandTileID] {
        state.settings.commandCenterCustomTiles.compactMap(CommandTileID.init(rawValue:))
    }

    private func addCustomTile(_ id: CommandTileID) {
        var ids = state.settings.commandCenterCustomTiles
        guard !ids.contains(id.rawValue) else { return }
        ids.append(id.rawValue)
        state.settings.commandCenterCustomTiles = ids
    }

    private var haptics: Bool { state.settings.hapticFeedback }

    var body: some View {
        Group {
            if showAddTiles {
                AddTileGallery(haptics: haptics) { id in
                    addCustomTile(id)
                } onCancel: {
                    showAddTiles = false
                }
            } else {
                VStack(spacing: 10) {
                    if state.settings.commandCenterPlayer { player }
                    Group {
                        switch tab {
                        case .home:
                            homeTab
                        case .capture:
                            captureTab
                        case .system:
                            systemTab
                        case .custom:
                            customTab
                        }
                    }
                    .frame(maxHeight: .infinity, alignment: .top)
                    bottomBar
                }
            }
        }
        .padding(11)
        .frame(width: 352, height: 576)
        .background {
            ZStack {
                ArrowVisualEffect(material: .popover)
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.arrowPanelTint)
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(Color.arrowStroke, lineWidth: 0.5)
            }
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .shadow(color: .black.opacity(0.55), radius: 30, y: 18)
        }
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .onAppear { state.systemAppearance.refresh() }
        .alert("Couldn’t change appearance", isPresented: Binding(
            get: { state.systemAppearance.errorMessage != nil },
            set: { if !$0 { state.systemAppearance.clearError() } }
        )) {
            Button("Open Automation Settings") {
                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation")!)
            }
            Button("OK", role: .cancel) { state.systemAppearance.clearError() }
        } message: {
            Text(state.systemAppearance.errorMessage ?? "Allow Arrowslit to control System Events in Privacy & Security › Automation.")
        }
    }

    // MARK: Player

    @ViewBuilder private var player: some View {
        if let track = state.nowPlaying.activeTrack, track.hasContent {
            VStack(spacing: 10) {
                HStack(spacing: 12) {
                    artwork
                    VStack(alignment: .leading, spacing: 2) {
                        Text(track.title)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.arrowText)
                            .lineLimit(1)
                        Text(track.artist)
                            .font(.system(size: 11))
                            .foregroundStyle(Color.arrowSecondaryText)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 6)
                    Image(systemName: state.nowPlaying.activeTrack?.isPlaying == true ? "waveform" : "pause.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.arrowSecondaryText)
                }

                HStack(spacing: 8) {
                    Text(clock(track.elapsed ?? 0))
                    Slider(
                        value: Binding(
                            get: { min(max(track.elapsed ?? 0, 0), max(track.duration ?? 1, 1)) },
                            set: { state.nowPlaying.seek(to: $0) }
                        ),
                        in: 0...max(track.duration ?? 1, 1)
                    )
                    .tint(Color.arrowIcon)
                    .controlSize(.mini)
                    Text("−" + clock(max(0, (track.duration ?? 0) - (track.elapsed ?? 0))))
                }
                .font(.system(size: 9.5, weight: .medium).monospacedDigit())
                .foregroundStyle(Color.arrowSecondaryText)

                HStack(spacing: 48) {
                    control("backward.end.fill") { state.nowPlaying.previous() }
                    control(track.isPlaying ? "pause.fill" : "play.fill", large: true) { state.nowPlaying.toggle() }
                    control("forward.end.fill") { state.nowPlaying.next() }
                }
                .frame(maxWidth: .infinity)
            }
            .padding(12)
            .frame(height: 158)
            .background(Color.arrowCard, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        } else {
            HStack(spacing: 11) {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.arrowStroke)
                    .frame(width: 48, height: 32)
                    .overlay {
                        Image(systemName: "music.note")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color.arrowTertiaryText)
                    }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Nothing playing")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.arrowText)
                    Text("Music and video appear here.")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.arrowSecondaryText)
                }
                Spacer()
            }
            .padding(.horizontal, 14)
            .frame(height: 158)
            .background(Color.arrowCard, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private var artwork: some View {
        Group {
            if let image = state.nowPlaying.activeArtwork {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFill()
            } else {
                ZStack {
                    LinearGradient(colors: [ArrowTheme.amber.opacity(0.55), Color(white: 0.12)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    Image(systemName: "music.note")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.arrowSecondaryText)
                }
            }
        }
        .frame(width: 48, height: 32)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }

    private func control(_ symbol: String, large: Bool = false, action: @escaping () -> Void) -> some View {
        Button {
            action()
            NookHaptics.perform(enabled: haptics)
        } label: {
            Image(systemName: symbol)
                .font(.system(size: large ? 20 : 13, weight: .semibold))
                .foregroundStyle(Color.arrowText)
                .frame(width: large ? 40 : 32, height: large ? 40 : 30)
                .contentShape(Rectangle())
        }
        .buttonStyle(NookPressStyle())
    }

    private func clock(_ value: TimeInterval) -> String {
        let seconds = max(0, Int(value.rounded()))
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    // MARK: Home

    private var homeTab: some View {
        VStack(spacing: 10) {
            Grid(horizontalSpacing: 9, verticalSpacing: 9) {
                GridRow {
                    compactTile(.clipboard)
                    compactTile(.area)
                    compactTile(.window)
                    Group {
                        if state.settings.commandCenterAppearanceTile {
                            compactTile(.appearance)
                        } else {
                            compactTile(.fullscreen)
                        }
                    }
                }
                GridRow {
                    compactTile(.text)
                    compactTile(.timer)
                    wideTile(.keepAwake)
                        .gridCellColumns(2)
                }
                GridRow {
                    compactTile(.settings)
                    compactTile(.stats)
                    Color.clear
                        .frame(height: 75)
                        .gridCellColumns(2)
                }
            }
            if state.settings.commandCenterUpcoming { upcoming }
        }
    }

    private var captureTab: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                captureHero("Area", "Draw a region", "viewfinder", .area)
                captureHero("Window", "Pick a window", "macwindow", .window)
            }
            HStack(spacing: 9) {
                compactTile(.fullscreen)
                compactTile(.text)
                compactTile(.clipboard)
                compactTile(.settings)
            }
            Spacer(minLength: 0)
        }
    }

    private var systemTab: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                systemCard("CPU", "cpu", "\(Int((state.stats.cpu * 100).rounded()))%", "\(ProcessInfo.processInfo.activeProcessorCount) cores", state.stats.cpu)
                systemCard("Memory", "memorychip", "\(Int((state.stats.memoryShare * 100).rounded()))%", "\(bytes(state.stats.memoryUsed)) of \(bytes(state.stats.memoryTotal))", state.stats.memoryShare)
            }
            HStack(spacing: 10) {
                systemCard("Network", "arrow.up.arrow.down", byteRate(state.stats.networkIn), "down · " + byteRate(state.stats.networkOut) + " up", nil)
                systemCard("Battery", "battery.75percent", "\(state.system.batteryLevel)%", state.system.isCharging ? "Charging" : (state.system.isOnAC ? "Plugged in" : "On battery"), Double(state.system.batteryLevel) / 100)
            }
            systemCard("Disk", "externaldrive", "\(Int((state.stats.diskShare * 100).rounded()))%", "\(bytes(UInt64(max(0, state.stats.diskFree)))) free", state.stats.diskShare)
            Spacer(minLength: 0)
        }
        .onAppear { if !state.stats.isRunning { state.stats.start() } }
    }

    private var customTab: some View {
        VStack(spacing: 10) {
            if customTiles.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "square.grid.2x2")
                        .font(.system(size: 27, weight: .medium))
                        .foregroundStyle(Color.arrowTertiaryText)
                    Text("This page is empty")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.arrowText)
                    Button {
                        showAddTiles = true
                        NookHaptics.perform(enabled: haptics)
                    } label: {
                        Label("Add tiles", systemImage: "plus")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.arrowText)
                            .padding(.horizontal, 15)
                            .frame(height: 32)
                            .background(Color.arrowPill, in: Capsule())
                    }
                    .buttonStyle(NookPressStyle())
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                LazyVGrid(columns: Array(repeating: GridItem(.fixed(75), spacing: 9), count: 4), spacing: 9) {
                    ForEach(customTiles) { id in
                        compactTile(id.command)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                HStack {
                    Button {
                        showAddTiles = true
                    } label: {
                        Label("Add tile", systemImage: "plus")
                            .font(.system(size: 10.5, weight: .semibold))
                            .foregroundStyle(Color.arrowSecondaryText)
                    }
                    .buttonStyle(NookPressStyle())
                    Spacer()
                }
            }
        }
    }

    private var upcoming: some View {
        VStack(spacing: 8) {
            HStack(spacing: 7) {
                Image(systemName: "calendar")
                    .font(.system(size: 12, weight: .semibold))
                Text("Upcoming")
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
                Button {
                    state.calendar.requestAccess()
                    NookHaptics.perform(enabled: haptics)
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.arrowSecondaryText)
                        .frame(width: 24, height: 24)
                        .background(Circle().fill(Color.arrowIconCircle))
                }
                .buttonStyle(NookPressStyle())
            }
            .foregroundStyle(Color.arrowText)

            if let event = state.calendar.nextEvent {
                HStack(spacing: 9) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(ArrowTheme.amber)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(event.title)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Color.arrowText)
                            .lineLimit(1)
                        Text(event.start.formatted(date: .abbreviated, time: .shortened))
                            .font(.system(size: 9))
                            .foregroundStyle(Color.arrowSecondaryText)
                    }
                    Spacer()
                }
            } else {
                Text("Nothing coming up")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.arrowTertiaryText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
            }
        }
        .padding(11)
        .frame(height: 82)
        .background(Color.arrowCard, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: Bottom bar

    private var bottomBar: some View {
        HStack(spacing: 8) {
            Button {
                NookHaptics.perform(enabled: haptics)
                state.onOpenSettings?()
                onClose()
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.arrowSecondaryText)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(Color.arrowIconCircle))
            }
            .buttonStyle(NookPressStyle())

            HStack(spacing: 2) {
                tabButton(.home, "square.grid.2x2.fill", "Home")
                tabButton(.capture, "camera", "Capture")
                if state.settings.commandCenterSystem {
                    tabButton(.system, "gearshape.2.fill", "System")
                }
                tabButton(.custom, "square.grid.2x2", "New page")
                Button {
                    NookHaptics.perform(enabled: haptics)
                    state.onOpenSettings?()
                    onClose()
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.arrowSecondaryText)
                        .frame(width: 30, height: 30)
                }
                .buttonStyle(NookPressStyle())
            }
            .padding(3)
            .frame(maxWidth: .infinity)
            .background(Capsule().fill(Color.arrowIconCircle))
        }
    }

    private func tabButton(_ value: CommandCenterTab, _ symbol: String, _ title: String) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) { tab = value }
            NookHaptics.perform(enabled: haptics)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: symbol)
                    .font(.system(size: 11, weight: .semibold))
                if tab == value {
                    Text(title)
                        .font(.system(size: 10, weight: .semibold))
                        .lineLimit(1)
                }
            }
            .foregroundStyle(tab == value ? Color.black : Color.arrowSecondaryText)
            .padding(.horizontal, tab == value ? 10 : 7)
            .frame(height: 30)
            .background(tab == value ? Color.white : Color.clear, in: Capsule())
        }
        .buttonStyle(NookPressStyle())
    }

    // MARK: Tiles

    private func compactTile(_ id: CommandTileID) -> some View {
        let isAppearance = id == .appearance
        let dark = isAppearance && state.systemAppearance.isDark
        return Button {
            perform(id)
            NookHaptics.perform(enabled: haptics)
        } label: {
            Image(systemName: isAppearance ? (dark ? "moon.stars.fill" : "sun.max.fill") : id.symbol)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(dark ? Color.black : Color.arrowIcon)
                .frame(width: 42, height: 42)
                .background(Circle().fill(dark ? Color.white : Color.arrowIconCircle))
                .contentTransition(.symbolEffect(.replace))
                .frame(width: 75, height: 75)
                .background(Color.arrowCard, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(NookPressStyle())
        .animation(.easeInOut(duration: 0.25), value: state.systemAppearance.isDark)
        .help(isAppearance
            ? (state.systemAppearance.isDark ? "Switch to Light Mode" : "Switch to Dark Mode")
            : id.title)
    }

    private func wideTile(_ id: CommandTileID) -> some View {
        Button {
            perform(id)
            NookHaptics.perform(enabled: haptics)
        } label: {
            HStack(spacing: 9) {
                Image(systemName: id.symbol)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Color.arrowIcon)
                    .frame(width: 42, height: 42)
                    .background(Circle().fill(Color.arrowIconCircle))
                VStack(alignment: .leading, spacing: 1) {
                    Text(id.title)
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(Color.arrowText)
                    Text(id.detail)
                        .font(.system(size: 9.5))
                        .foregroundStyle(Color.arrowSecondaryText)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .frame(width: 159, height: 75)
            .background(Color.arrowCard, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(NookPressStyle())
        .help(id.detail)
    }

    private func captureHero(_ title: String, _ detail: String, _ symbol: String, _ mode: CaptureMode) -> some View {
        Button {
            onCapture(mode)
            NookHaptics.perform(enabled: haptics)
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                Image(systemName: symbol)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(Color.arrowIcon)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Color.arrowIconCircle))
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(Color.arrowText)
                    Text(detail)
                        .font(.system(size: 9.5))
                        .foregroundStyle(Color.arrowSecondaryText)
                        .lineLimit(1)
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 86)
            .background(Color.arrowCard, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(NookPressStyle())
    }

    private func systemCard(_ title: String, _ symbol: String, _ value: String, _ detail: String, _ share: Double?) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 7) {
                Image(systemName: symbol)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.arrowSecondaryText)
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.arrowSecondaryText)
                Spacer()
            }
            Text(value)
                .font(.system(size: share == nil ? 18 : 23, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.arrowText)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(detail)
                .font(.system(size: 9))
                .foregroundStyle(Color.arrowTertiaryText)
                .lineLimit(1)
            if let share {
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.arrowIconCircle)
                        Capsule().fill(share > 0.85 ? Color.orange : Color.arrowIcon)
                            .frame(width: proxy.size.width * min(1, max(0, share)))
                    }
                }
                .frame(height: 3)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity)
        .frame(height: 98)
        .background(Color.arrowCard, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func perform(_ id: CommandTileID) {
        switch id {
        case .clipboard:
            onOpenClipboard()
            onClose()
        case .area:
            onCapture(.area)
            onClose()
        case .window:
            onCapture(.window)
            onClose()
        case .fullscreen:
            onCapture(.fullscreen)
            onClose()
        case .text:
            onCapture(.text)
            onClose()
        case .timer:
            state.expand(.timer)
            onClose()
        case .keepAwake:
            state.keepAwake.toggle()
        case .settings:
            state.onOpenSettings?()
            onClose()
        case .stats:
            state.expand(.stats)
            onClose()
        case .appearance:
            state.systemAppearance.toggle()
        }
    }

    private func bytes(_ value: UInt64) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(value), countStyle: .memory)
    }

    private func byteRate(_ value: Double) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(max(0, value)), countStyle: .file) + "/s"
    }
}

private struct AddTileGallery: View {
    let haptics: Bool
    let onAdd: (CommandTileID) -> Void
    let onCancel: () -> Void
    @State private var query = ""

    private var matches: [CommandTileID] {
        let all = CommandTileID.allCases
        guard !query.isEmpty else { return all }
        return all.filter { $0.title.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        VStack(spacing: 9) {
            HStack(spacing: 7) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.arrowSecondaryText)
                TextField("Search tiles", text: $query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.arrowText)
            }
            .padding(.horizontal, 11)
            .frame(height: 34)
            .background(Color.arrowPill, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .strokeBorder(Color.arrowStroke, lineWidth: 0.5)
            }

            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(matches) { id in
                        Button {
                            onAdd(id)
                            NookHaptics.perform(enabled: haptics)
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: id.symbol)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(Color.arrowIcon)
                                    .frame(width: 34, height: 34)
                                    .background(Circle().fill(Color.arrowIconCircle))
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(id.title)
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(Color.arrowText)
                                    Text(id.detail)
                                        .font(.system(size: 9.5))
                                        .foregroundStyle(Color.arrowTertiaryText)
                                }
                                Spacer(minLength: 4)
                                HStack(spacing: 7) {
                                    Image(systemName: "plus.square.on.square")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(Color.arrowTertiaryText)
                                    Image(systemName: "plus")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundStyle(Color.arrowText)
                                        .frame(width: 24, height: 24)
                                        .background(Circle().fill(Color.arrowIconCircle))
                                }
                            }
                            .padding(.horizontal, 7)
                            .frame(height: 52)
                            .background(Color.arrowPill.opacity(0.55), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                        .buttonStyle(NookPressStyle())
                    }
                }
            }

            HStack(spacing: 8) {
                Label("New page", systemImage: "square.grid.2x2")
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(Color.arrowSecondaryText)
                Spacer()
                Button(action: onCancel) {
                    Label("Back to page", systemImage: "chevron.left")
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundStyle(Color.arrowText)
                        .padding(.horizontal, 12)
                        .frame(height: 28)
                        .background(Capsule().fill(Color.arrowPill))
                }
                .buttonStyle(NookPressStyle())
            }
            .padding(.horizontal, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

enum CommandTileID: String, CaseIterable, Identifiable {
    case clipboard, area, window, fullscreen, text, timer, keepAwake, settings, stats, appearance

    var id: String { rawValue }
    var command: CommandTileID { self }

    var title: String {
        switch self {
        case .clipboard: "Clipboard"
        case .area: "Area"
        case .window: "Window"
        case .fullscreen: "Fullscreen"
        case .text: "Text Capture"
        case .timer: "Timer"
        case .keepAwake: "Keep Awake"
        case .settings: "Settings"
        case .stats: "System"
        case .appearance: "Appearance"
        }
    }

    var detail: String {
        switch self {
        case .clipboard: "Clipboard history and pinned clips"
        case .area: "Capture an area of the screen"
        case .window: "Capture a window"
        case .fullscreen: "Capture the whole screen"
        case .text: "Extract text from the screen"
        case .timer: "Start a timer"
        case .keepAwake: "Keep your Mac awake"
        case .settings: "Open Arrowslit Settings"
        case .stats: "CPU, memory, network and battery"
        case .appearance: "Switch macOS between light and dark"
        }
    }

    var symbol: String {
        switch self {
        case .clipboard: "doc.on.clipboard"
        case .area: "viewfinder"
        case .window: "macwindow"
        case .fullscreen: "arrow.up.left.and.arrow.down.right"
        case .text: "text.viewfinder"
        case .timer: "timer"
        case .keepAwake: "cup.and.saucer.fill"
        case .settings: "gearshape.fill"
        case .stats: "chart.bar.fill"
        case .appearance: "circle.lefthalf.filled"
        }
    }
}
