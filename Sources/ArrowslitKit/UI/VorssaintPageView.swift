import SwiftUI

/// One page inside the Vorssaint-style Explore surface.
struct VorssaintPageView: View {
    @Bindable var state: AppState
    let page: VorssaintPage

    var body: some View {
        Group {
            switch page {
            case .controls:
                VorssaintControlsPane(state: state)
            case .mixer:
                VorssaintMixerPane(state: state)
            case .music:
                NowPlayingPane(state: state)
            case .clipboard:
                ClipboardPane(state: state)
            case .captures:
                VorssaintCapturesPane(state: state)
            case .files:
                TrayPane(state: state)
            case .system:
                StatsPane(state: state)
            case .tools:
                VorssaintToolsPane(state: state)
            case .calendar:
                CalendarPane(state: state)
            case .notifications:
                VorssaintNotificationsPane(state: state)
            case .timer:
                TimerPane(state: state)
            case .camera:
                MirrorPane(state: state)
            case .downloads:
                DownloadPane(state: state)
            case .scratchpad:
                NotesPane(state: state)
            case .agents:
                VorssaintAgentsPane(state: state)
            case .watch:
                VorssaintWatchPane(state: state)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .accessibilityIdentifier("vorssaint.page.\(page.rawValue)")
    }
}
