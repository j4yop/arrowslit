import SwiftUI

/// Everything the closed notch can show: feedback events, persistent strips
/// and the Dynamic Island features Arrowslit implements. Rows whose macOS
/// surface is not present are shown disabled with the reason, rather than
/// pretending to work.
struct NotchSettingsPage: View {
    @Bindable var state: AppState

    var body: some View {
        Group {
            SettingsSection(
                title: "Live feedback",
                note: "A brief heads-up in the notch. These match Arrowslit's 15 feedback events; rows without a macOS source are disabled."
            ) {
                ForEach(NotchLiveSettings.Event.allCases) { event in
                    AlertToggleRow(
                        symbol: event.symbol,
                        tint: event.tint,
                        title: event.title,
                        detail: event.detail(available: state.live.isAvailable(event)),
                        isOn: Binding(
                            get: { state.live.isOn(event) },
                            set: { state.live.set(event, $0) }
                        )
                    )
                    .disabled(!state.live.isAvailable(event))
                    .opacity(state.live.isAvailable(event) ? 1 : 0.45)
                }
            }

            SettingsSection(
                title: "Live activities",
                note: "What can stay beside the camera while it is happening. Expanded pages keep working when a strip is off."
            ) {
                ForEach(NotchLiveSettings.Strip.allCases) { strip in
                    AlertToggleRow(
                        symbol: strip.symbol,
                        tint: strip.tint,
                        title: strip.title,
                        detail: strip.detail(available: state.live.isAvailable(strip)),
                        isOn: Binding(
                            get: { state.live.isOn(strip) },
                            set: { state.live.set(strip, $0) }
                        )
                    )
                    .disabled(!state.live.isAvailable(strip))
                    .opacity(state.live.isAvailable(strip) ? 1 : 0.45)
                }
            }

            SettingsSection(
                title: "Dynamic Island features",
                note: "The 13 feature switches AI Agents groups under Dynamic Island. Arrowslit wires the ones it has; the rest stay visible but disabled."
            ) {
                ForEach(FeatureSwitch.allCases) { feature in
                    featureRow(feature)
                }
            }
        }
        .padding(.top, 8)
    }

    @ViewBuilder
    private func featureRow(_ feature: FeatureSwitch) -> some View {
        let available = feature.isAvailable(state)
        AlertToggleRow(
            symbol: feature.symbol,
            tint: feature.tint,
            title: feature.title,
            detail: available ? feature.detail : "\(feature.detail) Not available in this build.",
            isOn: feature.binding(state)
        )
        .disabled(!available)
        .opacity(available ? 1 : 0.45)
    }
}

private extension NotchLiveSettings.Event {
    var title: String {
        switch self {
        case .volume: "Volume"
        case .brightness: "Brightness"
        case .keyboardLight: "Keyboard light"
        case .microphone: "Microphone"
        case .inputSource: "Input source"
        case .battery: "Battery & charging"
        case .accessory: "Accessory"
        case .systemNotification: "System notifications"
        case .clipboard: "Clipboard"
        case .capture: "Capture"
        case .download: "Downloads"
        case .agents: "AI agents"
        case .track: "New track"
        case .timer: "Timer"
        case .watch: "Watch"
        }
    }

    var symbol: String {
        switch self {
        case .volume: "speaker.wave.2.fill"
        case .brightness: "sun.max.fill"
        case .keyboardLight: "keyboard"
        case .microphone: "mic.fill"
        case .inputSource: "keyboard.badge.ellipsis"
        case .battery: "battery.75percent"
        case .accessory: "headphones"
        case .systemNotification: "bell.fill"
        case .clipboard: "doc.on.clipboard"
        case .capture: "camera.viewfinder"
        case .download: "arrow.down.circle.fill"
        case .agents: "sparkles"
        case .track: "music.note"
        case .timer: "timer"
        case .watch: "eye"
        }
    }

    var tint: Color {
        switch self {
        case .volume, .brightness, .keyboardLight: ArrowTheme.blue
        case .microphone: ArrowTheme.red
        case .battery, .accessory: ArrowTheme.green
        case .inputSource, .systemNotification, .track: ArrowTheme.blue
        case .clipboard, .download, .agents, .watch: ArrowTheme.green
        case .capture, .timer: ArrowTheme.amber
        }
    }

    func detail(available: Bool) -> String {
        let base = switch self {
        case .volume: "Shows the output level or mute state."
        case .brightness: "Shows the display brightness level."
        case .keyboardLight: "Shows the keyboard backlight level."
        case .microphone: "Shows when the microphone is muted or live."
        case .inputSource: "Shows the keyboard layout after a switch."
        case .battery: "Charging and low-battery warnings."
        case .accessory: "A Bluetooth audio accessory connecting."
        case .systemNotification: "Mirrors a macOS Notification Center banner."
        case .clipboard: "A short confirmation when something is copied."
        case .capture: "The capture preview and toolbar."
        case .download: "A confirmation when a download finishes."
        case .agents: "Finished turns, limit warnings and budget notices."
        case .track: "The title and artist when a new song starts."
        case .timer: "The notice when a timer finishes."
        case .watch: "The notice when a watched area changes."
        }
        return available ? base : "\(base) Not available in this build."
    }
}

private extension NotchLiveSettings.Strip {
    var title: String {
        switch self {
        case .timer: "Timer"
        case .watch: "Watch"
        case .download: "Downloads"
        case .agents: "AI agents"
        case .calendar: "Calendar"
        case .music: "Music"
        case .keepAwake: "Keep Awake"
        }
    }

    var symbol: String {
        switch self {
        case .timer: "timer"
        case .watch: "eye"
        case .download: "arrow.down.circle"
        case .agents: "sparkles"
        case .calendar: "calendar"
        case .music: "music.note"
        case .keepAwake: "cup.and.saucer.fill"
        }
    }

    var tint: Color {
        switch self {
        case .timer, .calendar: ArrowTheme.amber
        case .watch, .agents, .keepAwake: ArrowTheme.green
        case .download, .music: ArrowTheme.blue
        }
    }

    func detail(available: Bool) -> String {
        let base = switch self {
        case .timer: "The running countdown beside the camera."
        case .watch: "A watched screen area while it is being observed."
        case .download: "Active downloads and their progress."
        case .agents: "Working providers and the chosen reading."
        case .calendar: "The next event and its countdown."
        case .music: "Artwork, title, artist and the equalizer."
        case .keepAwake: "The running Keep Awake session."
        }
        return available ? base : "\(base) Not available in this build."
    }
}

private enum FeatureSwitch: String, CaseIterable, Identifiable {
    case notch, calendar, notifications, gestures, timer, accessories, lyrics
    case queue, equalizer, downloads, agents, watch, mascot

    var id: String { rawValue }

    var title: String {
        switch self {
        case .notch: "Dynamic Island"
        case .calendar: "Calendar"
        case .notifications: "Notifications"
        case .gestures: "Hover gestures"
        case .timer: "Timer"
        case .accessories: "Accessories"
        case .lyrics: "Lyrics"
        case .queue: "Queue"
        case .equalizer: "Live equalizer"
        case .downloads: "Downloads"
        case .agents: "AI Agents"
        case .watch: "Watch"
        case .mascot: "Companion"
        }
    }

    var symbol: String {
        switch self {
        case .notch: "capsule"
        case .calendar: "calendar"
        case .notifications: "bell"
        case .gestures: "hand.draw"
        case .timer: "timer"
        case .accessories: "battery.25percent"
        case .lyrics: "quote.bubble"
        case .queue: "list.bullet"
        case .equalizer: "waveform"
        case .downloads: "arrow.down.circle"
        case .agents: "sparkles"
        case .watch: "eye"
        case .mascot: "face.smiling"
        }
    }

    var tint: Color {
        switch self {
        case .notch: ArrowTheme.blue
        case .calendar, .timer: ArrowTheme.amber
        case .notifications, .queue, .lyrics, .equalizer, .downloads: ArrowTheme.blue
        case .gestures, .accessories, .agents, .watch, .mascot: ArrowTheme.green
        }
    }

    var detail: String {
        switch self {
        case .notch: "The core island and its closed strip."
        case .calendar: "The calendar page and countdown strip."
        case .notifications: "A mirrored Notification Center inbox."
        case .gestures: "Open the island by hovering over it."
        case .timer: "The timer page and countdown strip."
        case .accessories: "Accessory connection feedback."
        case .lyrics: "Timed lyrics for the current song."
        case .queue: "The up-next list in the music page."
        case .equalizer: "The animated bars in the music strip."
        case .downloads: "The download page and progress strip."
        case .agents: "The AI Agents page and live compact strip."
        case .watch: "OCR monitoring of a screen area."
        case .mascot: "The animated companion."
        }
    }

    func isAvailable(_ state: AppState) -> Bool {
        switch self {
        case .notifications, .queue, .watch, .mascot: false
        default: true
        }
    }

    func binding(_ state: AppState) -> Binding<Bool> {
        switch self {
        case .notch:
            return .constant(true)
        case .calendar:
            return Binding(
                get: { state.settings.isTabEnabled(.calendar) },
                set: { state.setTabEnabled(.calendar, $0) }
            )
        case .gestures:
            return Binding(
                get: { state.settings.openOnHover },
                set: { state.settings.openOnHover = $0 }
            )
        case .timer:
            return Binding(
                get: { state.settings.isTabEnabled(.timer) },
                set: { state.setTabEnabled(.timer, $0) }
            )
        case .accessories:
            return Binding(
                get: { state.live.isOn(NotchLiveSettings.Event.accessory) },
                set: { state.live.set(.accessory, $0) }
            )
        case .lyrics:
            return Binding(
                get: { state.settings.lyricsEnabled },
                set: { state.settings.lyricsEnabled = $0 }
            )
        case .equalizer:
            return Binding(
                get: { state.live.equalizer },
                set: { state.live.equalizer = $0 }
            )
        case .downloads:
            return Binding(
                get: { state.settings.downloadsEnabled },
                set: { state.setDownloadsEnabled($0) }
            )
        case .agents:
            return Binding(
                get: { state.settings.isTabEnabled(.agents) },
                set: { state.setTabEnabled(.agents, $0) }
            )
        case .notifications, .queue, .watch, .mascot:
            return .constant(false)
        }
    }
}
