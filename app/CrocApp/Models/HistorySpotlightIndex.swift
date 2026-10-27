import AppIntents
import CoreSpotlight
import Foundation
import OSLog

/// The Spotlight index of History, as `HistoryEntityStore` drives it. A
/// protocol so the tests record the calls and never touch the real index.
nonisolated protocol HistoryIndexing: Sendable {
    func index(_ entities: [HistoryEntity]) async throws
    func remove(ids: [String]) async throws
    func removeAll() async throws
}

/// The system index. A named index, not the default one: Apple's guidance is
/// to keep the default for prototyping only (App Intents, "Making app
/// entities available in Spotlight"). The index is on the device; it holds the
/// entity's name, summary, file names and date, and never a code phrase or the
/// code hint (`HistoryEntity`).
nonisolated struct SpotlightHistoryIndex: HistoryIndexing {
    static let indexName = "CrocAppHistory"

    private static let log = Logger(subsystem: "com.bakirgdev.CrocApp", category: "spotlight")

    /// The name the app uses; a test passes its own so it never touches this one.
    var name = Self.indexName

    private var index: CSSearchableIndex { CSSearchableIndex(name: name) }

    func index(_ entities: [HistoryEntity]) async throws {
        guard !entities.isEmpty, available else { return }
        try await index.indexAppEntities(entities)
    }

    func remove(ids: [String]) async throws {
        guard !ids.isEmpty, available else { return }
        try await index.deleteAppEntities(identifiedBy: ids, ofType: HistoryEntity.self)
    }

    func removeAll() async throws {
        guard available else { return }
        try await index.deleteAppEntities(ofType: HistoryEntity.self)
    }

    /// Not every device can index (`CSSearchableIndex.isIndexingAvailable`):
    /// there is then nothing to keep in step, which is not a failure.
    private var available: Bool {
        let available = CSSearchableIndex.isIndexingAvailable()
        if !available { Self.log.info("indexing unavailable on this device") }
        return available
    }
}
