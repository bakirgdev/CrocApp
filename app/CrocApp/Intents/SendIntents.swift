import AppIntents
import UniformTypeIdentifiers

/// Both send actions start a transfer on the app's one `TransferController`
/// and return its code as soon as croc has one. A transfer needs the app
/// running to its end, which on iOS lasts past the 30 s a background action
/// gets, so the actions run in the foreground.
struct SendFilesIntent: AppIntent {
    static let title: LocalizedStringResource = "Send Files with CrocApp"
    static let description = IntentDescription(
        "Sends files or folders with a croc code and returns the code. Keep CrocApp open until the transfer ends."
    )
    static let supportedModes: IntentModes = .foreground

    @Parameter(title: "Files", supportedContentTypes: [.item])
    var files: [IntentFile]

    @Dependency var controller: TransferController

    static var parameterSummary: some ParameterSummary {
        Summary("Send \(\.$files) with CrocApp")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        guard !files.isEmpty else { throw TransferIntentError.nothingToSend }
        try controller.claimForIntent()
        IntentStaging.sweep()
        let urls = try IntentStaging.urls(for: files)
        AppRouter.shared.path = [.send]
        controller.startSend(urls: urls, customCode: "")
        let code = try await controller.awaitCode()
        return .result(
            value: code,
            dialog: "The code is \(code). Keep CrocApp open until the transfer ends.")
    }
}

struct SendTextIntent: AppIntent {
    static let title: LocalizedStringResource = "Send Text with CrocApp"
    static let description = IntentDescription(
        "Sends text with a croc code and returns the code. Keep CrocApp open until the transfer ends."
    )
    static let supportedModes: IntentModes = .foreground

    @Parameter(title: "Text")
    var text: String

    @Dependency var controller: TransferController

    static var parameterSummary: some ParameterSummary {
        Summary("Send \(\.$text) with CrocApp")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        guard !text.isEmpty else { throw TransferIntentError.nothingToSend }
        try controller.claimForIntent()
        AppRouter.shared.path = [.send]
        controller.startSendText(text, customCode: "")
        let code = try await controller.awaitCode()
        return .result(
            value: code,
            dialog: "The code is \(code). Keep CrocApp open until the transfer ends.")
    }
}
