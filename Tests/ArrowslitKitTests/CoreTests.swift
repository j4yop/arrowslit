import Foundation
import Testing
@testable import ArrowslitKit

@Suite("Clock formatting")
struct ClockFormatTests {
    @Test func formatsCountdownsAndClocks() {
        #expect(ClockFormat.clock(59.2, roundingUp: true) == "1:00")
        #expect(ClockFormat.clock(65) == "1:05")
        #expect(ClockFormat.clock(3661) == "1:01:01")
        #expect(ClockFormat.clock(.nan) == "0:00")
        #expect(ClockFormat.presetLabel(minutes: 25) == "25m")
        #expect(ClockFormat.presetLabel(minutes: 90) == "1h 30m")
    }

    @Test func formatsTheNotchClockInIndiaStandardTime() {
        #expect(ClockFormat.wallClockIST(Date(timeIntervalSince1970: 0)) == "5:30 AM")
        #expect(ClockFormat.wallClockIST(Date(timeIntervalSince1970: 36_000)) == "3:30 PM")
    }

    @Test func speaksDurationsForVoiceOver() {
        #expect(ClockFormat.spoken(299) == "4 minutes, 59 seconds")
        #expect(ClockFormat.spoken(60) == "1 minute")
        #expect(ClockFormat.spoken(3_661) == "1 hour, 1 minute, 1 second")
        #expect(ClockFormat.spoken(0) == "0 seconds")
    }
}

@Suite("Countdown")
struct CountdownTests {
    @Test func pauseAndResumeKeepTheRemainingTime() {
        let start = Date(timeIntervalSince1970: 1_000)
        var timer = Countdown(minutes: 25, now: start)
        #expect(timer.remaining(at: start) == 1_500)

        timer.pause(at: start.addingTimeInterval(600))
        #expect(timer.isPaused)
        #expect(timer.remaining(at: start.addingTimeInterval(900)) == 900)

        timer.resume(at: start.addingTimeInterval(900))
        #expect(timer.remaining(at: start.addingTimeInterval(1_000)) == 800)
    }

    @Test func finishesOnlyAfterTheDeadline() {
        let start = Date(timeIntervalSince1970: 1_000)
        var timer = Countdown(minutes: 1, now: start)
        let early = timer.finishIfDue(at: start.addingTimeInterval(59))
        #expect(!early)
        let late = timer.finishIfDue(at: start.addingTimeInterval(60))
        #expect(late)
        #expect(timer.isFinished)
        #expect(timer.remaining(at: start.addingTimeInterval(61)) == 0)
    }
}

@Suite("Clipboard rules")
struct ClipboardRulesTests {
    @Test func skipsPrivatePasteboardMarkers() {
        #expect(ClipboardRules.isRecordable(types: ["public.utf8-plain-text"]))
        #expect(!ClipboardRules.isRecordable(types: ["public.utf8-plain-text", "org.nspasteboard.ConcealedType"]))
    }

    @Test func previewCollapsesWhitespace() {
        #expect(ClipboardRules.preview("hello\n\n  world") == "hello world")
    }
}

@Suite("Stats maths")
struct StatsMathTests {
    @Test func calculatesBusyShare() {
        let old = CPUSample(user: 100, system: 50, idle: 850, nice: 0)
        let new = CPUSample(user: 160, system: 70, idle: 870, nice: 0)
        #expect(abs(StatsMath.cpuUsage(from: old, to: new) - 0.8) < 0.001)
        #expect(StatsMath.level(0.5) == .normal)
        #expect(StatsMath.level(0.8) == .busy)
        #expect(StatsMath.level(0.95) == .high)
    }

    @Test func formatsDiskAndNetworkReadings() {
        #expect(StatsMath.rate(from: 1_000, to: 4_000, seconds: 2) == 1_500)
        #expect(StatsMath.rate(from: 4_000, to: 1_000, seconds: 2) == 0)
        #expect(StatsMath.rate(1_500).hasSuffix("/s"))
        #expect(StatsMath.rate(0) == "0 KB/s")
        #expect(StatsMath.countsTraffic(interface: "en0"))
        #expect(!StatsMath.countsTraffic(interface: "lo0"))
        #expect(StatsMath.bytes(Int64(1_024)).contains("KB") || StatsMath.bytes(Int64(1_024)).contains("bytes"))
    }
}

@Suite("Screen geometry")
struct ScreenGeometryTests {
    private func geometry(notchWidth: CGFloat) -> ScreenGeometry {
        ScreenGeometry(
            size: CGSize(width: 1470, height: 956),
            notch: CGRect(x: (1470 - notchWidth) / 2, y: 0, width: notchWidth, height: 32),
            menuBarHeight: 32
        )
    }

    @Test func compactStripKeepsAnEarOnEachSideOfANormalNotch() {
        let normal = geometry(notchWidth: 100)
        #expect(normal.compactWidth == 320)
        #expect(normal.earWidth(in: normal.compactWidth) == 110)
    }

    @Test func wideNotchGrowsTheStripToKeepTheClockClear() {
        let wide = geometry(notchWidth: 179)
        #expect(wide.compactWidth == 340)
        #expect(wide.earWidth(in: wide.compactWidth) == 80.5)
    }

    @Test func veryWideNotchGrowsTheStrip() {
        let veryWide = geometry(notchWidth: 250)
        #expect(veryWide.compactWidth == 410)
        #expect(veryWide.earWidth(in: veryWide.compactWidth) == 80)
    }
}

@MainActor
@Suite("File drops")
struct FileDropTests {
    @Test func parsesTheFileURLDataFinderSends() {
        let url = URL(fileURLWithPath: "/Users/jaygopal/Desktop/Arrowslit-Clock-IST.png")
        let data = Data(url.absoluteString.utf8)
        #expect(FileDrop.url(from: data) == url)
    }

    @Test func ignoresNonFileURLs() {
        let data = Data("https://example.com".utf8)
        #expect(FileDrop.url(from: data) == nil)
    }
}

@Suite("Clock ruler")
struct ClockRulerTests {
    @Test func draggingLeftPullsLaterMinutesUnderThePointer() {
        #expect(RulerMath.minute(from: 17, translation: -28, spacing: 14, range: RulerMath.timerRange) == 19)
        #expect(RulerMath.minute(from: 17, translation: 28, spacing: 14, range: RulerMath.timerRange) == 15)
    }

    @Test func clampsAtBothEnds() {
        #expect(RulerMath.minute(from: 1, translation: 200, spacing: 14, range: RulerMath.timerRange) == 1)
        #expect(RulerMath.minute(from: 60, translation: -200, spacing: 14, range: RulerMath.timerRange) == 60)
        #expect(RulerMath.clamp(0, to: RulerMath.timerRange) == 1)
        #expect(RulerMath.clamp(61, to: RulerMath.timerRange) == 60)
    }

    @Test func tappingATickJumpsToIt() {
        #expect(RulerMath.tappedMinute(at: 200, center: 200, current: 17, spacing: 14, range: RulerMath.timerRange) == 17)
        #expect(RulerMath.tappedMinute(at: 228, center: 200, current: 17, spacing: 14, range: RulerMath.timerRange) == 19)
    }

    @Test func visibleRangeAlwaysIncludesTheSelectedMinute() {
        let visible = RulerMath.visibleRange(
            value: 17,
            width: 400,
            spacing: 14,
            range: RulerMath.timerRange
        )
        #expect(visible?.contains(17) == true)
        #expect(visible?.lowerBound == 1)
    }
}

@MainActor
@Suite("Clock services")
struct ClockServiceTests {
    @Test func timerPanelAndFocusDurationsStayIndependent() {
        let timer = TimerService()
        defer { timer.reset() }

        timer.panelMinutes = 17
        timer.start(minutes: 17)
        #expect(timer.panelMinutes == 17)
        #expect(timer.countdown?.total == 1020)
        timer.reset()

        timer.startFocus(minutes: 40)
        #expect(timer.focusMinutes == 40)
        #expect(timer.panelMinutes == 17)
        #expect(timer.countdown?.total == 2400)
        timer.reset()

        timer.startBreak(minutes: 7)
        #expect(timer.breakMinutes == 7)
        #expect(timer.panelMinutes == 17)
        #expect(timer.countdown?.total == 420)
    }

    @Test func timerDefaultsPersistAcrossRelaunch() {
        let suite = "ArrowslitTimerTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)

        let timer = TimerService(defaults: defaults)
        timer.panelMinutes = 33
        timer.focusMinutes = 45
        timer.breakMinutes = 9

        let reloaded = TimerService(defaults: defaults)
        #expect(reloaded.panelMinutes == 33)
        #expect(reloaded.focusMinutes == 45)
        #expect(reloaded.breakMinutes == 9)
        defaults.removePersistentDomain(forName: suite)
    }

    @Test func stopwatchBecomesActiveWhenStarted() {
        let stopwatch = StopwatchService()
        defer { stopwatch.reset() }

        #expect(!stopwatch.isActive)
        stopwatch.start()
        #expect(stopwatch.isActive)
        stopwatch.reset()
        #expect(!stopwatch.isActive)
    }

    @Test func clockModesHaveTheExpectedTitles() {
        #expect(ClockMode.timer.title == "Timer")
        #expect(ClockMode.focus.title == "Pomodoro")
        #expect(ClockMode.stopwatch.title == "Stopwatch")
    }
}

@Suite("Month layout and calendar lists")
struct MonthLayoutTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        calendar.firstWeekday = 1
        return calendar
    }()

    @Test func laysOutTheCurrentMonth() {
        let date = calendar.date(from: DateComponents(year: 2026, month: 10, day: 22))!
        let month = MonthLayout(containing: date, calendar: calendar)
        #expect(month.cells.compactMap { $0 }.count == 31)
        #expect(month.today == 22)
        #expect(month.weekdaySymbols.count == 7)
    }

    @Test func listsUpcomingEventsInOrder() {
        let now = calendar.date(from: DateComponents(year: 2026, month: 10, day: 22, hour: 10))!
        func event(_ title: String, day: Int, hour: Int) -> CalendarEvent {
            let start = calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour))!
            return CalendarEvent(id: title, title: title, start: start, end: start.addingTimeInterval(1800))
        }
        let events = [event("Later", day: 23, hour: 9), event("Sooner", day: 22, hour: 12), event("Past", day: 21, hour: 9)]
        #expect(CalendarRules.upcoming(in: events, at: now, limit: 3).map(\.title) == ["Sooner", "Later"])
        #expect(CalendarRules.dayLabel(for: events[0], at: now) == "Tomorrow")
    }

    @Test func filtersTodayEventsThatAreOver() {
        let now = calendar.date(from: DateComponents(year: 2026, month: 10, day: 22, hour: 10))!
        let start = calendar.date(from: DateComponents(year: 2026, month: 10, day: 22, hour: 9))!
        let event = CalendarEvent(id: "done", title: "Done", start: start, end: start.addingTimeInterval(1800))
        #expect(CalendarRules.events(on: now, in: [event], at: now, calendar: calendar).isEmpty)
    }
}

@MainActor
@Suite("Pinned file tray")
struct PinnedTrayTests {
    @Test func pinnedFilesSurviveAReload() throws {
        let name = "ArrowslitTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        defer { defaults.removePersistentDomain(forName: name) }

        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let file = folder.appendingPathComponent("keep.txt")
        try Data("keep".utf8).write(to: file)

        let store = TrayStore(defaults: defaults)
        store.add([file])
        let id = try #require(store.items.first?.id)
        store.togglePin(id)
        #expect(store.items.first?.isPinned == true)

        let reloaded = TrayStore(defaults: defaults)
        #expect(reloaded.items.count == 1)
        #expect(reloaded.items.first?.isPinned == true)
    }
}
