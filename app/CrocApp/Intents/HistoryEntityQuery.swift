import AppIntents
import Foundation

/// How Shortcuts and Siri find a past transfer: by id, by text (a file name),
/// and through a "Find Transfers" action filtered by date, direction, status
/// or name. All of it answers from `HistoryEntityStore`, so it answers with
/// nothing while Save Transfer History is off.
struct HistoryEntityQuery: EntityStringQuery, EntityPropertyQuery {
    @Dependency var store: HistoryEntityStore

    @MainActor
    func entities(for identifiers: [String]) async throws -> [HistoryEntity] {
        store.entities(for: identifiers)
    }

    @MainActor
    func suggestedEntities() async throws -> [HistoryEntity] {
        store.suggested()
    }

    @MainActor
    func entities(matching string: String) async throws -> [HistoryEntity] {
        store.entities(matching: string)
    }

    // Built once and never changed. AppIntents declares these types without
    // `Sendable`, and its metadata exporter only reads a stored declaration.
    nonisolated(unsafe) static let properties = QueryProperties {
        Property(\.$date) {
            LessThanComparator { date in .init { $0.date < date } }
            GreaterThanComparator { date in .init { $0.date > date } }
            IsBetweenComparator { from, to in .init { $0.date >= from && $0.date <= to } }
        }
        Property(\.$direction) {
            EqualToComparator { direction in .init { $0.direction == direction } }
        }
        Property(\.$status) {
            EqualToComparator { status in .init { $0.status == status } }
        }
        Property(\.$name) {
            ContainsComparator { text in .init { $0.matches(text) } }
        }
    }

    nonisolated(unsafe) static let sortingOptions = SortingOptions {
        SortableBy(\.$date)
    }

    // `sortedBy` is not Sendable, so it is read here and only the answer to
    // "newest first?" crosses to the main actor.
    nonisolated func entities(
        matching comparators: [HistoryEntityStore.Filter], mode: ComparatorMode,
        sortedBy: [Sort<HistoryEntity>], limit: Int?
    ) async throws -> [HistoryEntity] {
        let newestFirst = sortedBy.first.map { $0.order == .descending } ?? true
        return await find(comparators, mode: mode, newestFirst: newestFirst, limit: limit)
    }

    @MainActor
    private func find(
        _ comparators: [HistoryEntityStore.Filter], mode: ComparatorMode, newestFirst: Bool,
        limit: Int?
    ) -> [HistoryEntity] {
        store.entities(matching: comparators, mode: mode, newestFirst: newestFirst, limit: limit)
    }
}
