import AppIntents
import Foundation
import OSLog
import Observation
import SwiftData

/// History as entities: what Shortcuts queries and what Spotlight indexes.
///
/// One policy governs both, and it is the **Save Transfer History** setting.
/// While it is off nothing is indexed, the index is emptied, and every query
/// answers with nothing, the same rule as the widget's empty line
/// (`design/platforms.md`, "Widgets"). Records saved before the user turned it
/// off stay in History until deleted, as that setting's footer promises, but
/// they are not offered outside the app.
///
/// The index follows the store: a saved record is indexed, a deleted one is
/// removed, a clear empties the index. The index is rebuilt in full at launch
/// and when the setting is turned on, so a record whose removal never finished
/// (the app was killed first) cannot linger.
@MainActor
final class HistoryEntityStore: HistoryChangeObserver {
    private static let log = Logger(subsystem: "com.bakirgdev.CrocApp", category: "spotlight")

    /// Newest first. History keeps at most `TransferRecord.maxRecords`.
    private static let suggestionCount = 10

    private let container: ModelContainer
    private let settings: AppSettings
    private let index: (any HistoryIndexing)?

    /// The index is changed by one operation at a time, in the order the
    /// changes happened: an add followed at once by a delete must not run
    /// backwards.
    private var tail: Task<Void, Never>?

    /// - Parameter index: nil leaves Spotlight alone (a harness run, whose
    ///   history lives in memory and is not the user's).
    init(container: ModelContainer, settings: AppSettings, index: (any HistoryIndexing)?) {
        self.container = container
        self.settings = settings
        self.index = index
    }

    /// Wires the store into the app: Shortcuts finds it as a dependency, and
    /// `history` tells it of every change. Called once, from `CrocAppApp.init`.
    @discardableResult
    static func install(for history: HistoryStore, settings: AppSettings, indexed: Bool)
        -> HistoryEntityStore
    {
        let store = HistoryEntityStore(
            container: history.container, settings: settings,
            index: indexed ? SpotlightHistoryIndex() : nil)
        history.observer = store
        AppDependencyManager.shared.add(dependency: store)
        store.start()
        return store
    }

    func start() {
        observeSetting()
        rebuild()
    }

    // MARK: - Queries

    var isEnabled: Bool { settings.saveTransferHistory }

    func entities(for ids: [String]) -> [HistoryEntity] {
        let wanted = Set(ids)
        return all().filter { wanted.contains($0.id) }
    }

    func suggested() -> [HistoryEntity] {
        Array(all().prefix(Self.suggestionCount))
    }

    func entities(matching text: String) -> [HistoryEntity] {
        all().filter { $0.matches(text) }
    }

    /// Every record as an entity, newest first; nothing while the setting is off.
    func all() -> [HistoryEntity] {
        guard isEnabled else { return [] }
        var descriptor = FetchDescriptor<TransferRecord>(
            sortBy: [SortDescriptor(\.date, order: .reverse)])
        // The bookmarks are the heavy part of a record and no entity reads them.
        descriptor.propertiesToFetch = [
            \.date, \.isSend, \.statusRaw, \.isText, \.fileCount, \.totalBytes, \.names,
        ]
        do {
            return try container.mainContext.fetch(descriptor).compactMap(HistoryEntity.init)
        } catch {
            Self.log.error(
                "entity fetch failed: \(String(describing: error), privacy: .public)")
            return []
        }
    }

    // MARK: - Keeping the index in step

    func historyDidAdd(_ record: TransferRecord) {
        guard isEnabled, let entity = HistoryEntity(record: record) else { return }
        enqueue("index") { try await $0.index([entity]) }
    }

    func historyDidRemove(_ ids: [PersistentIdentifier]) {
        let ids = ids.compactMap(HistoryEntityID.string)
        enqueue("remove") { try await $0.remove(ids: ids) }
    }

    func historyDidClear() {
        enqueue("clear") { try await $0.removeAll() }
    }

    /// Replaces the whole index with the current history, or empties it while
    /// the setting is off.
    private func rebuild() {
        let entities = all()
        enqueue("rebuild") {
            try await $0.removeAll()
            if !entities.isEmpty { try await $0.index(entities) }
        }
    }

    private func observeSetting() {
        withObservationTracking {
            _ = settings.saveTransferHistory
        } onChange: { [weak self] in
            // onChange runs before the new value lands: read it on the next turn.
            Task { @MainActor in
                self?.rebuild()
                self?.observeSetting()
            }
        }
    }

    private func enqueue(
        _ operation: String, _ work: @escaping @Sendable (any HistoryIndexing) async throws -> Void
    ) {
        guard let index else { return }
        let previous = tail
        tail = Task {
            await previous?.value
            do {
                try await work(index)
            } catch {
                // A failed index update loses a search result, never a record.
                Self.log.error(
                    "spotlight \(operation, privacy: .public) failed: \(String(describing: error), privacy: .public)"
                )
            }
        }
    }

    /// Returns once every queued index change has run.
    func settled() async {
        await tail?.value
    }
}

// MARK: - Shortcuts

extension HistoryEntityStore {
    /// One filter of a Shortcuts "Find Transfers" action.
    nonisolated struct Filter: Sendable {
        let matches: @Sendable (HistoryEntity) -> Bool
    }

    /// The entities that pass `filters` (all of them for `.and`, any for `.or`),
    /// in date order, at most `limit`.
    func entities(
        matching filters: [Filter], mode: EntityQueryComparatorMode, newestFirst: Bool,
        limit: Int?
    ) -> [HistoryEntity] {
        var found = all().filter { entity in
            guard !filters.isEmpty else { return true }
            return mode == .and
                ? filters.allSatisfy { $0.matches(entity) }
                : filters.contains { $0.matches(entity) }
        }
        if !newestFirst { found.reverse() }
        if let limit { found = Array(found.prefix(limit)) }
        return found
    }
}
