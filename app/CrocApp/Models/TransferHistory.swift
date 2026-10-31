import Foundation
import OSLog
import Observation
import SwiftData

/// One finished (or failed) transfer. Local only — never synced.
/// Privacy: stores at most `maxNames` file names, a code *hint*
/// (`CodeHint`; only the server host for a stored link),
/// and, for sends, bookmarks so history can re-stage the same files. Never
/// file contents, never the full code phrase, never a stored link or token.
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
    /// Stored uploads only: the server's id for the upload, which keys
    /// its receipt in `StoredTransferVault`. These three are optional so
    /// stores written before stored transfers migrate without a schema step.
    var storedID: String?
    var expiresAt: Date?
    var revokedAt: Date?

    var status: Status { Status(rawValue: statusRaw) ?? .failed }

    /// "Send Again" needs the original files back, which only resolvable
    /// bookmarks give. Text sends have no files to resolve.
    var canResend: Bool { isSend && !isText && !bookmarks.isEmpty }

    init(
        isSend: Bool, status: Status, isText: Bool, fileCount: Int,
        totalBytes: Int64, names: [String], codeHint: String, bookmarks: [Data],
        storedID: String? = nil, expiresAt: Date? = nil
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
        self.storedID = storedID
        self.expiresAt = expiresAt
    }
}

/// Told once a change to the store has been saved, so a Spotlight index can
/// follow it (`HistoryEntityStore`). Never told of a change that failed to save.
@MainActor
protocol HistoryChangeObserver: AnyObject {
    func historyDidAdd(_ record: TransferRecord)
    func historyDidRemove(_ ids: [PersistentIdentifier])
    func historyDidClear()
    /// The user deleted one record (a prune is `historyDidRemove` alone).
    func historyDidDelete()
}

extension HistoryChangeObserver {
    func historyDidDelete() {}
}

/// Thin MainActor wrapper over the ModelContainer so TransferController can
/// write records without importing SwiftData views, and so harness runs can
/// swap in an in-memory store (AutoVerify must never pollute real history).
@MainActor
@Observable
final class HistoryStore {
    private static let log = Logger(subsystem: "com.bakirgdev.CrocApp", category: "history")

    let container: ModelContainer
    @ObservationIgnored var observers: [any HistoryChangeObserver] = []
    /// Replaces the context save; a test sets it to make a save fail.
    @ObservationIgnored var saveOverride: (() throws -> Void)?

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
            // Crashing here is deliberate: this schema is fixed and ours, and
            // an in-memory store has no failure mode a disk-backed one has (no
            // corruption, no existing file) -- if this throws, the environment
            // itself is broken (e.g. out of memory) and there is no fallback
            // left that would leave the app in a working state anyway. The
            // message puts the error in the crash log.
            do {
                return try ModelContainer(for: TransferRecord.self, configurations: config)
            } catch {
                fatalError("history store failed to open in memory: \(error)")
            }
        }
    }

    func add(_ record: TransferRecord) {
        container.mainContext.insert(record)
        if save("add") { for observer in observers { observer.historyDidAdd(record) } }
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
        let ids = stale.map(\.persistentModelID)
        for record in stale { container.mainContext.delete(record) }
        if save("prune") { for observer in observers { observer.historyDidRemove(ids) } }
    }

    /// The record of the stored upload `storedID`, or nil when history holds
    /// none (deleted, cleared, or Save Transfer History was off).
    func record(storedID: String) -> TransferRecord? {
        var descriptor = FetchDescriptor<TransferRecord>(
            predicate: #Predicate { $0.storedID == storedID })
        descriptor.fetchLimit = 1
        do {
            return try container.mainContext.fetch(descriptor).first
        } catch {
            Self.log.error(
                "history stored-record fetch failed: \(String(describing: error), privacy: .public)"
            )
            return nil
        }
    }

    /// A record deleted while its revoke ran (a prune, or the user) has no
    /// context left, and writing to it would crash.
    func markRevoked(_ record: TransferRecord, at date: Date = .now) {
        guard record.modelContext != nil else { return }
        record.revokedAt = date
        save("revoke")
    }

    func delete(_ record: TransferRecord) {
        guard record.modelContext != nil else { return }
        let id = record.persistentModelID
        container.mainContext.delete(record)
        if save("delete") {
            for observer in observers {
                observer.historyDidRemove([id])
                observer.historyDidDelete()
            }
        }
    }

    func clear() {
        var deleted = false
        do {
            try container.mainContext.delete(model: TransferRecord.self)
            deleted = true
        } catch {
            Self.log.error("history clear failed: \(String(describing: error), privacy: .public)")
        }
        if save("clear"), deleted { for observer in observers { observer.historyDidClear() } }
    }

    func recordCount() -> Int {
        do {
            return try container.mainContext.fetchCount(FetchDescriptor<TransferRecord>())
        } catch {
            Self.log.error("history count failed: \(String(describing: error), privacy: .public)")
            return 0
        }
    }

    /// False when the save failed, so a caller does not announce a change
    /// that never reached the store.
    @discardableResult
    private func save(_ operation: String) -> Bool {
        do {
            try saveOverride?() ?? container.mainContext.save()
            return true
        } catch {
            Self.log.error(
                "history \(operation, privacy: .public) save failed: \(String(describing: error), privacy: .public)"
            )
            return false
        }
    }
}
