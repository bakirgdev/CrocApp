import AppIntents

/// Opens CrocApp at History. This is what a tap on a Spotlight result runs,
/// and what Shortcuts offers for a found transfer. It opens the list, not the
/// record: the record's own screen has no route to open it yet (see
/// `docs/known-issues.md`, "History entities").
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

extension AppRouter {
    /// Shows History. Same busy rule as `openSend(with:)`: a transfer in
    /// progress keeps the screen, because the app never moves the user off a
    /// transfer on its own.
    func openHistory() {
        if !isBusy, path != [.history] { path = [.history] }
    }
}
