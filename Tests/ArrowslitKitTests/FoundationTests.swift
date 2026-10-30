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

    @Test func expandedUsesTheWorkbenchSize() {
        let size = NotchPanelMetrics.size(for: .expanded(.home), geometry: geometry)
        #expect(size == CGSize(width: 560, height: 178))
    }

    @Test func alertUsesItsOwnShortPanel() {
        let size = NotchPanelMetrics.size(for: .alert(event()), geometry: geometry)
        #expect(size == CGSize(width: 560, height: 86))
    }
}
