import CoreSpotlight
import Foundation
import OSLog

/// 1.3.0 removed Spotlight indexing; people who had it on still have file names
/// in the system index, so it is emptied at every live launch. An earlier build
/// can refill it after a downgrade, so a one-time purge would miss that.
enum SpotlightPurge {
    private static let log = Logger(subsystem: "com.bakirgdev.CrocApp", category: "spotlight")

    /// A failure is logged and tried again at the next launch.
    static func run(
        deleteAll: () async throws -> Void = {
            try await CSSearchableIndex(name: "CrocAppHistory").deleteAllSearchableItems()
        }
    ) async {
        do {
            try await deleteAll()
        } catch {
            log.error("spotlight purge failed: \(String(describing: error), privacy: .public)")
        }
    }
}
