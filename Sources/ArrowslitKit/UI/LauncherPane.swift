import SwiftUI

/// Corbel-style feature launcher: large tiles, two rows, four across.
struct LauncherPane: View {
    @Bindable var state: AppState

    private let items: [WorkbenchTab] = [
        .nowPlaying, .timer, .calendar, .tray,
        .mirror, .clipboard, .notes, .stats
    ]

    var body: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4),
            spacing: 8
        ) {
            ForEach(items) { tab in
                Button { state.select(tab) } label: {
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
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(tab.title)
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private func tint(_ tab: WorkbenchTab) -> Color {
        switch tab {
        case .nowPlaying: Color(red: 1, green: 0.27, blue: 0.4)
        case .timer: ArrowTheme.amber
        case .calendar: Color(red: 1, green: 0.27, blue: 0.23)
        case .mirror: Color(red: 0.75, green: 0.55, blue: 1)
        case .clipboard, .tray: Color(red: 0.35, green: 0.68, blue: 1)
        case .stats: ArrowTheme.green
        case .notes: Color(red: 1, green: 0.84, blue: 0.35)
        case .home, .launcher: ArrowTheme.bone
        }
    }
}
