import Foundation
import CrocKit

/// Launch-argument harness for scripted verification.
///   --auto-receive CODE            receive into Documents, auto-accept
///   --auto-send PATH CODE          send PATH with custom code CODE
/// Writes verify-result.txt ("ok success=<bool>" | "error <msg>") to Documents.
enum AutoVerify {
    @MainActor
    static func runIfRequested(controller: TransferController) async {
        let args = ProcessInfo.processInfo.arguments
        let docs = OutputFolderStore.defaultFolder
        let resultURL = docs.appendingPathComponent("verify-result.txt")

        if let i = args.firstIndex(of: "--auto-receive"), i + 1 < args.count {
            controller.startReceive(code: args[i + 1], into: docs, folderIsScoped: false)
            await watch(controller, resultURL: resultURL, autoAccept: true)
        } else if let i = args.firstIndex(of: "--auto-send"), i + 2 < args.count {
            controller.startSend(urls: [URL(fileURLWithPath: args[i + 1])], customCode: args[i + 2])
            await watch(controller, resultURL: resultURL, autoAccept: false)
        }
    }

    @MainActor
    private static func watch(_ controller: TransferController, resultURL: URL, autoAccept: Bool) async {
        while true {
            try? await Task.sleep(for: .milliseconds(200))
            switch controller.phase {
            case .incoming where autoAccept:
                controller.respond(accept: true)
            case .done(let summary, _):
                try? "ok success=\(summary.success)".write(to: resultURL, atomically: true, encoding: .utf8)
                return
            case .failed(let message):
                try? "error \(message)".write(to: resultURL, atomically: true, encoding: .utf8)
                return
            default:
                break
            }
        }
    }
}
