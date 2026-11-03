import CoreGraphics
import Testing
@testable import ArrowslitKit

@Suite("Notch outline")
struct NotchOutlineTests {
    @Test func outlineMatchesAI AgentsStroke() {
        #expect(NotchOutline.key == "notchOutlineEnabled")
        #expect(NotchOutline.lineWidth == 2)
        #expect(NotchOutline.topGap == 1)
        #expect(abs(NotchOutline.opacity - 0.65) < 0.0001)
        #expect(abs(NotchOutline.increasedContrastOpacity - 0.85) < 0.0001)
    }

    @Test func outlineHidesForLiveActivitiesAndShowsAtRestOrOpen() {
        #expect(NotchOutline.isVisible(for: .hidden(peek: false)))
        #expect(NotchOutline.isVisible(for: .hidden(peek: true)))
        #expect(NotchOutline.isVisible(for: .idle))
        #expect(NotchOutline.isVisible(for: .expanded(.home)))
        #expect(NotchOutline.isVisible(for: .expanded(.nowPlaying)))
        #expect(!NotchOutline.isVisible(for: .compact(primary: .nowPlaying, secondary: nil)))
        #expect(!NotchOutline.isVisible(for: .compact(primary: .call, secondary: .nowPlaying)))
        #expect(!NotchOutline.isVisible(for: .hud(.level(kind: .volume, value: 0.5, muted: false))))
        #expect(!NotchOutline.isVisible(for: .hud(.charging(level: 50, isCharging: true))))
        #expect(!NotchOutline.isVisible(for: .alert(.headphones(name: "AirPods"))))
        #expect(!NotchOutline.isVisible(for: .alert(.timerFinished)))
        #expect(!NotchOutline.isVisible(for: .clockRunning(.timer)))
    }

    @Test func outlineFollowsEachSurface() {
        #expect(NotchOutline.radius(for: .idle) == 12)
        #expect(NotchOutline.radius(for: .compact(primary: .nowPlaying, secondary: nil)) == 12)
        #expect(NotchOutline.radius(for: .hud(.charging(level: 50, isCharging: true))) == 12)
        #expect(NotchOutline.radius(for: .alert(.headphones(name: "AirPods"))) == 16)
        #expect(NotchOutline.radius(for: .expanded(.home)) == 30)
        #expect(NotchOutline.radius(for: .clockRunning(.timer)) == 30)
        #expect(NotchOutline.radius(for: .hidden(peek: true)) == 11)
        #expect(NotchOutline.radius(for: .hidden(peek: false)) == 12)
    }

    @Test func outlineFlareFollowsEachSurface() {
        #expect(NotchOutline.flare(for: .hidden(peek: true)) == 5)
        #expect(NotchOutline.flare(for: .hidden(peek: false)) == 0)
        #expect(NotchOutline.flare(for: .idle) == 6)
        #expect(NotchOutline.flare(for: .compact(primary: nil, secondary: nil)) == 6)
        #expect(NotchOutline.flare(for: .hud(.lowBattery(level: 10))) == 6)
        #expect(NotchOutline.flare(for: .alert(.timerFinished)) == 6)
        #expect(NotchOutline.flare(for: .expanded(.home)) == 10)
        #expect(NotchOutline.flare(for: .clockRunning(.stopwatch)) == 10)
    }
}
