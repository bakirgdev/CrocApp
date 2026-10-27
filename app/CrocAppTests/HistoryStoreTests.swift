import Foundation
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
}
