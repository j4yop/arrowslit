import AppKit
import ApplicationServices

/// The Settings button asks macOS for Accessibility trust. The actual window-drag handoff
/// still requires the source app to expose its saved document location.
public enum DocumentWindowDrag {
    @MainActor
    public static func requestAccess() {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }
}
