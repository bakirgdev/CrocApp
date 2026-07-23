import Foundation
import CrocKit

/// Launch-argument harness for scripted verification.
///   --auto-receive CODE            receive into Documents, auto-accept
///   --auto-send PATH --code CODE   send PATH with custom code CODE
///   --auto-share-send CODE         send whatever's staged in the ShareInbox with custom code CODE
///   --local                        force croc local-only mode (LAN/sandbox listener check)
///   --no-compress                  disable croc compression (F15)
///   --ask                          require sender-side confirm before send (F19)
///   --relay ADDR                   use a custom relay address (F13); also disables local-only race
/// --auto-send takes its two values non-adjacently (separated by the --code
/// flag, not `--auto-send PATH CODE`): two bare positional arguments in a row
/// makes AppKit treat the launch as a file-open request and it never creates
/// the default window, so ContentView's .task (and this whole harness) never
/// runs -- confirmed via `sample` on the hung process (idle in NSApplication's
/// event loop, no window ever attached). Splitting them with a flag avoids it.
/// Writes verify-result.txt ("ok success=<bool>" | "error <msg>") to Documents.
enum AutoVerify {
    @MainActor
    static func runIfRequested(controller: TransferController) async {
        let args = ProcessInfo.processInfo.arguments
        // Harness overrides go through the real settings store, unpersisted.
        controller.settings.persist = false
        if args.contains("--local") { controller.settings.onlyLocal = true }
        if args.contains("--no-compress") { controller.settings.noCompress = true }
        if args.contains("--ask") { controller.settings.bothSidesConfirm = true }
        if let i = args.firstIndex(of: "--relay"), i + 1 < args.count {
            controller.settings.relayAddress = args[i + 1]
            // Kill the LAN race so success provably went through the relay.
            controller.harnessDisableLocal = true
        }
        // Harness contract: verify-result.txt + received files live in the
        // container Documents folder (verify-app-mac.sh reads it there),
        // independent of the app's user-facing default output folder.
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let resultURL = docs.appendingPathComponent("verify-result.txt")

        if let i = args.firstIndex(of: "--auto-receive"), i + 1 < args.count {
            controller.startReceive(code: args[i + 1], into: docs, folderIsScoped: false)
            await watch(controller, resultURL: resultURL, autoAccept: true)
        } else if let i = args.firstIndex(of: "--auto-send"), i + 1 < args.count,
                  let ci = args.firstIndex(of: "--code"), ci + 1 < args.count {
            controller.startSend(urls: [URL(fileURLWithPath: args[i + 1])], customCode: args[ci + 1])
            await watch(controller, resultURL: resultURL, autoAccept: false)
        } else if let i = args.firstIndex(of: "--auto-share-send"), i + 1 < args.count {
            let inbox = ShareInbox()
            inbox.refresh()
            guard !inbox.staged.isEmpty else {
                try? "error no staged files in share inbox".write(to: resultURL, atomically: true, encoding: .utf8)
                return
            }
            let urls = inbox.staged
            inbox.consumeManifest()
            controller.startSend(urls: urls, customCode: args[i + 1])
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
            case .confirmSend:
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
