import Foundation
import SwiftData
import Testing

@testable import CrocApp

/// When the Home recent-transfers section shows, and which records it takes
/// (design/components.md → Home, "Recent transfers").
@MainActor @Suite struct RecentTransfersSectionTests {
    // MARK: Gate

    @Test func historyOffHidesTheSectionEvenWithRecords() {
        #expect(RecentTransfersSection.content(saveHistory: false, recordCount: 0) == .hidden)
        #expect(RecentTransfersSection.content(saveHistory: false, recordCount: 3) == .hidden)
    }

    @Test func historyOnWithNoRecordsShowsTheEmptyState() {
        #expect(RecentTransfersSection.content(saveHistory: true, recordCount: 0) == .empty)
    }

    @Test func historyOnWithRecordsShowsRows() {
        #expect(RecentTransfersSection.content(saveHistory: true, recordCount: 1) == .rows)
    }

    // MARK: Limit and order

    private func latestNames(adding count: Int) throws -> [String] {
        let history = HistoryStore(container: HistoryStore.makeContainer(inMemory: true))
        let base = Date(timeIntervalSince1970: 1_800_000_000)
        // Inserted out of date order, so the sort is by date, not insertion.
        for index in [2, 0, 4, 1, 3].prefix(count) {
            let record = TransferRecord(
                isSend: true, status: .completed, isText: false, fileCount: 1,
                totalBytes: 1, names: ["file\(index)"], codeHint: "wiry-…", bookmarks: [])
            record.date = base.addingTimeInterval(Double(index) * 60)
            history.add(record)
        }
        let fetched = try history.container.mainContext.fetch(RecentTransfersSection.latest)
        return fetched.compactMap(\.names.first)
    }

    @Test func theSectionTakesTheNewestThreeNewestFirst() throws {
        #expect(RecentTransfersSection.limit == 3)
        #expect(try latestNames(adding: 5) == ["file4", "file3", "file2"])
    }

    @Test func fewerRecordsThanTheLimitAreAllKept() throws {
        #expect(try latestNames(adding: 2) == ["file2", "file0"])
    }
}
