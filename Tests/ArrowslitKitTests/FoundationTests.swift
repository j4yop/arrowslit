import Foundation
import Testing
@testable import ArrowslitKit

private let base = Date(timeIntervalSince1970: 1_000_000)

private func event(
    _ title: String = "Design review",
    startsIn minutes: Double = 5,
    joinURL: URL? = nil,
    provider: MeetingLinks.Provider? = nil
) -> NotchAlert {
    .upcomingEvent(
        title: title,
        startsAt: base.addingTimeInterval(minutes * 60),
        joinURL: joinURL,
        provider: provider
    )
}

@Suite("Alert queue")
struct AlertQueueTests {
    @Test func presentsTheFirstWaitingAlertOnlyWhenAsked() {
        var queue = AlertQueue()
        queue.enqueue(.charging(level: 80, isCharging: true), now: base)

        #expect(queue.current == nil)
        let presented = queue.present(now: base, allowNonUrgent: true)
        #expect(presented)
        #expect(queue.current == .charging(level: 80, isCharging: true))
        #expect(queue.pending.isEmpty)
    }

    @Test func sameKindReplacesInsteadOfStacking() {
        var queue = AlertQueue()
        queue.enqueue(.lowBattery(level: 20), now: base)
        queue.enqueue(.lowBattery(level: 10), now: base.addingTimeInterval(1))
        queue.present(now: base.addingTimeInterval(2), allowNonUrgent: true)

        #expect(queue.current == .lowBattery(level: 10))
        #expect(queue.pending.isEmpty)
    }

    @Test func urgentAlertInterruptsAndTheOtherComesBack() {
        var queue = AlertQueue()
        queue.enqueue(.charging(level: 80, isCharging: true), now: base)
        queue.present(now: base, allowNonUrgent: true)

        queue.enqueue(.timerFinished, now: base.addingTimeInterval(1))
        #expect(queue.current == .timerFinished)
        #expect(queue.pending == [.charging(level: 80, isCharging: true)])

        queue.dismissCurrent()
        queue.present(now: base.addingTimeInterval(2), allowNonUrgent: true)
        #expect(queue.current == .charging(level: 80, isCharging: true))
    }

    @Test func urgentAlertJumpsAheadOfAnEarlierWaitingAlert() {
        var queue = AlertQueue()
        queue.enqueue(.charging(level: 80, isCharging: true), now: base)
        queue.enqueue(.timerFinished, now: base.addingTimeInterval(1))

        queue.present(now: base.addingTimeInterval(2), allowNonUrgent: true)
        #expect(queue.current == .timerFinished)
        #expect(queue.pending == [.charging(level: 80, isCharging: true)])
    }

    @Test func nonUrgentAlertWaitsWhileAnExpandedViewIsOpen() {
        var queue = AlertQueue()
        queue.enqueue(event(), now: base)

        let hiddenWhileExpanded = !queue.present(now: base, allowNonUrgent: false)
        #expect(hiddenWhileExpanded)
        #expect(queue.current == nil)
        let shownAfterCollapse = queue.present(now: base.addingTimeInterval(1), allowNonUrgent: true)
        #expect(shownAfterCollapse)
        #expect(queue.current == event())
    }

    @Test func expiryUsesTheAlertDuration() {
        var queue = AlertQueue()
        queue.enqueue(event(), now: base)
        queue.present(now: base, allowNonUrgent: true)

        #expect(queue.expiry == base.addingTimeInterval(8))
        let expiredEarly = queue.expire(now: base.addingTimeInterval(7))
        #expect(!expiredEarly)
        let expired = queue.expire(now: base.addingTimeInterval(9))
        #expect(expired)
        #expect(queue.current == nil)
    }

    @Test func instantLevelAlertIsDroppedRatherThanReplayedAfterAnUrgentOne() {
        var queue = AlertQueue()
        queue.enqueue(.timerFinished, now: base)
        queue.present(now: base, allowNonUrgent: true)
        queue.enqueue(.level(kind: .volume, value: 0.4, muted: false), now: base.addingTimeInterval(1))

        #expect(queue.pending.isEmpty)
        #expect(queue.current == .timerFinished)
    }
}

@Suite("Power alerts")
struct PowerAlertRulesTests {
    private let battery80 = PowerSnapshot(level: 80, isCharging: false, isOnAC: false)

    @Test func firstReadingIsOnlyABaseline() {
        var rules = PowerAlertRules()
        let alerts = rules.observe(battery80, chargingAlerts: true, lowBatteryAlerts: true)
        #expect(alerts.isEmpty)
    }

    @Test func pluggingInAnnouncesChargingOnce() {
        var rules = PowerAlertRules()
        _ = rules.observe(battery80, chargingAlerts: true, lowBatteryAlerts: true)

        let pluggedIn = PowerSnapshot(level: 80, isCharging: true, isOnAC: true)
        #expect(rules.observe(pluggedIn, chargingAlerts: true, lowBatteryAlerts: true) == [
            .charging(level: 80, isCharging: true)
        ])
        #expect(rules.observe(pluggedIn, chargingAlerts: true, lowBatteryAlerts: true).isEmpty)
    }

    @Test func startingToChargeWhilePluggedInAnnouncesOnce() {
        var rules = PowerAlertRules()
        _ = rules.observe(
            PowerSnapshot(level: 80, isCharging: false, isOnAC: true),
            chargingAlerts: true,
            lowBatteryAlerts: true
        )

        let charging = PowerSnapshot(level: 80, isCharging: true, isOnAC: true)
        #expect(rules.observe(charging, chargingAlerts: true, lowBatteryAlerts: true) == [
            .charging(level: 80, isCharging: true)
        ])
        #expect(rules.observe(charging, chargingAlerts: true, lowBatteryAlerts: true).isEmpty)
    }

    @Test func lowBatteryFiresAtTwentyAndTenOnlyOnce() {
        var rules = PowerAlertRules()
        _ = rules.observe(PowerSnapshot(level: 21, isCharging: false, isOnAC: false), chargingAlerts: true, lowBatteryAlerts: true)

        #expect(rules.observe(PowerSnapshot(level: 19, isCharging: false, isOnAC: false), chargingAlerts: true, lowBatteryAlerts: true) == [
            .lowBattery(level: 19)
        ])
        #expect(rules.observe(PowerSnapshot(level: 18, isCharging: false, isOnAC: false), chargingAlerts: true, lowBatteryAlerts: true).isEmpty)
        #expect(rules.observe(PowerSnapshot(level: 9, isCharging: false, isOnAC: false), chargingAlerts: true, lowBatteryAlerts: true) == [
            .lowBattery(level: 9)
        ])
        #expect(rules.observe(PowerSnapshot(level: 8, isCharging: false, isOnAC: false), chargingAlerts: true, lowBatteryAlerts: true).isEmpty)
    }

    @Test func chargingRearmsBothWarnings() {
        var rules = PowerAlertRules()
        _ = rules.observe(PowerSnapshot(level: 21, isCharging: false, isOnAC: false), chargingAlerts: true, lowBatteryAlerts: true)
        #expect(rules.observe(PowerSnapshot(level: 19, isCharging: false, isOnAC: false), chargingAlerts: true, lowBatteryAlerts: true) == [
            .lowBattery(level: 19)
        ])
        _ = rules.observe(PowerSnapshot(level: 80, isCharging: true, isOnAC: true), chargingAlerts: true, lowBatteryAlerts: true)
        _ = rules.observe(PowerSnapshot(level: 21, isCharging: false, isOnAC: false), chargingAlerts: true, lowBatteryAlerts: true)

        #expect(rules.observe(PowerSnapshot(level: 19, isCharging: false, isOnAC: false), chargingAlerts: true, lowBatteryAlerts: true) == [
            .lowBattery(level: 19)
        ])
    }

    @Test func disabledWarningsStayQuiet() {
        var rules = PowerAlertRules()
        _ = rules.observe(battery80, chargingAlerts: false, lowBatteryAlerts: false)
        #expect(rules.observe(
            PowerSnapshot(level: 80, isCharging: true, isOnAC: true),
            chargingAlerts: false,
            lowBatteryAlerts: false
        ).isEmpty)
    }
}

@Suite("Presentation resolver")
struct PresentationResolverTests {
    @Test func compactUsesActivityPriority() {
        let presentation = PresentationResolver.resolve(PresentationInput(
            isExpanded: false,
            activeTab: .home,
            activeActivities: [.timer, .nowPlaying, .call]
        ))

        #expect(presentation == .compact(primary: .call, secondary: .timer))
    }

    @Test func chargingSitsBehindMediaAndAheadOfStats() {
        let presentation = PresentationResolver.resolve(PresentationInput(
            isExpanded: false,
            activeTab: .home,
            activeActivities: [.stats, .charging, .nowPlaying]
        ))

        #expect(presentation == .compact(primary: .nowPlaying, secondary: .charging))
    }

    @Test func expandedWorkspaceWinsOverANonUrgentAlert() {
        let presentation = PresentationResolver.resolve(PresentationInput(
            isExpanded: true,
            activeTab: .calendar,
            alert: event()
        ))

        #expect(presentation == .expanded(.calendar))
    }

    @Test func urgentAlertWinsOverAnExpandedWorkspace() {
        let presentation = PresentationResolver.resolve(PresentationInput(
            isExpanded: true,
            activeTab: .calendar,
            alert: .timerFinished
        ))

        #expect(presentation == .alert(.timerFinished))
    }

    @Test func alertWinsWhenTheNotchIsClosed() {
        let presentation = PresentationResolver.resolve(PresentationInput(
            isExpanded: false,
            activeTab: .home,
            alert: event()
        ))

        #expect(presentation == .alert(event()))
    }

    @Test func systemAlertsUseTheCompactHUD() {
        let alert = NotchAlert.level(kind: .volume, value: 0.4, muted: false)
        let presentation = PresentationResolver.resolve(PresentationInput(
            isExpanded: false,
            activeTab: .home,
            alert: alert
        ))

        #expect(presentation == .hud(alert))
        #expect(presentation.hudAlert == alert)
    }

    @Test func systemHUDWaitsWhileTheWorkbenchIsOpen() {
        let presentation = PresentationResolver.resolve(PresentationInput(
            isExpanded: true,
            activeTab: .calendar,
            alert: .lowBattery(level: 20)
        ))

        #expect(presentation == .expanded(.calendar))
    }

    @Test func updatePromptStaysLongEnoughToAct() {
        #expect(NotchAlert.update(version: "0.5.2").displayDuration == 10)
    }

    @Test func calendarAlertsKeepTheLargerPanel() {
        #expect(!event().usesCompactHUD)
        #expect(!NotchAlert.timerFinished.usesCompactHUD)
        #expect(!NotchAlert.update(version: "0.5.1").usesCompactHUD)
        #expect(NotchAlert.charging(level: 80, isCharging: true).usesCompactHUD)
        #expect(NotchAlert.lowBattery(level: 20).usesCompactHUD)
        #expect(NotchAlert.headphones(name: "AirPods Pro").usesCompactHUD)
        #expect(NotchAlert.level(kind: .volume, value: 0.5, muted: false).usesCompactHUD)
    }

    @Test func compactCanBeEmpty() {
        let presentation = PresentationResolver.resolve(PresentationInput(isExpanded: false, activeTab: .home))

        #expect(presentation == .compact(primary: nil, secondary: nil))
    }
}

@Suite("Meeting links")
struct MeetingLinksTests {
    @Test func recognisesSupportedProviders() {
        #expect(MeetingLinks.provider(for: URL(string: "https://meet.google.com/abc-defg-hij")!) == .meet)
        #expect(MeetingLinks.provider(for: URL(string: "https://acme.zoom.us/j/123456")!) == .zoom)
        #expect(MeetingLinks.provider(for: URL(string: "https://teams.microsoft.com/l/meetup-join/19%3ameeting")!) == .teams)
        #expect(MeetingLinks.provider(for: URL(string: "https://acme.webex.com/meet/jay")!) == .webex)
        #expect(MeetingLinks.provider(for: URL(string: "https://example.com/meeting")!) == nil)
    }

    @Test func findsTheFirstSupportedLinkInEventText() {
        let link = MeetingLinks.joinLink(in: [
            nil,
            "Join here: https://acme.zoom.us/j/123456",
            "Notes https://meet.google.com/abc-defg-hij",
        ])

        #expect(link?.provider == .zoom)
        #expect(link?.url.absoluteString == "https://acme.zoom.us/j/123456")
    }

    @Test func ignoresLookalikeHostsAndEmptyPaths() {
        #expect(MeetingLinks.joinLink(in: ["https://example.com/meet.google.com/abc"]) == nil)
        #expect(MeetingLinks.joinLink(in: ["https://meet.google.com"]) == nil)
        #expect(MeetingLinks.joinLink(in: ["https://acme.zoom.us/about"]) == nil)
    }
}

@Suite("Calendar rules")
struct CalendarRulesTests {
    private func calendarEvent(
        _ title: String,
        startsIn minutes: Double,
        allDay: Bool = false
    ) -> CalendarEvent {
        let start = base.addingTimeInterval(minutes * 60)
        return CalendarEvent(
            id: "\(title)-\(minutes)",
            title: title,
            start: start,
            end: start.addingTimeInterval(30 * 60),
            isAllDay: allDay
        )
    }

    @Test func nextEventSkipsAllDayAndFinishedEvents() {
        let events = [
            calendarEvent("All day", startsIn: 10, allDay: true),
            calendarEvent("Finished", startsIn: -60),
            calendarEvent("Next", startsIn: 35),
        ]

        #expect(CalendarRules.nextEvent(in: events, at: base)?.title == "Next")
    }

    @Test func reminderIsFiveMinutesBeforeAndOnlyOnce() {
        let next = calendarEvent("Design review", startsIn: 20)
        let reminder = CalendarRules.nextReminder(in: [next], after: base, reminded: [])

        #expect(reminder?.event.id == next.id)
        #expect(reminder?.at == next.start.addingTimeInterval(-300))
        #expect(CalendarRules.nextReminder(in: [next], after: base, reminded: [next.id]) == nil)
    }

    @Test func eventAlreadyInsideTheLeadWindowRemindsNow() {
        let next = calendarEvent("Stand-up", startsIn: 2)
        let reminder = CalendarRules.nextReminder(in: [next], after: base, reminded: [])

        #expect(reminder?.at == base)
    }

    @Test func relativeLabelsReadLikeTheClockApp() {
        #expect(CalendarRules.relativeLabel(for: calendarEvent("Now", startsIn: -1), at: base) == "now")
        #expect(CalendarRules.relativeLabel(for: calendarEvent("Soon", startsIn: 12), at: base) == "in 12 min")
        #expect(CalendarRules.relativeLabel(for: calendarEvent("Later", startsIn: 90), at: base) == "in 1 hr")
    }

    @Test func alertDetailSaysHowSoonTheEventStarts() {
        #expect(CalendarRules.alertDetail(for: calendarEvent("Soon", startsIn: 5), at: base) == "Starts in 5 min")
        #expect(CalendarRules.alertDetail(for: calendarEvent("Now", startsIn: 0.2), at: base) == "Starting now")
    }
}

@Suite("Notch panel metrics")
struct NotchPanelMetricsTests {
    private let geometry = ScreenGeometry(
        size: CGSize(width: 1470, height: 956),
        notch: CGRect(x: 645, y: 0, width: 180, height: 32),
        menuBarHeight: 32
    )

    @Test func compactMatchesTheStrip() {
        let size = NotchPanelMetrics.size(for: .compact(primary: nil, secondary: nil), geometry: geometry)
        #expect(size == CGSize(width: geometry.compactWidth, height: 32))
    }

    @Test func homeUsesTheTallerNudgeBody() {
        let size = NotchPanelMetrics.size(for: .expanded(.home), geometry: geometry)
        #expect(size == CGSize(width: 560, height: 204))
        let other = NotchPanelMetrics.size(for: .expanded(.timer), geometry: geometry)
        #expect(other == CGSize(width: 560, height: 178))
    }

    @Test func alertUsesItsOwnShortPanel() {
        let size = NotchPanelMetrics.size(for: .alert(event()), geometry: geometry)
        #expect(size == CGSize(width: 560, height: 86))
    }

    @Test func systemHUDUsesTheCompactStrip() {
        let size = NotchPanelMetrics.size(
            for: .hud(.level(kind: .brightness, value: 0.5, muted: false)),
            geometry: geometry
        )
        #expect(size == CGSize(width: geometry.compactWidth, height: 32))
    }

    @Test func nowPlayingUsesTheTallPlayerPanel() {
        let size = NotchPanelMetrics.size(for: .expanded(.nowPlaying), geometry: geometry)
        #expect(size == CGSize(width: 390, height: 218))
    }
}

@Suite("Synced lyrics")
struct SyncedLyricsTests {
    @Test func parsesTimedLinesAndIgnoresTags() {
        let lyrics = SyncedLyrics(lrc: """
        [ar:The Weeknd]
        [00:12.50]First line
        [00:20.00][00:40.00]Repeated
        [01:02.25]Last line
        """)

        #expect(lyrics?.lines.count == 4)
        #expect(lyrics?.lines.first?.text == "First line")
        #expect(lyrics?.lines.first?.time == 12.5)
        #expect(lyrics?.lines.last?.time == 62.25)
    }

    @Test func returnsNilForPlainLyrics() {
        #expect(SyncedLyrics(lrc: "Just words\nWithout a time") == nil)
    }

    @Test func findsTheLineAtTheCurrentTime() {
        let lyrics = SyncedLyrics(lrc: "[00:01.00]One\n[00:05.00]Two\n[00:09.00]Three")
        #expect(lyrics?.index(at: 0.5) == nil)
        #expect(lyrics?.index(at: 4.9) == 0)
        #expect(lyrics?.index(at: 5.0) == 1)
        #expect(lyrics?.index(at: 20) == 2)
    }
}

@Suite("Lyrics lookup")
struct LyricsLookupTests {
    @Test func buildsARequestWithOnlySongMetadata() {
        let key = LyricsKey(title: "Blinding Lights", artist: "The Weeknd", album: "After Hours", duration: 200)!
        let url = LyricsLookup.getURL(for: key)
        let items = URLComponents(url: url!, resolvingAgainstBaseURL: false)?.queryItems ?? []

        #expect(url?.host == "lrclib.net")
        #expect(items.contains { $0.name == "track_name" && $0.value == "Blinding Lights" })
        #expect(items.contains { $0.name == "artist_name" && $0.value == "The Weeknd" })
        #expect(items.contains { $0.name == "duration" && $0.value == "200" })
    }

    @Test func rejectsLyricsFromADifferentLength() {
        let key = LyricsKey(title: "Song", artist: "Artist", album: "", duration: 200)!
        let record = LyricsLookup.Record(duration: 260, instrumental: false, syncedLyrics: "[00:01.00]Words")
        #expect(LyricsLookup.lyrics(from: record, for: key) == nil)
    }

    @Test func parsesNetEaseSearchAndPicksTheExactTrack() throws {
        let json = """
        {"result":{"songs":[
          {"id":1424460203,"name":"After Hours","dt":361026,"ar":[{"name":"The Weeknd"}],"al":{"name":"After Hours"}},
          {"id":2027161334,"name":"After Hours (Live)","dt":267912,"ar":[{"name":"The Weeknd"}],"al":{"name":"Live"}}
        ]}}
        """
        let search = try JSONDecoder().decode(LyricsLookup.NetEase.self, from: Data(json.utf8))
        let key = LyricsKey(title: "After Hours", artist: "The Weeknd", album: "After Hours", duration: 361)!
        #expect(LyricsLookup.match(in: search, for: key)?.id == 1424460203)
    }

    @Test func rejectsANetEaseTrackOfTheWrongLength() throws {
        let json = """
        {"result":{"songs":[
          {"id":1424460203,"name":"After Hours","dt":361026,"ar":[{"name":"The Weeknd"}],"al":{"name":"After Hours"}}
        ]}}
        """
        let search = try JSONDecoder().decode(LyricsLookup.NetEase.self, from: Data(json.utf8))
        let key = LyricsKey(title: "After Hours", artist: "The Weeknd", album: "After Hours", duration: 300)!
        #expect(LyricsLookup.match(in: search, for: key) == nil)
    }

    @Test func netEaseLyricsDropProductionCredits() throws {
        let json = """
        {"lrc":{"lyric":"[00:00.000] 作词 : Someone\\n[00:01.000] 作曲 : Someone\\n[00:10.181]Thought I almost died\\n[00:18.124]Fightin' for my life"}}
        """
        let lyric = try JSONDecoder().decode(LyricsLookup.NetEaseLyric.self, from: Data(json.utf8))
        let key = LyricsKey(title: "After Hours", artist: "The Weeknd", album: "", duration: 361)!
        let lyrics = LyricsLookup.lyrics(from: lyric, for: key)
        #expect(lyrics?.lines.count == 2)
        #expect(lyrics?.lines.first?.text == "Thought I almost died")
        #expect(lyrics?.lines.first?.time == 10.181)
    }

    @Test func normalizesLiveAndRemasteredTitles() {
        #expect(LyricsLookup.normalizedTitle("After Hours (Live)") == "after hours")
        #expect(LyricsLookup.normalizedTitle("After Hours - Remastered 2011") == "after hours")
    }

    @Test func retriesOnAWideningSchedule() {
        #expect(LyricsRetryPolicy.delay(afterFailure: 0) == 5)
        #expect(LyricsRetryPolicy.delay(afterFailure: 1) == 15)
        #expect(LyricsRetryPolicy.delay(afterFailure: 2) == 60)
        #expect(LyricsRetryPolicy.delay(afterFailure: 3) == 300)
        #expect(LyricsRetryPolicy.delay(afterFailure: 20) == 300)
    }
}

@MainActor
@Suite("Settings defaults")
struct SettingsStoreTests {
    private func makeDefaults() -> (UserDefaults, String) {
        let name = "ArrowslitTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return (defaults, name)
    }

    @Test func newInstallsStartWithAlertsOnAndLockScreenOff() {
        let (defaults, name) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: name) }
        let settings = SettingsStore(defaults: defaults)

        #expect(settings.liquidAnimations)
        #expect(settings.hapticFeedback)
        #expect(!settings.showOnLockScreen)
        #expect(settings.alertCharging)
        #expect(settings.alertLowBattery)
        #expect(settings.alertHeadphones)
        #expect(settings.alertVolumeBrightness)
    }

    @Test func alertAndLockScreenChoicesPersist() {
        let (defaults, name) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: name) }
        let settings = SettingsStore(defaults: defaults)
        settings.showOnLockScreen = true
        settings.alertVolumeBrightness = false

        let reloaded = SettingsStore(defaults: defaults)
        #expect(reloaded.showOnLockScreen)
        #expect(!reloaded.alertVolumeBrightness)
    }
}

@Suite("Artwork accent")
struct ArtworkAccentTests {
    @Test func unreadableArtworkFallsBackToWhite() {
        #expect(ArtworkAccentReader.accent(from: Data([0, 1, 2, 3])) == .white)
    }
}


@MainActor
@Suite("Update prompts")
struct UpdatePromptTests {
    private func release(_ version: String) -> ReleaseInfo {
        ReleaseInfo(
            version: SemanticVersion(version)!,
            page: URL(string: "https://github.com/j4yop/arrowslit/releases/tag/v\(version)")!,
            diskImage: URL(string: "https://github.com/j4yop/arrowslit/releases/download/v\(version)/Arrowslit-\(version).dmg")!,
            checksum: URL(string: "https://github.com/j4yop/arrowslit/releases/download/v\(version)/Arrowslit-\(version).dmg.sha256")!
        )
    }

    @Test func announcesEachVersionOnlyOnce() {
        let name = "ArrowslitTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        defer { defaults.removePersistentDomain(forName: name) }

        let service = UpdateService(defaults: defaults)
        var announced: [String] = []
        service.onAvailable = { announced.append($0.version.description); return true }

        service.notifyIfNeeded(release("0.5.1"))
        service.notifyIfNeeded(release("0.5.1"))
        service.notifyIfNeeded(release("0.6.0"))

        #expect(announced == ["0.5.1", "0.6.0"])
    }
}

@Suite("Semantic versions")
struct SemanticVersionTests {
    @Test func comparesNumberByNumber() {
        #expect(SemanticVersion("0.4.4")! > SemanticVersion("0.4.3")!)
        #expect(SemanticVersion("v0.5.0")! > SemanticVersion("0.4.9")!)
        #expect(SemanticVersion("0.4")! == SemanticVersion("0.4.0")!)
        #expect(SemanticVersion("nope") == nil)
    }
}

@Suite("Release parsing")
struct ReleaseInfoTests {
    private let json = """
    {
      "tag_name": "v0.4.4",
      "html_url": "https://github.com/j4yop/arrowslit/releases/tag/v0.4.4",
      "assets": [
        {"name": "Arrowslit-0.4.4.dmg", "browser_download_url": "https://github.com/j4yop/arrowslit/releases/download/v0.4.4/Arrowslit-0.4.4.dmg"},
        {"name": "Arrowslit-0.4.4.dmg.sha256", "browser_download_url": "https://github.com/j4yop/arrowslit/releases/download/v0.4.4/Arrowslit-0.4.4.dmg.sha256"}
      ]
    }
    """

    @Test func parsesTheLatestReleaseAndItsAssets() {
        let release = ReleaseInfo.parse(Data(json.utf8))
        #expect(release?.version == SemanticVersion("0.4.4"))
        #expect(release?.diskImage.lastPathComponent == "Arrowslit-0.4.4.dmg")
        #expect(release?.checksum?.lastPathComponent == "Arrowslit-0.4.4.dmg.sha256")
    }

    @Test func buildsAReleaseFromTheLatestRedirect() {
        let release = ReleaseInfo.fromLatestRedirect(URL(string: "https://github.com/j4yop/arrowslit/releases/tag/v0.4.4")!)
        #expect(release?.version == SemanticVersion("0.4.4"))
        #expect(release?.diskImage.lastPathComponent == "Arrowslit-0.4.4.dmg")
        #expect(release?.checksum?.lastPathComponent == "Arrowslit-0.4.4.dmg.sha256")
        #expect(ReleaseInfo.fromLatestRedirect(URL(string: "https://example.com/releases/tag/v0.4.4")!) == nil)
    }

    @Test func rejectsForeignHostsAndMissingImages() {
        let foreign = json.replacingOccurrences(of: "github.com/j4yop", with: "example.com/j4yop")
        #expect(ReleaseInfo.parse(Data(foreign.utf8)) == nil)
        let noImage = json.replacingOccurrences(of: "Arrowslit-0.4.4.dmg", with: "other.dmg")
        #expect(ReleaseInfo.parse(Data(noImage.utf8)) == nil)
    }
}
