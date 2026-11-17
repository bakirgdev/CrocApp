import AppIntents
import Foundation
import SwiftData
import Testing

@testable import CrocApp

/// Save Transfer History governs everything History offers outside the app:
/// while it is off every query answers with nothing.
@MainActor @Suite struct HistoryEntityStoreTests {
    private let settings = AppSettings(storage: MemorySettingsStorage(), secrets: FakeSecretStore())
    private let history = HistoryStore(container: HistoryStore.makeContainer(inMemory: true))

    private func makeStore() -> HistoryEntityStore {
        HistoryEntityStore(container: history.container, settings: settings)
    }

    @discardableResult
    private func addRecord(
        _ name: String, isSend: Bool = true, status: TransferRecord.Status = .completed,
        daysAgo: Double = 0
    ) -> TransferRecord {
        let record = TransferRecord(
            isSend: isSend, status: status, isText: false, fileCount: 1, totalBytes: 100,
            names: [name], codeHint: "wiry-…", bookmarks: [])
        record.date = Date(timeIntervalSinceNow: -daysAgo * 86_400)
        history.add(record)
        return record
    }

    @Test func queriesAnswerNewestFirstAndFindById() throws {
        let store = makeStore()
        addRecord("old.txt", daysAgo: 3)
        let recent = addRecord("recent.txt", daysAgo: 1)
        #expect(store.all().map(\.name) == ["recent.txt", "old.txt"])
        #expect(store.suggested().map(\.name) == ["recent.txt", "old.txt"])
        let id = try #require(recent.uuid?.uuidString)
        #expect(store.entities(for: [id, "unknown"]).map(\.name) == ["recent.txt"])
        // The id a shortcut saved by 1.3.0 holds.
        let oldID = try legacyEntityID(recent.persistentModelID)
        #expect(store.entities(for: [oldID]).map(\.id) == [id])
    }

    @Test func aTextSearchMatchesFileNames() {
        let store = makeStore()
        addRecord("Holiday.jpg")
        addRecord("invoice.pdf")
        #expect(store.entities(matching: "holiday").map(\.name) == ["Holiday.jpg"])
        #expect(store.entities(matching: "zzz").isEmpty)
    }

    @Test func queriesAnswerNothingWhileTheSettingIsOff() throws {
        let store = makeStore()
        let record = addRecord("a.txt")
        let id = try #require(record.uuid?.uuidString)
        settings.saveTransferHistory = false
        #expect(store.all().isEmpty)
        #expect(store.suggested().isEmpty)
        #expect(store.entities(for: [id]).isEmpty)
        #expect(store.entities(matching: "a").isEmpty)
    }

    @Test func filtersCombineByModeAndHonourOrderAndLimit() {
        let store = makeStore()
        addRecord("sent-new.txt", isSend: true, daysAgo: 1)
        addRecord("sent-old.txt", isSend: true, daysAgo: 5)
        addRecord("got.txt", isSend: false, daysAgo: 2)
        let sent = HistoryEntityStore.Filter { $0.direction == .sent }
        let recent = HistoryEntityStore.Filter { $0.date > Date(timeIntervalSinceNow: -3 * 86_400) }

        func names(_ filters: [HistoryEntityStore.Filter], _ mode: EntityQueryComparatorMode)
            -> [String]
        {
            store.entities(matching: filters, mode: mode, newestFirst: true, limit: nil).map(\.name)
        }
        #expect(names([sent, recent], .and) == ["sent-new.txt"])
        #expect(names([sent, recent], .or) == ["sent-new.txt", "got.txt", "sent-old.txt"])
        #expect(names([], .and).count == 3, "no filter means every transfer")
        #expect(
            store.entities(matching: [sent], mode: .and, newestFirst: false, limit: 1).map(\.name)
                == ["sent-old.txt"])
    }
}
