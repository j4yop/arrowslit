import AppKit
import Foundation
import Observation

/// Switches macOS between light and dark appearance. The change goes through System Events so
/// every app, the menu bar and the desktop follow, exactly like the appearance tile in Droppy.
@MainActor
@Observable
public final class AppearanceService {
    public private(set) var isDark: Bool
    public private(set) var errorMessage: String?

    @ObservationIgnored private var themeObserver: NSObjectProtocol?
    @ObservationIgnored private var activeObserver: NSObjectProtocol?

    public init() {
        isDark = Self.systemIsDark
        observe()
    }

    public func toggle() {
        setDark(!isDark)
    }

    public func setDark(_ value: Bool) {
        let script = """
        tell application "System Events"
            tell appearance preferences
                set dark mode to \(value ? "true" : "false")
            end tell
        end tell
        """
        var error: NSDictionary?
        NSAppleScript(source: script)?.executeAndReturnError(&error)
        if let error {
            errorMessage = (error[NSAppleScript.errorMessage] as? String)
                ?? "macOS did not allow Arrowslit to change the appearance."
            refresh()
        } else {
            errorMessage = nil
            isDark = value
        }
    }

    public func clearError() {
        errorMessage = nil
    }

    public func refresh() {
        isDark = Self.systemIsDark
    }

    private func observe() {
        themeObserver = DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("AppleInterfaceThemeChangedNotification"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in self?.refresh() }
        }
        activeObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in self?.refresh() }
        }
    }

    private static var systemIsDark: Bool {
        if let style = UserDefaults.standard.string(forKey: "AppleInterfaceStyle") {
            return style.caseInsensitiveCompare("Dark") == .orderedSame
        }
        return NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    }
}
