import CoreGraphics
import Testing
@testable import ArrowslitKit

@Suite("Vorssaint pages")
struct VorssaintPagesTests {
    @Test func sixteenPagesAndTwoExploreRows() {
        #expect(VorssaintPage.allCases.count == 16)
        #expect(VorssaintPage.exploreOrder.count == 16)
        #expect(Set(VorssaintPage.exploreOrder).count == 16)
        #expect(VorssaintPage.exploreOrder.prefix(10).map(\.rawValue) == [
            "controls", "mixer", "music", "clipboard", "captures",
            "files", "system", "tools", "calendar", "notifications",
        ])
        #expect(VorssaintPage.exploreOrder.suffix(6).map(\.rawValue) == [
            "timer", "camera", "downloads", "scratchpad", "agents", "watch",
        ])
    }

    @Test func shortcutsAreUniqueAndUseOptionCommand() {
        let labels = VorssaintPage.allCases.map(\.shortcutLabel)
        #expect(Set(labels).count == labels.count)
        #expect(labels.allSatisfy { $0.hasPrefix("⌥⌘") })
    }

    @Test func existingPanesAreReusedWhereTheyFit() {
        #expect(VorssaintPage.music.workbenchTab == .nowPlaying)
        #expect(VorssaintPage.clipboard.workbenchTab == .clipboard)
        #expect(VorssaintPage.files.workbenchTab == .tray)
        #expect(VorssaintPage.system.workbenchTab == .stats)
        #expect(VorssaintPage.timer.workbenchTab == .timer)
        #expect(VorssaintPage.controls.workbenchTab == nil)
        #expect(VorssaintPage.agents.workbenchTab == nil)
    }

    @Test func exploreUsesTheVorssaintPanelSize() {
        let geometry = ScreenGeometry(
            size: CGSize(width: 1470, height: 956),
            notch: CGRect(x: 645, y: 0, width: 180, height: 32),
            menuBarHeight: 32
        )
        let size = ParityLayout.expandedSize(
            for: .launcher,
            appearance: .standard,
            geometry: geometry
        )
        #expect(size == CGSize(width: 704, height: 316))
    }

    @Test func launcherUsesTheVorssaintPanelAndQuickAccessGeometry() {
        #expect(VorssaintWindow.panelWidth == 560)
        #expect(VorssaintWindow.gutter == 72)
        #expect(VorssaintWindow.totalWidth == 704)
        #expect(VorssaintWindow.quickDiameter == 44)
        #expect(VorssaintWindow.quickRowSpacing == 54)
        #expect(VorssaintWindow.leftQuickCenter(index: 0) == CGPoint(x: 38, y: 66))
        #expect(VorssaintWindow.rightQuickCenter(index: 1) == CGPoint(x: 666, y: 120))
        #expect(VorssaintWindow.musicCenter(for: nil) == CGPoint(x: 352, y: 278))
        #expect(ParityLayout.launcherSize() == CGSize(width: 704, height: 316))
        #expect(ParityLayout.launcherSize(for: .agents) == CGSize(width: 704, height: 400))
        #expect(VorssaintWindow.panelHeight(for: .agents) == 328)
        #expect(VorssaintWindow.contentHeight(for: .agents) == 264)
        #expect(VorssaintWindow.contentHeight(for: .system) == 180)
    }
}
