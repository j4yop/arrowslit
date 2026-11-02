import AppKit
import Foundation
import Testing
@testable import ArrowslitKit

@Suite("Displays")
struct DisplayTests {
    @MainActor
    @Test func allDisplaysRoundTripsAndPersists() throws {
        #expect(DisplayChoice.all.rawValue == "all")
        #expect(DisplayChoice(rawValue: "all") == .all)
        #expect(DisplayChoice(rawValue: "display:ABC-123") == .specific("ABC-123"))
        #expect(DisplayChoice(rawValue: "bogus") == nil)

        let suite = "arrowslit.tests.display." + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let settings = SettingsStore(defaults: defaults)
        #expect(settings.displayChoice == .automatic)
        settings.displayChoice = .all
        #expect(SettingsStore(defaults: defaults).displayChoice == .all)
        settings.displayChoice = .specific("ABC-123")
        #expect(SettingsStore(defaults: defaults).displayChoice == .specific("ABC-123"))
    }

    @MainActor
    @Test func hoverDelayClampsAndPersists() throws {
        let suite = "arrowslit.tests.hover." + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let settings = SettingsStore(defaults: defaults)
        #expect(settings.hoverDelay == 0.4)
        #expect(settings.notchOpenMode == .hover)
        settings.hoverDelay = 0.1
        #expect(SettingsStore(defaults: defaults).hoverDelay == 0.1)
        settings.hoverDelay = 9
        #expect(settings.hoverDelay == 0.5)
        settings.notchOpenMode = .click
        #expect(!settings.openOnHover)
        settings.notchOpenMode = .hover
        #expect(settings.openOnHover)
    }

    @MainActor
    @Test func launcherShortcutsAreCompleteAndUnique() {
        let tabs = HotKeys.items
        #expect(tabs.count == 12)
        #expect(Set(tabs.compactMap(\.shortcutKey)).count == tabs.count)
        #expect(WorkbenchTab.nowPlaying.shortcutLabel == "⌃⌥M")
        #expect(WorkbenchTab.tray.shortcutLabel == "⌃⌥L")
        #expect(WorkbenchTab.sports.shortcutLabel == "⌃⌥F")
        #expect(HotKeys.keyCode("L") != nil)
        #expect(HotKeys.keyCode("Q") == nil)
    }

    @MainActor
    @Test func panelSizesUseTheScreenTheyAreOn() throws {
        let notch = ScreenGeometry(
            size: CGSize(width: 1512, height: 982),
            notch: CGRect(x: 662, y: 0, width: 188, height: 32),
            menuBarHeight: 32
        )
        let external = ScreenGeometry(
            size: CGSize(width: 2560, height: 1440),
            notch: nil,
            menuBarHeight: 24
        )
        let suite = "arrowslit.tests.panel." + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let state = AppState(settings: SettingsStore(defaults: defaults))
        let builtInCompact = state.panelSize(for: .idle, geometry: notch)
        let externalCompact = state.panelSize(for: .idle, geometry: external)
        #expect(builtInCompact.width != externalCompact.width)
        #expect(state.panelSize(for: .expanded(.home), geometry: notch).width == 580)
        #expect(state.panelSize(for: .expanded(.home), geometry: notch).height == 178)
        #expect(ScreenReader.screen(for: .all) != nil)
    }
}
