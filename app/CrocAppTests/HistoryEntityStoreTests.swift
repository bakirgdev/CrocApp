import AppIntents
import Foundation
import SwiftData
import Synchronization
import Testing

@testable import CrocApp

/// Records what the store asks of the Spotlight index. The real index is never
/// touched: a test run must not put rows in the developer's Spotlight.
private final class RecordingIndex: HistoryIndexing {
    enum Call: Equatable {
        case index(names: [String])
        case remove(count: Int)
        case removeAll
    }

    private let recorded = Mutex<[Call]>([])
    private let failures = Mutex<Int>(0)

    var calls: [Call] { recorded.withLock { $0 } }

    /// Makes the next `count` calls throw.
    func failNext(_ count: Int) { failures.withLock { $0 = count } }

    private func record(_ call: Call) throws {
        recorded.withLock { $0.append(call) }
        let fails = failures.withLock { remaining -> Bool in
            defer { remaining = max(0, remaining - 1) }
            return remaining > 0
        }
        if fails { throw Failure() }
    }

    struct Failure: Error {}

    func index(_ entities: [HistoryEntity]) async throws {
        try record(.index(names: entities.map(\.name)))
    }

    func remove(ids: [String]) async throws { try record(.remove(count: ids.count)) }
    func removeAll() async throws { try record(.removeAll) }
}

/// The Save Transfer History setting governs everything History offers outside
/// the app: the Spotlight index follows the store while it is on, and is gone
/// while it is off.
@MainActor @Suite struct HistoryEntityStoreTests {
    private let settings = AppSettings(storage: MemorySettingsStorage(), secrets: FakeSecretStore())
    private let history = HistoryStore(container: HistoryStore.makeContainer(inMemory: true))
    private let index = RecordingIndex()

    /// A store wired to `history`, started, and settled. `index` is what the
    /// app passes: the system index, or nil for a harness run.
    private func started(index: (any HistoryIndexing)?) async -> HistoryEntityStore {
        let store = HistoryEntityStore(
            container: history.container, settings: settings, index: index)
        history.observer = store
        store.start()
        await store.settled()
        return store
    }

    private func started() async -> HistoryEntityStore {
        await started(index: index)
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

    /// The setting is observed on the main actor; this waits for the rebuild it
    /// triggers to have run.
    private func settle(_ store: HistoryEntityStore, after calls: Int) async {
        for _ in 0..<200 where index.calls.count < calls {
            try? await Task.sleep(for: .milliseconds(5))
        }
        await store.settled()
    }

    // MARK: - The index follows the store

    @Test func launchEmptiesTheIndexAndIndexesWhatIsThere() async {
        addRecord("old.txt")
        _ = await started()
        #expect(index.calls == [.removeAll, .index(names: ["old.txt"])])
    }

    @Test func aSavedRecordIsIndexed() async {
        let store = await started()
        addRecord("new.txt")
        await store.settled()
        #expect(index.calls.last == .index(names: ["new.txt"]))
    }

    @Test func aDeletedRecordIsRemoved() async {
        let store = await started()
        let record = addRecord("gone.txt")
        history.delete(record)
        await store.settled()
        #expect(index.calls.suffix(2) == [.index(names: ["gone.txt"]), .remove(count: 1)])
    }

    @Test func clearingHistoryEmptiesTheIndex() async {
        let store = await started()
        addRecord("a.txt")
        addRecord("b.txt")
        history.clear()
        await store.settled()
        #expect(index.calls.last == .removeAll)
        #expect(store.all().isEmpty)
    }

    @Test func recordsPrunedBeyondTheCapAreRemoved() async {
        let store = await started()
        for number in 0...TransferRecord.maxRecords {
            addRecord("file-\(number).txt", daysAgo: Double(TransferRecord.maxRecords - number))
        }
        await store.settled()
        #expect(index.calls.last == .remove(count: 1))
        #expect(history.recordCount() == TransferRecord.maxRecords)
    }

    // MARK: - The setting

    @Test func nothingIsIndexedWhileTheSettingIsOff() async {
        settings.saveTransferHistory = false
        let store = await started()
        #expect(index.calls == [.removeAll], "launch only clears the index")
        addRecord("hidden.txt")
        await store.settled()
        #expect(index.calls == [.removeAll])
    }

    @Test func turningTheSettingOffEmptiesTheIndex() async {
        addRecord("a.txt")
        let store = await started()
        let before = index.calls.count
        settings.saveTransferHistory = false
        await settle(store, after: before + 1)
        #expect(Array(index.calls.dropFirst(before)) == [.removeAll])
    }

    @Test func turningTheSettingBackOnIndexesTheHistoryAgain() async {
        addRecord("a.txt")
        settings.saveTransferHistory = false
        let store = await started()
        let before = index.calls.count
        settings.saveTransferHistory = true
        await settle(store, after: before + 2)
        #expect(Array(index.calls.dropFirst(before)) == [.removeAll, .index(names: ["a.txt"])])
    }

    @Test func aDeleteWhileTheSettingIsOffStillReachesTheIndex() async {
        let record = addRecord("a.txt")
        settings.saveTransferHistory = false
        let store = await started()
        history.delete(record)
        await store.settled()
        #expect(index.calls.last == .remove(count: 1))
    }

    // MARK: - Failure

    @Test func aFailedIndexCallDoesNotStopTheNextOne() async {
        let store = await started()
        index.failNext(1)
        addRecord("first.txt")
        addRecord("second.txt")
        await store.settled()
        #expect(index.calls.suffix(2) == [.index(names: ["first.txt"]), .index(names: ["second.txt"])])
        #expect(history.recordCount() == 2, "History keeps the record")
    }

    @Test func theTestHostLeavesTheSystemIndexAlone() {
        #expect(HistoryEntityStore.isHostingTests)
    }

    @Test func aHarnessRunHasNoIndexAndStillWorks() async {
        let store = await started(index: nil)
        addRecord("a.txt")
        await store.settled()
        #expect(store.all().count == 1)
        #expect(index.calls.isEmpty)
    }

    // MARK: - Queries

    @Test func queriesAnswerNewestFirstAndFindById() async throws {
        let store = await started()
        addRecord("old.txt", daysAgo: 3)
        let recent = addRecord("recent.txt", daysAgo: 1)
        #expect(store.all().map(\.name) == ["recent.txt", "old.txt"])
        #expect(store.suggested().map(\.name) == ["recent.txt", "old.txt"])
        let id = try #require(HistoryEntityID.string(for: recent.persistentModelID))
        #expect(store.entities(for: [id, "unknown"]).map(\.name) == ["recent.txt"])
    }

    @Test func aTextSearchMatchesFileNames() async {
        let store = await started()
        addRecord("Holiday.jpg")
        addRecord("invoice.pdf")
        #expect(store.entities(matching: "holiday").map(\.name) == ["Holiday.jpg"])
        #expect(store.entities(matching: "zzz").isEmpty)
    }

    @Test func queriesAnswerNothingWhileTheSettingIsOff() async throws {
        let store = await started()
        let record = addRecord("a.txt")
        let id = try #require(HistoryEntityID.string(for: record.persistentModelID))
        settings.saveTransferHistory = false
        #expect(store.all().isEmpty)
        #expect(store.suggested().isEmpty)
        #expect(store.entities(for: [id]).isEmpty)
        #expect(store.entities(matching: "a").isEmpty)
    }

    @Test func filtersCombineByModeAndHonourOrderAndLimit() async {
        let store = await started()
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
