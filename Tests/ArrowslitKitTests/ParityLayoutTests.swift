import CoreGraphics
import Testing
@testable import ArrowslitKit

@Suite("Parity layout")
struct ParityLayoutTests {
    private let builtIn = ScreenGeometry(
        size: CGSize(width: 1470, height: 956),
        notch: CGRect(x: 645, y: 0, width: 180, height: 32),
        menuBarHeight: 32
    )

    private let external = ScreenGeometry(
        size: CGSize(width: 1920, height: 1080),
        notch: nil,
        menuBarHeight: 24
    )

    private let large = NotchAppearance.standard
    private let medium = NotchAppearance(width: 200, height: 32, size: .medium)
    private let small = NotchAppearance(width: 200, height: 32, size: .small)

    @Test func compactMatchesNotch ShellEars() {
        #expect(ParityLayout.hiddenSize(large, geometry: builtIn) == CGSize(width: 200, height: 35))
        #expect(ParityLayout.compactSize(large, geometry: builtIn) == CGSize(width: 274, height: 32))
        #expect(ParityLayout.compactSize(medium, geometry: builtIn) == CGSize(width: 264, height: 32))
        #expect(ParityLayout.compactSize(small, geometry: builtIn) == CGSize(width: 256, height: 32))
        #expect(ParityLayout.compactSize(large, geometry: builtIn, hasSecondary: true) == CGSize(width: 304, height: 32))
    }

    @Test func externalDisplayGetsAVirtualNotch() {
        let notch = ParityLayout.notch(in: external)
        #expect(notch == CGRect(x: 870, y: 0, width: 180, height: 32))
        #expect(ParityLayout.isVirtualNotch(external))
        #expect(ParityLayout.compactSize(large, geometry: external) == CGSize(width: 274, height: 32))
    }

    @Test func expandedWidthsScaleLikeNotch Shell() {
        #expect(ParityLayout.expandedSize(for: .nowPlaying, appearance: large, geometry: builtIn) == CGSize(width: 390, height: 188))
        #expect(ParityLayout.expandedSize(for: .nowPlaying, appearance: medium, geometry: builtIn) == CGSize(width: 351, height: 173))
        #expect(ParityLayout.expandedSize(for: .nowPlaying, appearance: small, geometry: builtIn) == CGSize(width: 312, height: 157))
        #expect(ParityLayout.expandedSize(for: .nowPlaying, appearance: large, geometry: builtIn, hasLyrics: true).height == 218)
    }

    @Test func homeUsesTheShortNook() {
        #expect(ParityLayout.expandedSize(for: .home, appearance: large, geometry: builtIn) == CGSize(width: 580, height: 178))
        #expect(ParityLayout.expandedSize(for: .launcher, appearance: large, geometry: builtIn) == CGSize(width: 580, height: 228))
    }

    @Test func elongatedStretchesOnlyTheThreeTabs() {
        let elongated = NotchAppearance(width: 200, height: 32, nookLayout: .elongated)
        #expect(ParityLayout.isElongated(.home, appearance: elongated))
        #expect(ParityLayout.isElongated(.tray, appearance: elongated))
        #expect(ParityLayout.isElongated(.clipboard, appearance: elongated))
        #expect(!ParityLayout.isElongated(.launcher, appearance: elongated))
        #expect(ParityLayout.expandedSize(for: .home, appearance: elongated, geometry: builtIn) == CGSize(width: 1240, height: 178))
        #expect(ParityLayout.expandedSize(for: .tray, appearance: elongated, geometry: builtIn).width == 1240)
        #expect(ParityLayout.expandedSize(for: .clipboard, appearance: elongated, geometry: builtIn).width == 1240)
        #expect(ParityLayout.expandedSize(for: .launcher, appearance: elongated, geometry: builtIn).width == 580)
        #expect(ParityLayout.expandedSize(for: .nowPlaying, appearance: elongated, geometry: builtIn).width == 390)
    }

    @Test func alertsUseNotch ShellEarsAndHeight() {
        let event = NotchAlert.upcomingEvent(title: "Design review", startsAt: .now, joinURL: nil, provider: nil)
        #expect(ParityLayout.alertSize(for: event, appearance: large, geometry: builtIn) == CGSize(width: 492, height: 38))

        let level = NotchAlert.level(kind: .volume, value: 0.5, muted: false)
        #expect(ParityLayout.alertSize(for: level, appearance: large, geometry: builtIn) == CGSize(width: 372, height: 32))

        let charging = NotchAlert.charging(level: 80, isCharging: true)
        #expect(ParityLayout.alertSize(for: charging, appearance: large, geometry: builtIn) == CGSize(width: 436, height: 38))
    }

    @Test func hudStaysInsideTheCompactHeight() {
        let size = ParityLayout.size(
            for: .hud(.level(kind: .brightness, value: 0.5, muted: false)),
            appearance: large,
            geometry: builtIn
        )
        #expect(size == CGSize(width: 372, height: 32))
    }

    @Test func appearanceClampsEverything() {
        let clamped = NotchAppearance(width: 999, height: 1, glassTint: 4).clamped()
        #expect(clamped.width == 420)
        #expect(clamped.height == 24)
        #expect(clamped.glassTint == 1)
    }

    @Test func shapeHasConcaveShoulders() {
        let shape = IslandShape(bottomRadius: 18, flare: 6)
        let rect = CGRect(x: 0, y: 0, width: 300, height: 120)
        let path = shape.path(in: rect)
        #expect(!path.isEmpty)
        #expect(abs(path.boundingRect.width - rect.width) < 0.001)
        #expect(abs(path.boundingRect.height - rect.height) < 0.001)
    }
}

@Suite("Launcher paging")
struct LauncherPagingTests {
    @Test func twelveFeaturesMakeTwoPages() {
        #expect(LauncherPaging.pages(Array(1...12)).map(\.count) == [10, 2])
    }

    @Test func tenFeaturesFitOnePage() {
        #expect(LauncherPaging.pages(Array(1...10)).map(\.count) == [10])
    }

    @Test func elevenFeaturesSpillOneTile() {
        #expect(LauncherPaging.pages(Array(1...11)).map(\.count) == [10, 1])
    }

    @Test func noFeaturesMakeNoPages() {
        #expect(LauncherPaging.pages([Int]()).isEmpty)
    }
}
