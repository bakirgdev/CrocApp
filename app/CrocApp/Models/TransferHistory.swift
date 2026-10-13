import Foundation
import OSLog
import Observation
import SwiftData

/// One finished (or failed) transfer (F12). Local only — never synced.
/// Privacy: stores at most `maxNames` file names, a code *hint*
/// (`TransferController.codeHint`), and, for sends, bookmarks so history can
/// re-stage the same files. Never file contents, never the full code phrase.
/// Bookmarks are stored only for sends of at most `maxBookmarks` items and
/// only when every bookmark resolves — all-or-nothing at capture time. Re-send
/// still drops files that have vanished since (the user sees the staged list
/// before sending).
@Model
final class TransferRecord {
    static let maxNames = 20
    static let maxBookmarks = 200
    /// Retention cap enforced by `HistoryStore.add()`: oldest records beyond
    /// this count are pruned. Send records can each carry up to
    /// `maxBookmarks` bookmark blobs, so an unbounded history grows without
    /// limit otherwise.
    static let maxRecords = 300

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

    /// "Send Again" needs the original files back, which only resolvable
    /// bookmarks give. Text sends have no files to resolve.
    var canResend: Bool { isSend && !isText && !bookmarks.isEmpty }

    init(
        isSend: Bool, status: Status, isText: Bool, fileCount: Int,
        totalBytes: Int64, names: [String], codeHint: String, bookmarks: [Data]
    ) {
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
    private static let log = Logger(subsystem: "com.bakirgdev.CrocApp", category: "history")

    let container: ModelContainer

    init(container: ModelContainer) {
        self.container = container
    }

    static func makeContainer(inMemory: Bool) -> ModelContainer {
        do {
            let config = ModelConfiguration(isStoredInMemoryOnly: inMemory)
            return try ModelContainer(for: TransferRecord.self, configurations: config)
        } catch {
            Self.log.error(
                "history store failed to open, using memory only: \(String(describing: error), privacy: .public)"
            )
            // Corrupt store beats a launch crash: fall back to memory-only.
            let config = ModelConfiguration(isStoredInMemoryOnly: true)
            // try! is deliberate, the only one in the app: this schema is
            // fixed and ours, and an in-memory store has no failure mode a
            // disk-backed one has (no corruption, no existing file) -- if
            // this throws, the environment itself is broken (e.g. out of
            // memory) and there is no fallback left that would leave the
            // app in a working state anyway.
            // swift-format-ignore: NeverUseForceTry
            return try! ModelContainer(for: TransferRecord.self, configurations: config)
        }
    }

    func add(_ record: TransferRecord) {
        container.mainContext.insert(record)
        save("add")
        pruneToRetentionCap()
    }

    /// Delete oldest records beyond `TransferRecord.maxRecords`. Runs on the
    /// main actor at the end of every transfer, so keep it to two cheap
    /// fetches (a count, then a limited oldest-first fetch) rather than
    /// loading the whole table.
    private func pruneToRetentionCap() {
        let cap = TransferRecord.maxRecords
        let overflow = recordCount() - cap
        guard overflow > 0 else { return }
        var descriptor = FetchDescriptor<TransferRecord>(
            sortBy: [SortDescriptor(\.date, order: .forward)])
        descriptor.fetchLimit = overflow
        let stale: [TransferRecord]
        do {
            stale = try container.mainContext.fetch(descriptor)
        } catch {
            Self.log.error(
                "history prune fetch failed: \(String(describing: error), privacy: .public)")
            return
        }
        for record in stale { container.mainContext.delete(record) }
        save("prune")
    }

    func delete(_ record: TransferRecord) {
        container.mainContext.delete(record)
        save("delete")
    }

    func clear() {
        do {
            try container.mainContext.delete(model: TransferRecord.self)
        } catch {
            Self.log.error("history clear failed: \(String(describing: error), privacy: .public)")
        }
        save("clear")
    }

    func recordCount() -> Int {
        do {
            return try container.mainContext.fetchCount(FetchDescriptor<TransferRecord>())
        } catch {
            Self.log.error("history count failed: \(String(describing: error), privacy: .public)")
            return 0
        }
    }

    private func save(_ operation: String) {
        do {
            try container.mainContext.save()
        } catch {
            Self.log.error(
                "history \(operation, privacy: .public) save failed: \(String(describing: error), privacy: .public)"
            )
        }
    }
}
