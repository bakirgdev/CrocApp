import AppIntents
import Foundation
import OSLog
import Observation
import SwiftData

/// History as entities: what Shortcuts queries and what Spotlight indexes.
///
/// Two settings govern them. **Save Transfer History** governs both: while it
/// is off every query answers with nothing, the same rule as the widget's empty
/// line (`design/platforms.md`, "Widgets"), and nothing is indexed. Records
/// saved before the user turned it off stay in History until deleted, as that
/// setting's footer promises, but they are not offered outside the app.
/// **Show History in Spotlight** (off by default) governs the index alone:
/// names reach the system index only while both settings are on, and turning
/// either off empties it.
///
/// The index follows the store: a saved record is indexed, a deleted one is
/// removed, a clear empties the index. The index is rebuilt in full at launch
/// and whenever a setting changes, so a record whose removal never finished
/// (the app was killed first) cannot linger. After a failed index call the next
/// change rebuilds it in full as well.
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

    /// Set when an index call failed: the next change rebuilds the index in
    /// full instead of applying one more delta to an index of unknown content.
    private var needsRebuild = false

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
            index: indexed && !isHostingTests ? SpotlightHistoryIndex() : nil)
        history.observer = store
        AppDependencyManager.shared.add(dependency: store)
        store.start()
        return store
    }

    /// A unit-test run launches the real app as its host. That launch must not
    /// write the developer's Spotlight index.
    static var isHostingTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    func start() {
        observeSetting()
        rebuild()
    }

    // MARK: - Queries

    var isEnabled: Bool { settings.saveTransferHistory }

    /// Whether names may be in the system index.
    private var isIndexing: Bool {
        settings.saveTransferHistory && settings.indexHistoryInSpotlight
    }

    func entities(for ids: [String]) -> [HistoryEntity] {
        // Compared as identifiers, not as text: an id kept by Spotlight or a
        // saved shortcut may have been written by another OS version.
        let wanted = Set(ids.compactMap(HistoryEntityID.identifier))
        return all().filter {
            HistoryEntityID.identifier(from: $0.id).map(wanted.contains) ?? false
        }
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
        guard !retryIfNeeded() else { return }
        guard isIndexing, let entity = HistoryEntity(record: record) else { return }
        enqueue("index") { try await $0.index([entity]) }
    }

    func historyDidRemove(_ ids: [PersistentIdentifier]) {
        guard !retryIfNeeded() else { return }
        let ids = ids.compactMap(HistoryEntityID.string)
        enqueue("remove") { try await $0.remove(ids: ids) }
    }

    func historyDidClear() {
        guard !retryIfNeeded() else { return }
        enqueue("clear") { try await $0.removeAll() }
    }

    /// A rebuild covers the change that triggered it, so the caller stops.
    private func retryIfNeeded() -> Bool {
        guard needsRebuild else { return false }
        Self.log.info("spotlight index retried in full after a failure")
        rebuild()
        return true
    }

    /// Replaces the whole index with the current history, or empties it while
    /// either setting is off.
    private func rebuild() {
        needsRebuild = false
        let entities = isIndexing ? all() : []
        enqueue("rebuild") {
            try await $0.removeAll()
            if !entities.isEmpty { try await $0.index(entities) }
        }
    }

    private func observeSetting() {
        withObservationTracking {
            _ = settings.saveTransferHistory
            _ = settings.indexHistoryInSpotlight
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
                self.needsRebuild = true
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
