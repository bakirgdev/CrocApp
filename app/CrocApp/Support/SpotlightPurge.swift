import CoreSpotlight
import Foundation
import OSLog

/// 1.3.0 removed Spotlight indexing; people who had it on still have file names
/// in the system index, so it is emptied once.
enum SpotlightPurge {
    private static let log = Logger(subsystem: "com.bakirgdev.CrocApp", category: "spotlight")

    static let doneKey = "spotlightIndexPurged"

    /// Runs `deleteAll` until it succeeds once; a failure is logged and tried
    /// again at the next launch.
    static func runOnce(
        storage: any SettingsStorage = UserDefaults.standard,
        deleteAll: () async throws -> Void = {
            try await CSSearchableIndex(name: "CrocAppHistory").deleteAllSearchableItems()
        }
    ) async {
        guard storage.object(forKey: doneKey) == nil else { return }
        do {
            try await deleteAll()
            storage.set(true, forKey: doneKey)
        } catch {
            log.error("spotlight purge failed: \(String(describing: error), privacy: .public)")
        }
    }
}
