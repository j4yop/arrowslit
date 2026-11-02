import Foundation

/// Recognises the apps that make calls, and the system processes that should never show up as
/// microphone activity.
public enum CallClassifier {
    public static let callApps: Set<String> = [
        "com.apple.FaceTime",
        "com.apple.mobilephone",
        "us.zoom.xos",
        "com.microsoft.teams",
        "com.microsoft.teams2",
        "com.cisco.webexmeetingsapp",
        "Cisco-Systems.Spark",
        "com.tinyspeck.slackmacgap",
        "com.hnc.Discord",
        "net.whatsapp.WhatsApp",
        "desktop.WhatsApp",
        "ru.keepcoder.Telegram",
        "org.telegram.desktop",
        "com.skype.skype",
        "com.microsoft.SkypeForBusiness",
        "com.ringcentral.glip",
        "com.google.Chrome.app.kjgfgldnnfoeklkmfkjfagphfepbbdan",
        "com.signal.Signal",
        "org.whispersystems.signal-desktop",
    ]

    private static let ignoredPrefixes: [String] = [
        "com.apple.SpeechRecognitionCore",
        "com.apple.speech",
        "com.apple.corespeech",
        "com.apple.CoreSpeech",
        "com.apple.assistant",
        "com.apple.Siri",
        "com.apple.siri",
        "com.apple.dictation",
        "com.apple.DictationIM",
        "com.apple.accessibility",
        "com.apple.controlcenter",
        "com.apple.audio",
        "com.apple.coreaudiod",
        "com.apple.systemsoundserverd",
        "com.apple.SoundAnalysis",
        "com.apple.mediaanalysisd",
        "com.apple.universalaccess",
    ]

    public static func isCallApp(_ bundleIdentifier: String?) -> Bool {
        guard let bundleIdentifier else { return false }
        return callApps.contains(bundleIdentifier)
    }

    public static func shouldIgnore(_ bundleIdentifier: String?) -> Bool {
        guard let bundleIdentifier, !bundleIdentifier.isEmpty else { return false }
        return ignoredPrefixes.contains { bundleIdentifier.hasPrefix($0) }
    }

    public static func appBundleIdentifier(forHelper bundleIdentifier: String) -> String {
        let suffixes = [".helper.Renderer", ".helper.GPU", ".helper.Plugin", ".helper.Alerts", ".helper"]
        for suffix in suffixes where bundleIdentifier.hasSuffix(suffix) {
            return String(bundleIdentifier.dropLast(suffix.count))
        }
        return bundleIdentifier
    }
}
