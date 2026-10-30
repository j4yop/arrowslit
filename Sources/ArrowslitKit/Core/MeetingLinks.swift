import Foundation

/// Finds the first supported video-call link in an event's URL, location or notes.
public enum MeetingLinks {
    public enum Provider: String, CaseIterable, Sendable, Equatable {
        case meet = "Meet"
        case zoom = "Zoom"
        case teams = "Teams"
        case webex = "Webex"

        public var displayName: String { rawValue }
    }

    public struct Link: Equatable, Sendable {
        public var url: URL
        public var provider: Provider

        public init(url: URL, provider: Provider) {
            self.url = url
            self.provider = provider
        }
    }

    public static func joinLink(in texts: [String?]) -> Link? {
        for text in texts.compactMap({ $0 }) where !text.isEmpty {
            for url in links(in: text) {
                if let provider = provider(for: url) {
                    return Link(url: url, provider: provider)
                }
            }
        }
        return nil
    }

    public static func provider(for url: URL) -> Provider? {
        guard let scheme = url.scheme?.lowercased(), scheme == "https" || scheme == "http",
              let host = url.host?.lowercased() else { return nil }
        let path = url.path.lowercased()

        if host == "meet.google.com", path.count > 1 {
            return .meet
        }
        if host == "zoom.us" || host.hasSuffix(".zoom.us") {
            return path.hasPrefix("/j/") || path.hasPrefix("/my/") || path.hasPrefix("/w/") ? .zoom : nil
        }
        if host == "teams.microsoft.com" || host == "teams.live.com" {
            return path.contains("meetup-join") || path.hasPrefix("/meet") || path.hasPrefix("/l/meet") ? .teams : nil
        }
        if host.hasSuffix(".webex.com"), path.count > 1 {
            return .webex
        }
        return nil
    }

    private static func links(in text: String) -> [URL] {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else {
            return []
        }
        let range = NSRange(text.startIndex..., in: text)
        return detector.matches(in: text, range: range).compactMap(\.url)
    }
}
