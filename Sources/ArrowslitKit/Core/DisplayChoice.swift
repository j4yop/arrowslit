import AppKit
import CoreGraphics

/// Where the notch panel lives.
public enum DisplayChoice: Hashable, Sendable, Identifiable {
    case automatic
    case main
    case followPointer
    case specific(String)
    /// One panel per connected display. Opened content stays on the screen in use.
    case all

    public var id: String { rawValue }

    public var rawValue: String {
        switch self {
        case .automatic: "automatic"
        case .main: "main"
        case .followPointer: "followPointer"
        case .specific(let uuid): "display:" + uuid
        case .all: "all"
        }
    }

    public init?(rawValue: String) {
        switch rawValue {
        case "automatic": self = .automatic
        case "main": self = .main
        case "followPointer": self = .followPointer
        case "all": self = .all
        default:
            guard rawValue.hasPrefix("display:"), rawValue.count > 8 else { return nil }
            self = .specific(String(rawValue.dropFirst(8)))
        }
    }
}

public struct DisplayOption: Identifiable, Sendable {
    public let uuid: String
    public let name: String
    public var id: String { uuid }

    public init(uuid: String, name: String) {
        self.uuid = uuid
        self.name = name
    }

    @MainActor
    public static var connected: [DisplayOption] {
        NSScreen.screens.compactMap { screen in
            guard let uuid = ScreenReader.uuid(for: screen) else { return nil }
            return DisplayOption(uuid: uuid, name: screen.localizedName)
        }
    }
}
