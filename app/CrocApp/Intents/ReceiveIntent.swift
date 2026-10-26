import AppIntents
import Foundation

/// Receives with a code or any link CrocApp opens (`TransferLink`), then
/// returns the files. The incoming-files prompt still appears in the app
/// unless auto-accept is on in Settings: a shortcut does not answer it.
struct ReceiveIntent: AppIntent {
    static let title: LocalizedStringResource = "Receive with CrocApp"
    static let description = IntentDescription(
        "Receives files with a croc code or a download link and returns them.")
    static let supportedModes: IntentModes = .foreground

    @Parameter(title: "Code or Link")
    var codeOrLink: String

    @Dependency var controller: TransferController
    @Dependency var outputFolder: OutputFolderStore

    static var parameterSummary: some ParameterSummary {
        Summary("Receive \(\.$codeOrLink) with CrocApp")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<[IntentFile]> & ProvidesDialog {
        guard let link = TransferLink.parse(codeOrLink) else {
            throw TransferIntentError.notACodeOrLink
        }
        try controller.claimForIntent()
        let started = Date()
        let folder = outputFolder.url
        AppRouter.shared.openReceive()
        switch link {
        case .code(let code):
            controller.start(
                .receive(code: code, folder: folder, folderIsScoped: outputFolder.isUserSelected))
        case .stored(let url):
            controller.start(
                .storedReceive(
                    link: url, folder: folder, folderIsScoped: outputFolder.isUserSelected))
        }
        let text = try await controller.awaitReceive()
        // The controller let go of a chosen folder when the transfer ended.
        let scoped = outputFolder.isUserSelected && folder.startAccessingSecurityScopedResource()
        defer { if scoped { folder.stopAccessingSecurityScopedResource() } }
        var urls = ReceivedFileLocator.locate(
            names: controller.offeredFileNames, in: folder, since: started)
        if let text { urls.append(try IntentStaging.textFile(text)) }
        let files = urls.map { IntentFile(fileURL: $0) }
        // One key: Localizable.xcstrings varies it by plural ("1 item", "3 items").
        return .result(value: files, dialog: "Received \(files.count) items.")
    }
}
