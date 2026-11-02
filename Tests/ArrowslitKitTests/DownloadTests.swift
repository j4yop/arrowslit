import Foundation
import Testing
@testable import ArrowslitKit

@Suite("Download progress")
struct DownloadProgressTests {
    @Test func fractionAndSummaryAggregateOnlySizedDownloads() {
        let first = DownloadProgressItem(id: "/tmp/a", name: "a", completed: 50, total: 100, startedAt: .now)
        let second = DownloadProgressItem(id: "/tmp/b", name: "b", completed: 25, total: 50, startedAt: .now)
        let unknown = DownloadProgressItem(id: "/tmp/c", name: "c", completed: 10, total: 0, startedAt: .now)
        #expect(first.fraction == 0.5)
        #expect(unknown.fraction == nil)
        #expect(DownloadSummary([first, second, unknown]).fraction == 0.5)
    }

    @Test func summaryReportsTheLongestWait() {
        let first = DownloadProgressItem(id: "a", name: "a", completed: 1, total: 2, secondsLeft: 3, startedAt: .now)
        let second = DownloadProgressItem(id: "b", name: "b", completed: 1, total: 2, secondsLeft: 8, startedAt: .now)
        #expect(DownloadSummary([first, second]).secondsLeft == 8)
    }

    @Test func rateSmoothsAndEstimatesTheRemainingTime() {
        var rate = DownloadRate()
        let start = Date(timeIntervalSince1970: 1_000)
        rate.add(bytes: 100, at: start)
        rate.add(bytes: 1_100, at: start.addingTimeInterval(1))
        #expect(rate.secondsLeft(completed: 1_100, total: 2_100) == 1)
    }

    @Test func formatsBytesAndTimes() {
        #expect(DownloadFormat.timeLeft(8) == "8 sec left")
        #expect(DownloadFormat.timeLeft(90) == "2 min left")
        #expect(DownloadFormat.timeLeft(3_900) == "1 hr 5 min left")
        #expect(DownloadFormat.bytes(0, of: 0) == "Zero KB")
    }

    @Test func stripsTemporaryDownloadExtensions() {
        #expect(DownloadProgressItem.displayName(for: URL(fileURLWithPath: "/tmp/report.pdf.crdownload")) == "report.pdf")
        #expect(DownloadProgressItem.displayName(for: URL(fileURLWithPath: "/tmp/report.pdf")) == "report.pdf")
    }

    @MainActor
    @Test func readsPartialBrowserDownloadsFromTheFolder() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let partial = directory.appendingPathComponent("report.pdf.crdownload")
        try Data(repeating: 0x41, count: 2_048).write(to: partial)
        try FileManager.default.setAttributes(
            [.modificationDate: Date().addingTimeInterval(-5)],
            ofItemAtPath: partial.path
        )
        let monitor = DownloadProgressMonitor(folder: directory)
        monitor.refresh(now: Date())
        #expect(monitor.items.count == 1)
        #expect(monitor.items.first?.name == "report.pdf")
        #expect(monitor.items.first?.completed == 2_048)
    }

    @Test func finishedNamesExcludePartialsAndHiddenFiles() {
        #expect(DownloadRules.isFinishedName("report.pdf"))
        #expect(!DownloadRules.isFinishedName("report.pdf.crdownload"))
        #expect(!DownloadRules.isFinishedName("report.pdf.part"))
        #expect(!DownloadRules.isFinishedName(".DS_Store"))
        #expect(!DownloadRules.isFinishedName(""))
    }
}
