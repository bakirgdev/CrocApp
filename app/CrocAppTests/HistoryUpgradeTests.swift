import Foundation
import SwiftData
import Testing

@testable import CrocApp

/// The 1.3.0 `TransferRecord`, stored property for stored property
/// (`git show v1.3.0:app/CrocApp/Models/TransferHistory.swift`), so a test can
/// write a store the way that build did. The entity name is the class name,
/// so it opens as today's `TransferRecord`.
private enum V130 {
    @Model final class TransferRecord {
        var date: Date
        var isSend: Bool
        var statusRaw: String
        var isText: Bool
        var fileCount: Int
        var totalBytes: Int64
        var names: [String]
        var codeHint: String
        var bookmarks: [Data]
        var storedID: String?
        var expiresAt: Date?
        var revokedAt: Date?

        init(
            date: Date, isSend: Bool, names: [String], bookmarks: [Data],
            storedID: String? = nil, expiresAt: Date? = nil
        ) {
            self.date = date
            self.isSend = isSend
            self.statusRaw = "completed"
            self.isText = false
            self.fileCount = names.count
            self.totalBytes = 10
            self.names = names
            self.codeHint = "wiry-…"
            self.bookmarks = bookmarks
            self.storedID = storedID
            self.expiresAt = expiresAt
        }
    }
}

/// The entity id 1.3.0 gave a record, encoded as that build encoded it.
func legacyEntityID(_ id: PersistentIdentifier) throws -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = .sortedKeys
    return try #require(String(data: try encoder.encode(id), encoding: .utf8))
}

/// A store 1.3.0 wrote opens in this build with every record, a `uuid` for
/// each, and its bookmarks moved where Send Again reads them. Opening falls
/// back to an empty memory-only store on failure (`HistoryStore.makeContainer`),
/// so a failed migration would look like lost history.
@MainActor @Suite struct HistoryUpgradeTests {
    private let folder = FileManager.default.temporaryDirectory
        .appending(path: "CrocAppHistoryUpgrade-\(UUID().uuidString)")
    private var storeURL: URL { folder.appending(path: "history.store") }

    private struct Written {
        let bookmarks: [Data]
        let sendID: String
    }

    /// Writes three 1.3.0 records: a file send with bookmarks, a receive, and
    /// a stored upload. Returns the send's bookmarks and 1.3.0 entity id.
    private func write130Store() throws -> Written {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let file = folder.appending(path: "report.txt")
        try Data("hi".utf8).write(to: file)
        let bookmarks = [
            try #require(SecurityScopedBookmark.create(for: file)), Data("second".utf8),
        ]
        let container = try ModelContainer(
            for: Schema([V130.TransferRecord.self]),
            configurations: ModelConfiguration(url: storeURL))
        let context = ModelContext(container)
        let send = V130.TransferRecord(
            date: Date(timeIntervalSince1970: 3), isSend: true, names: ["report.txt"],
            bookmarks: bookmarks)
        context.insert(send)
        context.insert(
            V130.TransferRecord(
                date: Date(timeIntervalSince1970: 2), isSend: false, names: ["got.txt"],
                bookmarks: []))
        context.insert(
            V130.TransferRecord(
                date: Date(timeIntervalSince1970: 1), isSend: true, names: ["linked.txt"],
                bookmarks: [], storedID: "up1", expiresAt: Date(timeIntervalSince1970: 9)))
        try context.save()
        return Written(bookmarks: bookmarks, sendID: try legacyEntityID(send.persistentModelID))
    }

    /// Opens the store with today's schema the way the app does, minus the
    /// memory-only fallback: a failed migration throws here.
    private func openStore() throws -> HistoryStore {
        HistoryStore(
            container: try ModelContainer(
                for: HistoryStore.schema, configurations: ModelConfiguration(url: storeURL)))
    }

    private func records(_ history: HistoryStore) throws -> [TransferRecord] {
        try history.container.mainContext.fetch(
            FetchDescriptor<TransferRecord>(sortBy: [SortDescriptor(\.date, order: .reverse)]))
    }

    private func bookmarkSets(_ history: HistoryStore) throws -> Int {
        try history.container.mainContext.fetchCount(FetchDescriptor<TransferBookmarks>())
    }

    @Test func a130StoreKeepsItsRecordsAndBookmarksAndSendsAgain() throws {
        defer { try? FileManager.default.removeItem(at: folder) }
        let written = try write130Store()

        let history = try openStore()
        let all = try records(history)

        #expect(all.map(\.names) == [["report.txt"], ["got.txt"], ["linked.txt"]])
        #expect(Set(all.compactMap(\.uuid)).count == 3, "every record gets its own uuid")
        let send = all[0]
        #expect(send.savedBookmarks?.data == written.bookmarks)
        #expect(send.bookmarks.isEmpty)
        #expect(send.canResend)
        #expect(!all[1].canResend)
        #expect(all[1].savedBookmarks == nil)
        #expect(all[2].storedID == "up1")
        #expect(all[2].expiresAt == Date(timeIntervalSince1970: 9))
        #expect(send.codeHint == "wiry-…")
        #expect(try bookmarkSets(history) == 1)

        let router = AppRouter()
        #expect(HistoryActions().resend(send, router: router))
        #expect(router.sendDraft.pickedURLs.map(\.lastPathComponent) == ["report.txt"])
    }

    @Test func aShortcutSavedBy130StillFindsItsTransfer() throws {
        defer { try? FileManager.default.removeItem(at: folder) }
        let written = try write130Store()

        let history = try openStore()
        let settings = AppSettings(storage: MemorySettingsStorage(), secrets: FakeSecretStore())
        let store = HistoryEntityStore(container: history.container, settings: settings)
        let send = try #require(try records(history).first)

        let found = store.entities(for: [written.sendID])
        #expect(found.map(\.name) == ["report.txt"])
        #expect(found.first?.id == send.uuid?.uuidString, "it answers with the new id")
        #expect(store.records(for: [written.sendID]).first === send)
    }

    @Test func theBackfillRunsOnce() throws {
        defer { try? FileManager.default.removeItem(at: folder) }
        let written = try write130Store()

        // Kept open: a record outlives its context only as long as the container.
        let first = try openStore()
        let uuids = try records(first).map(\.uuid)
        let reopened = try openStore()

        #expect(try records(reopened).map(\.uuid) == uuids)
        #expect(try bookmarkSets(reopened) == 1)
        #expect(try records(reopened).first?.savedBookmarks?.data == written.bookmarks)
    }

    /// More records than one backfill batch, then Clear History on a store on
    /// disk: the bookmarks must leave the file with their records.
    @Test func aLongHistoryBackfillsInBatchesAndClearsFromDisk() throws {
        defer { try? FileManager.default.removeItem(at: folder) }
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        do {
            let container = try ModelContainer(
                for: Schema([V130.TransferRecord.self]),
                configurations: ModelConfiguration(url: storeURL))
            let context = ModelContext(container)
            for number in 0..<25 {
                context.insert(
                    V130.TransferRecord(
                        date: Date(timeIntervalSince1970: Double(number)), isSend: true,
                        names: ["\(number).txt"], bookmarks: [Data("\(number)".utf8)]))
            }
            try context.save()
        }

        let history = try openStore()
        #expect(try records(history).allSatisfy { $0.uuid != nil && $0.bookmarks.isEmpty })
        #expect(try bookmarkSets(history) == 25)

        history.clear()
        let reopened = try openStore()
        #expect(reopened.recordCount() == 0)
        #expect(try bookmarkSets(reopened) == 0)
    }
}
