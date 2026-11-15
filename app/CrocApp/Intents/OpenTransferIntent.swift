import AppIntents

/// Opens CrocApp at History. Shortcuts offers it for a found transfer. It opens
/// the list, not the record: the record's own screen has no route to open it
/// yet (issue #126).
struct OpenTransferIntent: OpenIntent {
    static let title: LocalizedStringResource = "Open Transfer"
    static let description = IntentDescription("Opens CrocApp at History.")
    static let supportedModes: IntentModes = .foreground

    @Parameter(title: "Transfer")
    var target: HistoryEntity

    @MainActor
    func perform() async throws -> some IntentResult {
        AppRouter.shared.openHistory()
        return .result()
    }
}
