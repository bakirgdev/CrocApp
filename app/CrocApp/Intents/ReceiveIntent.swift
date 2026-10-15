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
        guard !controller.isActive else { throw TransferIntentError.busy }
        let started = Date()
        let folder = outputFolder.url
        AppRouter.shared.openReceive()
        switch link {
        case .code(let code):
            controller.startReceive(
                code: code, into: folder, folderIsScoped: outputFolder.isUserSelected)
        case .stored(let url):
            controller.startStoreReceive(
                link: url, into: folder, folderIsScoped: outputFolder.isUserSelected)
        }
        let text = try await controller.awaitReceive()
        var urls = ReceivedFileLocator.locate(
            names: controller.offeredFileNames, in: folder, since: started)
        if let text { urls.append(try IntentStaging.textFile(text)) }
        let files = urls.map { IntentFile(fileURL: $0) }
        return .result(
            value: files,
            dialog: files.count == 1 ? "Received 1 item." : "Received \(files.count) items.")
    }
}
