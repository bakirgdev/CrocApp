import AppIntents
import Foundation
import OSLog
import SwiftData

/// History as entities, for Shortcuts to query.
///
/// **Save Transfer History** governs them: while it is off every query answers
/// with nothing, the same rule as the widget's empty line
/// (`docs/knowledge/app-ui-architecture.md`, "System surfaces"). Records saved
/// before the user turned it off stay in History until deleted, as that
/// setting's footer promises, but they are not offered outside the app.
@MainActor
final class HistoryEntityStore {
    private static let log = Logger(subsystem: "com.bakirgdev.CrocApp", category: "shortcuts")

    /// Newest first. History keeps at most `TransferRecord.maxRecords`.
    private static let suggestionCount = 10

    private let container: ModelContainer
    private let settings: AppSettings

    init(container: ModelContainer, settings: AppSettings) {
        self.container = container
        self.settings = settings
    }

    /// Shortcuts finds the store as a dependency. Called once, from `CrocAppApp.init`.
    static func install(for history: HistoryStore, settings: AppSettings) {
        let store = HistoryEntityStore(container: history.container, settings: settings)
        AppDependencyManager.shared.add(dependency: store)
    }

    // MARK: - Queries

    var isEnabled: Bool { settings.saveTransferHistory }

    func entities(for ids: [String]) -> [HistoryEntity] {
        records(for: ids).compactMap(HistoryEntity.init)
    }

    /// The records `ids` name, newest first: by `uuid`, or by the identifier a
    /// shortcut saved by 1.3.0 and earlier holds (`HistoryEntityID`). Compared
    /// as values, not as text: an old id may have been written by another OS
    /// version.
    func records(for ids: [String]) -> [TransferRecord] {
        let uuids = Set(ids.compactMap(UUID.init(uuidString:)))
        // An array, not a set: a decoded identifier equals the record's but
        // does not always hash the same.
        let legacy = ids.compactMap(HistoryEntityID.identifier)
        return records().filter {
            ($0.uuid.map(uuids.contains) ?? false) || legacy.contains($0.persistentModelID)
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
        records().compactMap(HistoryEntity.init)
    }

    /// Every record, newest first; nothing while the setting is off.
    private func records() -> [TransferRecord] {
        guard isEnabled else { return [] }
        let descriptor = FetchDescriptor<TransferRecord>(
            sortBy: [SortDescriptor(\.date, order: .reverse)])
        do {
            return try container.mainContext.fetch(descriptor)
        } catch {
            Self.log.error(
                "entity fetch failed: \(String(describing: error), privacy: .public)")
            return []
        }
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
