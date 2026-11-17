import Foundation
import SwiftData
import SwiftUI
import Testing

@testable import CrocApp

@MainActor @Suite struct HistoryStoreTests {
    private let history = HistoryStore(container: HistoryStore.makeContainer(inMemory: true))

    private func record(storedID: String?) -> TransferRecord {
        TransferRecord(
            isSend: true, status: .completed, isText: false, fileCount: 1, totalBytes: 10,
            names: ["a.txt"], codeHint: "store.example", bookmarks: [], storedID: storedID,
            expiresAt: storedID == nil ? nil : Date(timeIntervalSince1970: 2_000_000_000))
    }

    @Test func findsTheRecordOfAStoredUpload() {
        let other = record(storedID: "up1")
        let wanted = record(storedID: "up2")
        history.add(other)
        history.add(wanted)
        history.add(record(storedID: nil))

        #expect(history.record(storedID: "up2") === wanted)
        #expect(history.record(storedID: "up1") === other)
    }

    @Test func hasNoRecordForAnUnknownUpload() {
        history.add(record(storedID: "up1"))
        history.add(record(storedID: nil))

        #expect(history.record(storedID: "nope") == nil)
    }

    @Test func hasNoRecordOnceItIsDeleted() {
        let stored = record(storedID: "up1")
        history.add(stored)
        history.delete(stored)

        #expect(history.record(storedID: "up1") == nil)
    }

    @Test func theOldestRecordsGoBeyondTheCap() {
        for number in 0...TransferRecord.maxRecords {
            let old = record(storedID: "up\(number)")
            old.date = Date(timeIntervalSinceNow: Double(number - TransferRecord.maxRecords))
            history.add(old)
        }

        #expect(history.recordCount() == TransferRecord.maxRecords)
        #expect(history.record(storedID: "up0") == nil)
        #expect(history.record(storedID: "up1") != nil)
    }

    #if os(macOS)
    /// Issue #221: `clear()` deletes on the main context, and History is a
    /// `@Query`. A live `@Query` hosted in a real window must see the rows
    /// arrive and then go, with no relaunch.
    @Test func aLiveQuerySeesClearEmptyTheList() async throws {
        let box = QueryProbeBox()
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 200, height: 200), styleMask: [.titled],
            backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(
            rootView: QueryProbe(box: box).modelContainer(history.container))
        window.orderFront(nil)
        defer { window.close() }

        history.add(record(storedID: nil))
        history.add(record(storedID: nil))
        try await waitUntil("the query to show both records") { box.count == 2 }

        history.clear()
        try await waitUntil("the query to show an empty list") { box.count == 0 }
    }

    /// Polls on the main actor until `condition` holds, so SwiftUI gets its
    /// update passes in between, and fails after a deadline.
    private func waitUntil(
        _ what: String, sourceLocation: SourceLocation = #_sourceLocation,
        _ condition: () -> Bool
    ) async throws {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: .seconds(30))
        while !condition(), clock.now < deadline {
            try await Task.sleep(for: .milliseconds(5))
        }
        try #require(condition(), "timed out waiting for \(what)", sourceLocation: sourceLocation)
    }
    #endif
}

#if os(macOS)
@MainActor private final class QueryProbeBox {
    var count: Int?

    func report(_ count: Int) { self.count = count }
}

/// Reports how many records its `@Query` holds each time `body` runs.
private struct QueryProbe: View {
    @Query private var records: [TransferRecord]
    let box: QueryProbeBox

    var body: some View {
        let _ = box.report(records.count)
        Color.clear
    }
}
#endif
