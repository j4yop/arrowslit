import Testing
@testable import ArrowslitKit

@Suite("Media app filter")
struct MediaAppFilterTests {
    @Test func allAppsAllowsEverything() {
        #expect(MediaAppFilter.all.allows("com.spotify.client"))
        #expect(MediaAppFilter.all.allows(nil))
    }

    @Test func chosenAppsNeedAnAllowedIdentifier() {
        let filter = MediaAppFilter(mode: .chosen, allowed: ["com.spotify.client"])
        #expect(filter.allows("com.spotify.client"))
        #expect(!filter.allows("com.apple.Music"))
        #expect(!filter.allows(nil))
    }

    @Test func recentAppsDeduplicateAndKeepNewestFirst() {
        var recent = RecentMediaApps()
        let first = recent.note("com.spotify.client")
        let second = recent.note("com.apple.Music")
        let third = recent.note("com.spotify.client")
        #expect(first)
        #expect(second)
        #expect(!third)
        #expect(recent.identifiers == ["com.apple.Music", "com.spotify.client"])
    }

    @Test func recentAppsAreCapped() {
        var recent = RecentMediaApps()
        for index in 0..<(RecentMediaApps.limit + 4) {
            _ = recent.note("app.\(index)")
        }
        #expect(recent.identifiers.count == RecentMediaApps.limit)
        #expect(recent.identifiers.first == "app.15")
    }
}

@Suite("Media linger")
@MainActor
struct MediaLingerTests {
    @Test func pausedMediaLingersThenDisappears() async {
        let service = NowPlayingService()
        service.lingerDuration = 0.1
        service.showDemo(
            title: "Blinding Lights",
            artist: "The Weeknd",
            album: "After Hours",
            artwork: nil,
            accent: .white,
            duration: 202,
            elapsed: 4
        )
        #expect(service.isVisible)

        service.toggle()
        #expect(service.isLingering)
        #expect(service.isVisible)

        try? await Task.sleep(for: .milliseconds(500))
        #expect(!service.isLingering)
    }
}
