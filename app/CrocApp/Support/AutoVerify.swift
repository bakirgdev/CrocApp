import CrocKit
import Foundation

/// Launch-argument harness for scripted verification.
///   --auto-receive CODE            receive into Documents, auto-accept
///   --auto-send PATH --code CODE   send PATH with custom code CODE
///   --auto-share-send CODE         send whatever's staged in the ShareInbox with custom code CODE
///   --local                        force croc local-only mode (LAN/sandbox listener check)
///   --no-compress                  disable croc compression (F15)
///   --ask                          require sender-side confirm before send (F19)
///   --relay ADDR                   use a custom relay address (F13); also disables local-only race
///   --hold                         park at the incoming prompt instead of auto-accepting
///   --screen ROUTE                 navigate to home|send|receive|settings|howItWorks|history|
///                                  onboarding on launch; combines with the --auto-* modes
///   --stage PATH                   preload PATH into the Send screen's staged list (repeatable)
///   --seed-history                 fill the (in-memory) history store with sample records
/// --auto-send takes its two values non-adjacently (separated by the --code
/// flag, not `--auto-send PATH CODE`): two bare positional arguments in a row
/// makes AppKit treat the launch as a file-open request and it never creates
/// the default window, so ContentView's .task (and this whole harness) never
/// runs -- confirmed via `sample` on the hung process (idle in NSApplication's
/// event loop, no window ever attached). Splitting them with a flag avoids it.
/// Writes verify-result.txt ("ok success=<bool>" | "error <msg>") to Documents.
/// --hold, --screen, --stage and --seed-history exist for
/// scripts/capture-screenshots.sh rather than the verify-*.sh runs: the harness
/// drives the controller directly, so without them the UI sits on HomeView
/// while the transfer runs behind it, and no screen holds still to photograph.
// The type itself must exist in Release too (CrocAppApp.swift and ContentView.swift
// call it unconditionally), but the harness it drives -- real transfers, settings
// overrides, writes into Documents -- must not ship. Only the bodies are #if DEBUG;
// in Release isHarnessRun is a hardcoded false and runIfRequested is a no-op.
enum AutoVerify {
    /// True when any --auto-* or --screen harness mode is active this launch.
    static var isHarnessRun: Bool {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        return args.contains("--auto-receive") || args.contains("--auto-send")
            || args.contains("--auto-share-send") || args.contains("--screen")
        #else
        return false
        #endif
    }

    /// True when `--screen onboarding` asked for the first-run sheet, which
    /// ContentView otherwise suppresses for every harness run.
    static var forcesOnboarding: Bool {
        #if DEBUG
        return requestedRoute() == "onboarding"
        #else
        return false
        #endif
    }

    #if DEBUG
    private static func requestedRoute() -> String? {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "--screen"), i + 1 < args.count else { return nil }
        return args[i + 1]
    }
    #endif

    @MainActor
    static func runIfRequested(controller: TransferController) async {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        guard isHarnessRun else { return }
        // Harness overrides go through the real settings store, unpersisted.
        // Reset first so a manual run's UserDefaults can't bleed into this run.
        controller.settings.persist = false
        controller.settings.resetToDefaults()
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

        // Navigation and history seeding are orthogonal to the transfer modes:
        // the verify-*.sh runs pass neither and keep asserting on files, not
        // pixels, while the capture script combines them freely.
        if let route = requestedRoute() { applyRoute(route, args: args) }
        if args.contains("--seed-history") { seedHistory(controller.history) }
        let hold = args.contains("--hold")

        if let i = args.firstIndex(of: "--auto-receive"), i + 1 < args.count {
            controller.startReceive(code: args[i + 1], into: docs, folderIsScoped: false)
            await watch(controller, resultURL: resultURL, autoAccept: !hold)
        } else if let i = args.firstIndex(of: "--auto-send"), i + 1 < args.count,
            let ci = args.firstIndex(of: "--code"), ci + 1 < args.count
        {
            controller.startSend(
                urls: [URL(fileURLWithPath: args[i + 1])], customCode: args[ci + 1])
            await watch(controller, resultURL: resultURL, autoAccept: false)
        } else if let i = args.firstIndex(of: "--auto-share-send"), i + 1 < args.count {
            let inbox = ShareInbox()
            inbox.refresh()
            guard !inbox.staged.isEmpty else {
                try? "error no staged files in share inbox".write(
                    to: resultURL, atomically: true, encoding: .utf8)
                return
            }
            let urls = inbox.staged
            inbox.consumeManifest()
            controller.startSend(urls: urls, customCode: args[i + 1])
            await watch(controller, resultURL: resultURL, autoAccept: false)
        }
        #endif
    }

    #if DEBUG
    @MainActor
    private static func applyRoute(_ route: String, args: [String]) {
        // --stage is repeatable, so collect every occurrence rather than the
        // first: a one-file Send screen is not the interesting screenshot.
        let staged = args.indices
            .filter { args[$0] == "--stage" && $0 + 1 < args.count }
            .map { URL(fileURLWithPath: args[$0 + 1]) }
        switch route {
        case "send": AppRouter.shared.openSend(with: staged)
        case "receive": AppRouter.shared.path = [.receive]
        case "settings": AppRouter.shared.path = [.settings]
        case "howItWorks": AppRouter.shared.path = [.howItWorks]
        case "history": AppRouter.shared.path = [.history]
        default: break  // home and onboarding both start from an empty path
        }
    }

    /// Sample records for the history screenshot. Safe because every harness
    /// run gets an in-memory container (CrocAppApp.init), so this can never
    /// reach the user's real store.
    @MainActor
    private static func seedHistory(_ history: HistoryStore?) {
        guard let history else { return }
        let samples:
            [(
                send: Bool, status: TransferRecord.Status, files: Int, bytes: Int64,
                names: [String],
                hint: String, agoHours: Double
            )] = [
                (
                    true, .completed, 3, 12_163_000,
                    ["Presentation.pdf", "Budget.numbers", "Cover-Art.png"], "4821", 0.4
                ),
                (false, .completed, 1, 8_800_000, ["Design-Assets.zip"], "6142", 5),
                (true, .completed, 1, 1_240_000, ["Notes.md"], "9134", 27),
                (
                    false, .declined, 2, 47_300_000, ["raw-scan-01.tiff", "raw-scan-02.tiff"],
                    "3057", 51
                ),
                (true, .failed, 1, 96_000_000, ["Archive.tar.gz"], "7253", 74),
            ]
        for sample in samples {
            let record = TransferRecord(
                isSend: sample.send, status: sample.status, isText: false,
                fileCount: sample.files, totalBytes: sample.bytes, names: sample.names,
                codeHint: sample.hint, bookmarks: [])
            record.date = Date(timeIntervalSinceNow: -sample.agoHours * 3600)
            history.add(record)
        }
    }

    @MainActor
    private static func watch(
        _ controller: TransferController, resultURL: URL, autoAccept: Bool
    ) async {
        while true {
            try? await Task.sleep(for: .milliseconds(200))
            switch controller.phase {
            case .incoming where autoAccept:
                controller.respond(accept: true)
            case .confirmSend:
                controller.respond(accept: true)
            case .done(let summary, _):
                try? "ok success=\(summary.success)".write(
                    to: resultURL, atomically: true, encoding: .utf8)
                let historyURL = resultURL.deletingLastPathComponent().appendingPathComponent(
                    "verify-history.txt")
                try? "records=\(controller.history?.recordCount() ?? -1)".write(
                    to: historyURL, atomically: true, encoding: .utf8)
                return
            case .failed(let message):
                try? "error \(message)".write(to: resultURL, atomically: true, encoding: .utf8)
                let historyURL = resultURL.deletingLastPathComponent().appendingPathComponent(
                    "verify-history.txt")
                try? "records=\(controller.history?.recordCount() ?? -1)".write(
                    to: historyURL, atomically: true, encoding: .utf8)
                return
            default:
                break
            }
        }
    }
    #endif
}
