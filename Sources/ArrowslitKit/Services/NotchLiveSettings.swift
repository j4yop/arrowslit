import Foundation
import Observation

/// The closed notch's live catalogue: the feedback events it can flash and
/// the activities it can keep beside the camera.
///
/// Vorssaint exposes 15 feedback events and 7 live activities. Arrowslit
/// keeps the same names and defaults where it has a source for them; rows
/// without a macOS surface are marked unavailable instead of pretending to
/// work.
@MainActor
@Observable
public final class NotchLiveSettings {
    public enum Event: String, CaseIterable, Identifiable, Sendable {
        case volume, brightness, keyboardLight, microphone, inputSource
        case battery, accessory, systemNotification, clipboard, capture
        case download, agents, track, timer, watch

        public var id: String { rawValue }
    }

    public enum Strip: String, CaseIterable, Identifiable, Sendable {
        case timer, watch, download, agents, calendar, music, keepAwake

        public var id: String { rawValue }
    }

    private var values: [String: Bool]
    @ObservationIgnored private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        var initial: [String: Bool] = [:]
        for event in Event.allCases {
            if let saved = defaults.object(forKey: Self.key(event)) as? Bool {
                initial[Self.key(event)] = saved
            } else {
                initial[Self.key(event)] = Self.legacyDefault(event, defaults: defaults)
                    ?? Self.eventDefault(event)
            }
        }
        for strip in Strip.allCases {
            initial[Self.key(strip)] = defaults.object(forKey: Self.key(strip)) as? Bool
                ?? Self.stripDefault(strip)
        }
        initial[Self.key("equalizer")] = defaults.object(forKey: Self.key("equalizer")) as? Bool ?? true
        values = initial
    }

    // MARK: Events

    public func isOn(_ event: Event) -> Bool {
        isAvailable(event) && (values[Self.key(event)] ?? false)
    }

    public func set(_ event: Event, _ on: Bool) {
        guard isAvailable(event) else { return }
        values[Self.key(event)] = on
        defaults.set(on, forKey: Self.key(event))
    }

    /// Rows without a source are visible in Settings, disabled and explained.
    public func isAvailable(_ event: Event) -> Bool {
        switch event {
        case .volume, .brightness, .microphone, .inputSource, .battery, .accessory,
             .clipboard, .download, .agents, .track, .timer:
            return true
        case .keyboardLight, .systemNotification, .capture, .watch:
            return false
        }
    }

    /// Arrowslit shipped one switch for volume and brightness, one for
    /// charging and one for headphones. Carry those choices into the new rows.
    private static func legacyDefault(_ event: Event, defaults: UserDefaults) -> Bool? {
        switch event {
        case .volume, .brightness:
            return defaults.object(forKey: "arrowslit.alertVolumeBrightness") as? Bool
        case .battery:
            return (defaults.object(forKey: "arrowslit.alertCharging") as? Bool)
                ?? (defaults.object(forKey: "arrowslit.alertLowBattery") as? Bool)
        case .accessory:
            return defaults.object(forKey: "arrowslit.alertHeadphones") as? Bool
        default:
            return nil
        }
    }

    private static func eventDefault(_ event: Event) -> Bool {
        switch event {
        case .keyboardLight, .systemNotification, .capture, .watch:
            return false
        default:
            return true
        }
    }

    // MARK: Strips

    public func isOn(_ strip: Strip) -> Bool {
        values[Self.key(strip)] ?? false
    }

    public func set(_ strip: Strip, _ on: Bool) {
        guard isAvailable(strip) else { return }
        values[Self.key(strip)] = on
        defaults.set(on, forKey: Self.key(strip))
    }

    public func isAvailable(_ strip: Strip) -> Bool {
        strip != .watch
    }

    private static func stripDefault(_ strip: Strip) -> Bool {
        strip != .watch
    }

    /// Whether a closed-notch activity still has a strip after the person's
    /// choices. Expanded pages keep working even when their strip is off.
    public func showsStrip(_ activity: NotchActivity) -> Bool {
        switch activity {
        case .timer: return isOn(Strip.timer)
        case .download: return isOn(Strip.download)
        case .agents: return isOn(Strip.agents)
        case .calendar: return isOn(Strip.calendar)
        case .nowPlaying: return isOn(Strip.music)
        case .keepAwake: return isOn(Strip.keepAwake)
        case .watch: return isOn(Strip.watch)
        case .call, .stopwatch, .sports, .charging, .stats: return true
        }
    }

    // MARK: Music extras

    public var equalizer: Bool {
        get { values[Self.key("equalizer")] ?? true }
        set {
            values[Self.key("equalizer")] = newValue
            defaults.set(newValue, forKey: Self.key("equalizer"))
        }
    }

    // MARK: Keys

    private static func key(_ event: Event) -> String { "arrowslit.live.event.\(event.rawValue)" }
    private static func key(_ strip: Strip) -> String { "arrowslit.live.strip.\(strip.rawValue)" }
    private static func key(_ name: String) -> String { "arrowslit.live.\(name)" }
}
