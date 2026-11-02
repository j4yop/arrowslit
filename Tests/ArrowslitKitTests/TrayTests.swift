import Foundation
import Testing
@testable import ArrowslitKit

@Suite("Tray links")
@MainActor
struct TrayLinkTests {
    @Test func keepsWebLinksAndPinsThem() {
        let suite = "ArrowslitTrayTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let store = TrayStore(defaults: defaults)
        let url = URL(string: "https://example.com/article")!
        let added = store.add([url])
        #expect(added == 1)
        #expect(store.items.first?.isLink == true)
        #expect(store.items.first?.name == "example.com")
        let item = store.items[0]
        store.togglePin(item.id)

        let reloaded = TrayStore(defaults: defaults)
        #expect(reloaded.items.count == 1)
        #expect(reloaded.items.first?.url == url)
        defaults.removePersistentDomain(forName: suite)
    }

    @Test func rejectsUnsupportedSchemesAndMissingFiles() {
        let suite = "ArrowslitTrayTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        let store = TrayStore(defaults: defaults)
        #expect(store.add([URL(string: "ftp://example.com/file")!]) == 0)
        #expect(store.add([URL(fileURLWithPath: "/tmp/definitely-not-a-real-arrowslit-file")]) == 0)
        defaults.removePersistentDomain(forName: suite)
    }

    @Test func linkDropIsAcceptedButAirDropURLsStayFilesOnly() {
        let data = Data("https://example.com/page".utf8)
        #expect(FileDrop.anyURL(from: data)?.absoluteString == "https://example.com/page")
        #expect(FileDrop.url(from: data) == nil)
    }
}
