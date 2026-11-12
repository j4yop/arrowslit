import AppKit
import Foundation
import Testing
@testable import ArrowslitKit

@Suite("Clipboard history")
struct ClipboardHistoryTests {
    @Test func pinnedClipsSitAtTheTopAndSurviveClear() {
        var history = ClipboardHistory()
        history.add("alpha", appName: "Terminal")
        history.add("beta", appName: "Safari")
        let alpha = history.entries.first { $0.text == "alpha" }!
        let pinned = history.togglePin(alpha.id)
        #expect(pinned)
        #expect(history.entries.first?.text == "alpha")
        #expect(history.entries.first?.isPinned == true)
        history.removeAll()
        #expect(history.entries.map(\.text) == ["alpha"])
        #expect(history.pinnedCount == 1)
    }

    @Test func copyingTheSameTextDoesNotDuplicateIt() {
        var history = ClipboardHistory()
        _ = history.add("alpha")
        _ = history.add("beta")
        _ = history.add("alpha")
        #expect(history.entries.map(\.text) == ["alpha", "beta"])
    }

    @Test func matchingUsesEveryWordAndIgnoresCaseAndAccents() {
        var history = ClipboardHistory()
        _ = history.add("Café order for Jay", appName: "Notes")
        _ = history.add("Unrelated text", appName: "Terminal")
        #expect(history.matching("cafe jay").map(\.text) == ["Café order for Jay"])
        #expect(history.matching("terminal").map(\.text) == ["Unrelated text"])
        #expect(history.matching("").count == 2)
    }

    @Test func changingCapacityDropsTheOldestUnpinnedClips() {
        var history = ClipboardHistory(capacity: 2)
        _ = history.add("one")
        _ = history.add("two")
        _ = history.add("three")
        #expect(history.entries.map(\.text) == ["three", "two"])

        history.setCapacity(1)
        #expect(history.entries.map(\.text) == ["three"])
        #expect(history.capacity == 1)
    }



    @Test func richEntriesKeepTheirKindAndPreview() {
        var history = ClipboardHistory()
        history.addEntry(ClipboardHistory.Entry(
            kind: .image,
            text: "",
            appName: "Screenshot",
            imageFilename: "image.png",
            imageWidth: 284,
            imageHeight: 206,
            imageHash: "abc"
        ))
        history.addEntry(ClipboardHistory.Entry(
            kind: .file,
            text: "report.pdf",
            appName: "Finder",
            filePath: "/tmp/report.pdf"
        ))
        history.addEntry(ClipboardHistory.Entry(
            kind: .url,
            text: "https://github.com/j4yop/arrowslit",
            appName: "Safari"
        ))

        #expect(history.entries.map(\.kind) == [.url, .file, .image])
        #expect(history.entries.last?.previewText == "Image · 284 × 206")
        #expect(history.entries[1].previewText == "report.pdf")
        #expect(history.matching("report").map(\.kind) == [.file])
        #expect(history.matching("image").map(\.kind) == [.image])
    }

    @Test func copyingTheSameImageMovesTheExistingCardToTheFront() {
        var history = ClipboardHistory()
        let image = ClipboardHistory.Entry(
            kind: .image,
            text: "",
            appName: "Screenshot",
            imageFilename: "one.png",
            imageWidth: 100,
            imageHeight: 100,
            imageHash: "same"
        )
        history.addEntry(image)
        history.add("a text clip")
        history.addEntry(ClipboardHistory.Entry(
            kind: .image,
            text: "",
            appName: "Screenshot",
            imageFilename: "two.png",
            imageWidth: 100,
            imageHeight: 100,
            imageHash: "same"
        ))

        #expect(history.entries.count == 2)
        #expect(history.entries.first?.kind == .image)
        #expect(history.entries.first?.imageFilename == "one.png")
    }

    @Test func clipPreviewsShowThatPreviewIsUnavailable() {
        var history = ClipboardHistory()
        history.addEntry(ClipboardHistory.Entry(kind: .clip, text: "", appName: "Notes"))
        #expect(history.entries.first?.previewText == "Preview unavailable")
        #expect(history.entries.first?.characterCount == 0)
    }

    @Test func unpinnedHistoryIsCapped() {
        var history = ClipboardHistory()
        for index in 0..<(ClipboardHistory.capacity + 5) {
            _ = history.add("clip \(index)")
        }
        #expect(history.entries.count == ClipboardHistory.capacity)
        #expect(history.entries.first?.text == "clip 24")
    }
}

@Suite("Clipboard pins persistence")
@MainActor
struct ClipboardPinsPersistenceTests {
    @Test func pinsReloadAfterARestartAndClearKeepsThem() {
        let suite = "ArrowslitClipboardTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let board = NSPasteboard(name: NSPasteboard.Name("ArrowslitClipboardTests-\(UUID().uuidString)"))
        let service = ClipboardService(pasteboard: board, defaults: defaults)
        service.promote("alpha", appName: "Terminal")
        service.promote("beta", appName: "Safari")
        let alpha = service.entries.first { $0.text == "alpha" }!
        service.togglePin(alpha)
        service.clear()
        #expect(service.entries.map(\.text) == ["alpha"])
        #expect(service.entries.first?.isPinned == true)

        let reloaded = ClipboardService(pasteboard: board, defaults: defaults)
        #expect(reloaded.entries.map(\.text) == ["alpha"])
        #expect(reloaded.entries.first?.isPinned == true)
        defaults.removePersistentDomain(forName: suite)
    }
}
