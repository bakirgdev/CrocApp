import AppIntents

/// Opens CrocApp at a found transfer's detail in History.
struct OpenTransferIntent: OpenIntent {
    static let title: LocalizedStringResource = "Open Transfer"
    static let description = IntentDescription("Opens CrocApp at a transfer in History.")
    static let supportedModes: IntentModes = .foreground

    @Parameter(title: "Transfer")
    var target: HistoryEntity

    @MainActor
    func perform() async throws -> some IntentResult {
        if let record = HistoryEntityID.identifier(from: target.id) {
            AppRouter.shared.openHistory(record: record)
        } else {
            AppRouter.shared.openHistory()
        }
        return .result()
    }
}
