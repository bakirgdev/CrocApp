import Foundation
import SwiftData
import Observation

/// One finished (or failed) transfer (F12). Local only — never synced.
/// Privacy: stores at most `maxNames` file names, a code *hint* (first
/// segment only), and, for sends, bookmarks so history can re-stage the
/// same files. Never file contents, never the full code phrase.
/// Bookmarks are stored only for sends of at most `maxBookmarks` items and
/// only when every bookmark resolves — all-or-nothing at capture time. Re-send
/// still drops files that have vanished since (the user sees the staged list
/// before sending).
@Model
final class TransferRecord {
    static let maxNames = 20
    static let maxBookmarks = 200

    enum Status: String {
        case completed, failed, cancelled, declined
    }

    var date: Date
    var isSend: Bool
    var statusRaw: String
    var isText: Bool
    var fileCount: Int
    var totalBytes: Int64
    var names: [String]
    var codeHint: String
    var bookmarks: [Data]

    var status: Status { Status(rawValue: statusRaw) ?? .failed }

    init(isSend: Bool, status: Status, isText: Bool, fileCount: Int,
         totalBytes: Int64, names: [String], codeHint: String, bookmarks: [Data]) {
        self.date = Date()
        self.isSend = isSend
        self.statusRaw = status.rawValue
        self.isText = isText
        self.fileCount = fileCount
        self.totalBytes = totalBytes
        self.names = names
        self.codeHint = codeHint
        self.bookmarks = bookmarks
    }
}

/// Thin MainActor wrapper over the ModelContainer so TransferController can
/// write records without importing SwiftData views, and so harness runs can
/// swap in an in-memory store (AutoVerify must never pollute real history).
@MainActor
@Observable
final class HistoryStore {
    let container: ModelContainer

    init(container: ModelContainer) {
        self.container = container
    }

    static func makeContainer(inMemory: Bool) -> ModelContainer {
        do {
            let config = ModelConfiguration(isStoredInMemoryOnly: inMemory)
            return try ModelContainer(for: TransferRecord.self, configurations: config)
        } catch {
            // Corrupt store beats a launch crash: fall back to memory-only.
            let config = ModelConfiguration(isStoredInMemoryOnly: true)
            return try! ModelContainer(for: TransferRecord.self, configurations: config)
        }
    }

    func add(_ record: TransferRecord) {
        container.mainContext.insert(record)
        try? container.mainContext.save()
    }

    func delete(_ record: TransferRecord) {
        container.mainContext.delete(record)
        try? container.mainContext.save()
    }

    func clear() {
        try? container.mainContext.delete(model: TransferRecord.self)
        try? container.mainContext.save()
    }

    func recordCount() -> Int {
        (try? container.mainContext.fetchCount(FetchDescriptor<TransferRecord>())) ?? 0
    }
}
