import Foundation
import Testing
@testable import ArrowslitKit

@Suite("Notch live catalogue")
@MainActor
struct NotchLiveTests {
    private func defaults() -> UserDefaults {
        let name = "arrowslit.tests.live.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    @Test func eventDefaultsMatchTheSupportedCatalogue() {
        #expect(NotchLiveSettings.Event.allCases.count == 15)
        #expect(NotchLiveSettings.Strip.allCases.count == 7)
        let live = NotchLiveSettings(defaults: defaults())
        #expect(live.isOn(NotchLiveSettings.Event.volume))
        #expect(live.isOn(NotchLiveSettings.Event.brightness))
        #expect(live.isOn(NotchLiveSettings.Event.microphone))
        #expect(live.isOn(NotchLiveSettings.Event.inputSource))
        #expect(live.isOn(NotchLiveSettings.Event.battery))
        #expect(live.isOn(NotchLiveSettings.Event.accessory))
        #expect(live.isOn(NotchLiveSettings.Event.clipboard))
        #expect(live.isOn(NotchLiveSettings.Event.download))
        #expect(live.isOn(NotchLiveSettings.Event.agents))
        #expect(live.isOn(NotchLiveSettings.Event.track))
        #expect(live.isOn(NotchLiveSettings.Event.timer))
        #expect(!live.isOn(NotchLiveSettings.Event.keyboardLight))
        #expect(!live.isOn(NotchLiveSettings.Event.systemNotification))
        #expect(!live.isOn(NotchLiveSettings.Event.capture))
        #expect(!live.isOn(NotchLiveSettings.Event.watch))
    }

    @Test func choicesPersistAndUnavailableRowsStayOff() {
        let defaults = defaults()
        let live = NotchLiveSettings(defaults: defaults)
        live.set(NotchLiveSettings.Event.track, false)
        live.set(NotchLiveSettings.Strip.calendar, false)
        live.set(NotchLiveSettings.Event.keyboardLight, true)
        #expect(!live.isOn(NotchLiveSettings.Event.track))
        #expect(!live.isOn(.calendar))
        #expect(!live.isOn(NotchLiveSettings.Event.keyboardLight))

        let reloaded = NotchLiveSettings(defaults: defaults)
        #expect(!reloaded.isOn(NotchLiveSettings.Event.track))
        #expect(!reloaded.isOn(.calendar))
        #expect(!reloaded.isOn(NotchLiveSettings.Event.keyboardLight))
    }

    @Test func stripsMapToTheClosedNotch() {
        let live = NotchLiveSettings(defaults: defaults())
        #expect(live.showsStrip(NotchActivity.timer))
        #expect(live.showsStrip(.nowPlaying))
        #expect(live.showsStrip(NotchActivity.calendar))
        #expect(live.showsStrip(NotchActivity.keepAwake))
        live.set(NotchLiveSettings.Strip.music, false)
        #expect(!live.showsStrip(.nowPlaying))
        #expect(live.showsStrip(NotchActivity.timer))
    }

    @Test func newAlertsUseTheCompactHUDAndKeepTargetDurations() {
        #expect(NotchAlert.clipboard(kind: "Text").usesCompactHUD)
        #expect(NotchAlert.track(title: "Song", artist: "Artist").usesCompactAlert)
        #expect(NotchAlert.microphone(muted: true).usesCompactHUD)
        #expect(NotchAlert.inputSource(code: "US", name: "U.S.").usesCompactHUD)
        #expect(NotchAlert.agentEvent(provider: "Codex", title: "Finished", detail: "2m").usesCompactHUD)
        #expect(NotchAlert.systemNotification(app: "Mail", title: "Hello", body: "Body").usesCompactHUD)
        #expect(NotchAlert.capture(kind: "Screenshot").usesCompactHUD)
        #expect(NotchAlert.watch(title: "Done", detail: "Terminal").usesCompactHUD)
        #expect(NotchAlert.clipboard(kind: "Text").displayDuration == 2.5)
        #expect(NotchAlert.track(title: "Song", artist: "Artist").displayDuration == 3)
        #expect(NotchAlert.agentEvent(provider: "Codex", title: "Finished", detail: "").displayDuration == 5)
        #expect(NotchAlert.watch(title: "Done", detail: "Terminal").displayDuration == 6)
    }

    @Test func musicSitsAheadOfCalendarAndKeepAwake() {
        #expect(NotchActivity.nowPlaying.priority < NotchActivity.calendar.priority)
        #expect(NotchActivity.nowPlaying.priority < NotchActivity.keepAwake.priority)
        #expect(NotchActivity.agents.priority < NotchActivity.calendar.priority)
        #expect(NotchActivity.agents.priority < NotchActivity.sports.priority)
    }

    @Test func agentsHoldTheStripOverLiveSports() {
        let input = PresentationInput(
            activeActivities: [.sports, .agents]
        )
        #expect(PresentationResolver.resolve(input) == .compact(primary: .agents))
    }

    @Test func aGoalInterruptsAgentsAndThenReturnsToThem() {
        let goal = SportsGoalEvent(
            matchID: "agents-sports",
            teamName: "Espanyol",
            teamShortName: "ESP",
            homeShortName: "ESP",
            awayShortName: "BAR",
            homeScore: 1,
            awayScore: 0,
            minute: "67'"
        )
        let during = PresentationInput(
            activeActivities: [.sports, .agents],
            alert: .sportsGoal(goal)
        )
        #expect(PresentationResolver.resolve(during) == .alert(.sportsGoal(goal)))

        let after = PresentationInput(
            activeActivities: [.sports, .agents],
            alert: nil
        )
        #expect(PresentationResolver.resolve(after) == .compact(primary: .agents))
    }
}
