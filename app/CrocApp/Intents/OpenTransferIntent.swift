import AppIntents
import SwiftData

/// Opens CrocApp at a found transfer's detail in History.
struct OpenTransferIntent: OpenIntent {
    static let title: LocalizedStringResource = "Open Transfer"
    static let description = IntentDescription("Opens CrocApp at a transfer in History.")
    static let supportedModes: IntentModes = .foreground

    @Parameter(title: "Transfer")
    var target: HistoryEntity

    @Dependency var store: HistoryEntityStore

    @MainActor
    func perform() async throws -> some IntentResult {
        if let record = store.records(for: [target.id]).first {
            AppRouter.shared.openHistory(record: record.persistentModelID)
        } else {
            AppRouter.shared.openHistory()
        }
        return .result()
    }
}
