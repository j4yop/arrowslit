import SwiftUI

/// The sixteen pages Vorssaint puts inside its Dynamic Island. They are
/// presented inside Arrowslit's existing launcher surface, so the rest of the
/// app keeps its own tab model and keyboard shortcuts.
public enum VorssaintPage: String, CaseIterable, Identifiable {
    case controls
    case mixer
    case music
    case clipboard
    case captures
    case files
    case system
    case tools
    case calendar
    case notifications
    case timer
    case camera
    case downloads
    case scratchpad
    case agents
    case watch

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .controls: "Controls"
        case .mixer: "Volume mixer"
        case .music: "Now Playing"
        case .clipboard: "Clipboard"
        case .captures: "Recent captures"
        case .files: "Files"
        case .system: "System"
        case .tools: "Tools"
        case .calendar: "Calendar"
        case .notifications: "Notifications"
        case .timer: "Timer"
        case .camera: "Camera mirror"
        case .downloads: "Downloads"
        case .scratchpad: "Scratchpad"
        case .agents: "AI Agents"
        case .watch: "Watch"
        }
    }

    public var symbol: String {
        switch self {
        case .controls: "slider.horizontal.3"
        case .mixer: "speaker.wave.2"
        case .music: "music.note"
        case .clipboard: "doc.on.clipboard"
        case .captures: "camera.viewfinder"
        case .files: "tray.full"
        case .system: "gauge.with.dots.needle.50percent"
        case .tools: "square.grid.2x2"
        case .calendar: "calendar"
        case .notifications: "bell"
        case .timer: "timer"
        case .camera: "web.camera"
        case .downloads: "arrow.down.circle"
        case .scratchpad: "note.text"
        case .agents: "sparkles"
        case .watch: "eye"
        }
    }

    /// The keyboard hint shown under the tile. These match Vorssaint's
    /// physical-key choices, so the grid reads the same.
    public var shortcutKey: String {
        switch self {
        case .controls: "C"
        case .mixer: "V"
        case .music: "M"
        case .clipboard: "B"
        case .captures: "S"
        case .files: "F"
        case .system: "I"
        case .tools: "T"
        case .calendar: "A"
        case .notifications: "N"
        case .timer: "R"
        case .camera: "W"
        case .downloads: "D"
        case .scratchpad: "P"
        case .agents: "G"
        case .watch: "O"
        }
    }

    public var shortcutLabel: String { "⌥⌘\(shortcutKey)" }

    public var accent: Color {
        switch self {
        case .music: Color(red: 1, green: 0.27, blue: 0.4)
        case .timer: ArrowTheme.amber
        case .calendar: ArrowTheme.red
        case .agents: Color(red: 0.78, green: 0.66, blue: 1)
        case .watch: ArrowTheme.green
        default: .white
        }
    }

    /// Existing Arrowslit panes that this page can reuse directly.
    var workbenchTab: WorkbenchTab? {
        switch self {
        case .music: .nowPlaying
        case .clipboard: .clipboard
        case .files: .tray
        case .system: .stats
        case .calendar: .calendar
        case .timer: .timer
        case .camera: .mirror
        case .downloads: .download
        case .scratchpad: .notes
        default: nil
        }
    }

    /// The two rows in the recording, in order.
    static var exploreOrder: [VorssaintPage] { [
        .controls, .mixer, .music, .clipboard, .captures,
        .files, .system, .tools, .calendar, .notifications,
        .timer, .camera, .downloads, .scratchpad, .agents, .watch
    ] }

    /// Arrowslit-only pages kept reachable from the third Explore page.
    static var arrowslitExtras: [(title: String, symbol: String, shortcut: String, tab: WorkbenchTab)] { [
        ("Sports", "soccerball", "⌃⌥F", .sports),
        ("Reminders", "checklist", "⌃⌥O", .reminders),
        ("Stopwatch", "stopwatch", "⌃⌥S", .stopwatch),
        ("Keep Awake", "cup.and.saucer", "⌃⌥Z", .keepAwake),
        ("Call", "phone", "", .call),
        ("Home", "house", "⌃⌥H", .home)
    ] }
}
