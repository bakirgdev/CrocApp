import CoreSpotlight
import Foundation
import Synchronization
import Testing

@testable import CrocApp

/// The real `CSSearchableIndex`, under a throwaway index name, so the app's own
/// index and the developer's Spotlight are untouched. It shows that an entity
/// reaches the system index and that a removal takes it out. The Spotlight
/// search UI is not driven.
@Suite(.serialized) nonisolated struct HistorySpotlightIndexTests {

    private func entity(_ name: String) -> HistoryEntity {
        HistoryEntity(
            id: "test-\(UUID().uuidString)", isSend: true, status: .completed, isText: false,
            fileCount: 1, totalBytes: 10, names: [name], date: .now)
    }

    /// The identifiers the index returns for items whose title is `title`.
    private func found(title: String, in _: String) async throws -> [String] {
        let context = CSSearchQueryContext()
        context.fetchAttributes = ["title"]
        let query = CSSearchQuery(
            queryString: "title == \"\(title)\"", queryContext: context)
        let ids = Mutex<[String]>([])
        query.foundItemsHandler = { @Sendable items in
            ids.withLock { $0.append(contentsOf: items.map(\.uniqueIdentifier)) }
        }
        // A query that never completes is cancelled, which fails the test
        // instead of hanging the host.
        nonisolated(unsafe) let running = query
        let watchdog = Task {
            try? await Task.sleep(for: .seconds(20))
            running.cancel()
        }
        defer { watchdog.cancel() }
        try await withCheckedThrowingContinuation { (done: CheckedContinuation<Void, Error>) in
            query.completionHandler = { @Sendable error in
                if let error { done.resume(throwing: error) } else { done.resume() }
            }
            query.start()
        }
        return ids.withLock { $0 }
    }

    @Test func anIndexedEntityIsFoundAndARemovedOneIsGone() async throws {
        guard CSSearchableIndex.isIndexingAvailable() else { return }
        let index = SpotlightHistoryIndex(name: "CrocAppTests-\(UUID().uuidString)")
        let title = "croc-test-\(UUID().uuidString)"
        let item = entity(title)
        defer { Task { try? await index.removeAll() } }

        try await index.index([item])
        let present = try await found(title: title, in: index.name)
        #expect(present.contains { $0.contains(item.id) }, "indexed: \(present)")

        try await index.remove(ids: [item.id])
        let gone = try await found(title: title, in: index.name)
        #expect(gone.isEmpty, "removed: \(gone)")
    }
}
