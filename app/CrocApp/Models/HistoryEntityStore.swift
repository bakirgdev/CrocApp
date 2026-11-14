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
        // Compared as identifiers, not as text: an id kept by a saved shortcut
        // may have been written by another OS version.
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
