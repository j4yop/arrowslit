import SwiftUI

struct WorkbenchView: View {
    @Bindable var state: AppState

    var body: some View {
        HStack(spacing: 0) {
            Rail(state: state)
            VStack(spacing: 0) {
                Header(state: state)
                Divider().overlay(ArrowTheme.hairline)
                Group {
                    switch state.activeTab {
                    case .home: HomePane(state: state)
                    case .launcher: LauncherPane(state: state)
                    case .nowPlaying: NowPlayingPane(state: state)
                    case .timer: TimerPane(state: state)
                    case .calendar: CalendarPane(state: state)
                    case .tray: TrayPane(state: state)
                    case .mirror: MirrorPane(state: state)
                    case .clipboard: ClipboardPane(state: state)
                    case .notes: NotesPane(state: state)
                    case .stats: StatsPane(state: state)
                    case .reminders: RemindersPane(state: state)
                    case .stopwatch: StopwatchPane(state: state)
                    case .keepAwake: KeepAwakePane(state: state)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(.horizontal, 22)
                .padding(.top, 16)
                .padding(.bottom, 10)
                Footer(state: state)
            }
        }
        .frame(width: 720, height: 420)
        .background(ArrowTheme.ink)
        .clipShape(SlitShape(radius: 22))
        .overlay {
            SlitShape(radius: 22)
                .stroke(ArrowTheme.hairline, lineWidth: 0.5)
        }
        .shadow(color: .black.opacity(0.45), radius: 24, y: 10)
    }
}

private struct Rail: View {
    @Bindable var state: AppState

    var body: some View {
        VStack(spacing: 8) {
            SlitMark(height: 20)
                .padding(.top, 14)
                .padding(.bottom, 10)

            ForEach(WorkbenchTab.allCases) { tab in
                RailButton(
                    symbol: tab.symbol,
                    title: tab.title,
                    isSelected: state.activeTab == tab
                ) {
                    state.select(tab)
                }
            }

            Spacer(minLength: 0)

            RailButton(symbol: "gearshape", title: "Settings", isSelected: false) {
                state.collapse()
                state.onOpenSettings?()
            }
            .padding(.bottom, 14)
        }
        .frame(width: 58)
        .frame(maxHeight: .infinity)
        .background(ArrowTheme.panel.opacity(0.55))
        .overlay(alignment: .trailing) {
            Rectangle().fill(ArrowTheme.hairline).frame(width: 1)
        }
    }
}

private struct RailButton: View {
    let symbol: String
    let title: String
    let isSelected: Bool
    let action: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .leading) {
                if isSelected {
                    Capsule().fill(ArrowTheme.amber).frame(width: 2.5, height: 18)
                }
                Image(systemName: symbol)
                    .font(.system(size: 15, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? ArrowTheme.amber : ArrowTheme.muted)
                    .frame(width: 34, height: 34)
                    .background(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(isSelected ? ArrowTheme.amberSoft : (isHovering ? Color.white.opacity(0.06) : .clear))
                    )
            }
            .frame(width: 44, height: 36)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .help(title)
        .accessibilityLabel(title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct Header: View {
    @Bindable var state: AppState

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("ARROWSLIT")
                    .font(.system(size: 12, weight: .bold))
                    .tracking(3)
                    .foregroundStyle(ArrowTheme.bone)
                Text("LOCAL / PRIVATE")
                    .font(.system(size: 8, weight: .bold))
                    .tracking(1.4)
                    .foregroundStyle(ArrowTheme.amber.opacity(0.8))
            }

            Spacer(minLength: 8)

            Text(ClockFormat.wallClock())
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundStyle(ArrowTheme.muted)

            Button {
                state.collapse()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(ArrowTheme.muted)
                    .frame(width: 24, height: 24)
                    .background(Circle().fill(Color.white.opacity(0.06)))
            }
            .buttonStyle(.plain)
            .help("Close")
            .accessibilityLabel("Close")
        }
        .padding(.horizontal, 22)
        .frame(height: 58)
    }
}

private struct Footer: View {
    @Bindable var state: AppState

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(ArrowTheme.green)
                .frame(width: 5, height: 5)
            Text("NO ACCOUNT · NO ANALYTICS · NO NETWORK")
                .font(.system(size: 8, weight: .semibold))
                .tracking(1.05)
                .foregroundStyle(ArrowTheme.faint)
            Spacer()
            Text("⌘,")
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundStyle(ArrowTheme.faint)
        }
        .padding(.horizontal, 22)
        .frame(height: 28)
    }
}
