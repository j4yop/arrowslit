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

    @Test func wideNotchStillLeavesRoomForTheClock() {
        let wide = geometry(notchWidth: 179)
        #expect(wide.compactWidth == 320)
        #expect(wide.earWidth(in: wide.compactWidth) == 70.5)
    }

    @Test func veryWideNotchGrowsTheStrip() {
        let veryWide = geometry(notchWidth: 250)
        #expect(veryWide.compactWidth == 390)
        #expect(veryWide.earWidth(in: veryWide.compactWidth) == 70)
    }
}
