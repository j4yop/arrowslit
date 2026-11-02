// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit

struct NotchNotificationContent: Equatable, Sendable {
    let app: String
    let title: String
    let subtitle: String
    let body: String

    var compactTitle: String { title.isEmpty ? app : title }

    var compactDetail: String {
        [subtitle, body].filter { !$0.isEmpty }.joined(separator: " · ")
    }

    var accessibilityText: String {
        [app, title, subtitle, body].filter { !$0.isEmpty }.joined(separator: ", ")
    }
}

struct NotchSystemNotification: Equatable, Identifiable, Sendable {
    let id: UUID
    let content: NotchNotificationContent
    let received: Date
    var canOpen: Bool
}

struct NotchNotificationInbox {
    private(set) var items: [NotchSystemNotification] = []
    private var seen = Set<UUID>()
    private var primed = false

    mutating func update(_ live: [NotchSystemNotification]) -> [NotchSystemNotification] {
        let byID = Dictionary(live.map { ($0.id, $0) }, uniquingKeysWith: { _, latest in latest })
        items = items.map { item in
            if let current = byID[item.id] { return current }
            var expired = item; expired.canOpen = false
            return expired
        }
        var arrivals: [NotchSystemNotification] = []
        for item in live where seen.insert(item.id).inserted {
            guard primed else { continue }
            items.insert(item, at: 0)
            if items.count > NotchNotificationSupport.maximumItems { items.removeLast() }
            arrivals.append(item)
        }
        primed = true
        if seen.count > 200 { seen = Set(items.map(\.id) + live.map(\.id)) }
        return arrivals
    }

    mutating func dismiss(_ id: UUID) { items.removeAll { $0.id == id } }

    /// Banners still on screen stay seen, so the next layout pass cannot
    /// bring back what was just cleared; later arrivals are mirrored as usual.
    mutating func clear() { items.removeAll() }
}

/// Only labelled notification text belongs in the mirror. Controls, widgets
/// and editable native fields never become message content.
enum NotchNotificationSupport {
    struct Text: Equatable {
        let identifier: String
        let value: String
    }

    static let bannerRoles: Set<String> = ["AXNotificationCenterAlert", "AXNotificationCenterBanner"]
    static let stackRoles: Set<String> = ["AXNotificationCenterAlertStack", "AXNotificationCenterBannerStack"]
    static let maximumItems = 50
    /// A brief grace avoids cutting off short alert tones when closing the
    /// original banner. This does not observe playback; longer sounds may stop.
    static let nativeCloseGrace: TimeInterval = 1.2
    /// Moving the window that holds a banner was measured on macOS 27, where
    /// the center keeps its banners in one window it places again each time
    /// it shows one. Earlier versions close the original after the grace.
    static var movesNativeWindow: Bool {
        if #available(macOS 27, *) { return true }
        return false
    }

    /// Resolve only an unambiguous installed source. Formatting marks used by
    /// localized app labels are not part of the application's name.
    static func sourceBundleIdentifier(for names: [String],
                                       applications: [(name: String, bundleIdentifier: String)]) -> String? {
        func label(_ value: String) -> String {
            let scalars = value.unicodeScalars.filter {
                ![0x061C, 0x200E, 0x200F, 0x202A, 0x202B, 0x202C, 0x202D, 0x202E, 0x2066, 0x2067, 0x2068, 0x2069].contains($0.value)
            }
            return String(String.UnicodeScalarView(scalars)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        let names = names.filter { $0.utf8.count <= 256 }.map(label).filter { !$0.isEmpty }
        let matches = Set(applications.filter { app in
            names.contains { label(app.name).compare($0, options: .caseInsensitive) == .orderedSame }
        }.map(\.bundleIdentifier))
        return matches.count == 1 ? matches.first : nil
    }

    /// Many messages arrive while their app is closed, so installed apps can
    /// name a source too. A running match wins; otherwise the name must stay
    /// unambiguous across both lists.
    static func sourceBundleIdentifier(for names: [String],
                                       running: [(name: String, bundleIdentifier: String)],
                                       installed: [(name: String, bundleIdentifier: String)]) -> String? {
        sourceBundleIdentifier(for: names, applications: running)
            ?? sourceBundleIdentifier(for: names, applications: running + installed)
    }

    /// Native formatted descriptions include the app before the same labelled
    /// message fields. Remove that exact suffix rather than splitting names or
    /// message text at commas, which may be part of their content.
    static func applicationLabel(from description: String, content: NotchNotificationContent) -> String? {
        let suffix = ", " + [content.title, content.subtitle, content.body].filter { !$0.isEmpty }.joined(separator: ", ")
        guard description.utf8.count <= 50_000, description.hasSuffix(suffix) else { return nil }
        let source = String(description.dropLast(suffix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
        return source.isEmpty || source.utf8.count > 256 ? nil : source
    }

    static func dismissesNative(in defaults: UserDefaults = .standard) -> Bool {
        isEnabled(in: defaults) && defaults.bool(forKey: DefaultsKey.notchDismissNativeNotifications)
    }

    static func closeAction(in actions: [String], title: String) -> String? {
        guard !title.isEmpty else { return nil }
        let matches = actions.filter { $0.components(separatedBy: "\n").first == "Name:" + title }
        return matches.count == 1 ? matches.first : nil
    }

    static func isEnabled(in defaults: UserDefaults = .standard) -> Bool {
        defaults.object(forKey: DefaultsKey.notchNotificationsEnabled) as? Bool ?? true
    }

    static func content(from texts: [Text]) -> NotchNotificationContent? {
        func values(_ identifier: String) -> [String] {
            texts.filter { $0.identifier == identifier }.map { $0.value.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        }
        let headers = values("header"), titles = values("title"), bodies = values("body")
        let subtitles = values("subtitle")
        if texts.allSatisfy({ $0.identifier.isEmpty }), (2...3).contains(texts.count),
           texts.allSatisfy({ !$0.value.isEmpty && $0.value.utf8.count <= 16_384 }) {
            return NotchNotificationContent(app: "", title: texts[0].value,
                                            subtitle: texts.count == 3 ? texts[1].value : "",
                                            body: texts[texts.count - 1].value)
        }
        // Multiple messages in a stack must never be flattened into one sender.
        guard headers.count <= 1, titles.count == 1, bodies.count <= 1, subtitles.count <= 1,
              texts.allSatisfy({ $0.value.utf8.count <= 16_384 }) else { return nil }
        return NotchNotificationContent(app: headers.first ?? "", title: titles[0],
                                        subtitle: subtitles.first ?? "", body: bodies.first ?? "")
    }

    /// Structural view markers are not durable message identities. Opening
    /// still requires the unchanged native target and notification content.
    static func nativeIdentity(_ identifier: String?) -> String? {
        guard let identifier, identifier.utf8.count <= 2_048,
              identifier.range(of: "[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}",
                               options: .regularExpression) != nil else { return nil }
        return identifier
    }
}

/// Installed-app lookup for notification source attribution. The list is
/// cached by `NotchNotificationSources` and only walked every ten minutes.
enum ArrowslitNotificationApps {
    static func installed() -> [(name: String, bundleIdentifier: String)] {
        let roots = [
            URL(fileURLWithPath: "/Applications"),
            URL(fileURLWithPath: "/System/Applications"),
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications"),
        ]
        var seen = Set<String>()
        var result: [(String, String)] = []
        for root in roots {
            let apps = (try? FileManager.default.contentsOfDirectory(
                at: root,
                includingPropertiesForKeys: [.isApplicationKey],
                options: [.skipsHiddenFiles]
            )) ?? []
            for app in apps where app.pathExtension.lowercased() == "app" {
                let plist = app.appendingPathComponent("Contents/Info.plist")
                guard let data = try? Data(contentsOf: plist),
                      let object = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
                      let identifier = object["CFBundleIdentifier"] as? String,
                      seen.insert(identifier).inserted else { continue }
                let name = (object["CFBundleDisplayName"] as? String)
                    ?? (object["CFBundleName"] as? String)
                    ?? app.deletingPathExtension().lastPathComponent
                result.append((name, identifier))
            }
        }
        return result
    }
}
