import CrocKit
import Foundation
import SwiftData

/// Launch-argument harness for scripted verification.
///   --auto-receive CODE            receive into Documents, auto-accept
///   --auto-send PATH --code CODE   send PATH with custom code CODE
///   --auto-store-send PATH         "Send as link" PATH (to --store-server URL, allowing --store-downloads N,
///                                  default 1), write the link to verify-store-link.txt, then wait for
///                                  verify-store-revoke.go in Documents and revoke the upload
///   --auto-store-receive LINK      receive a stored link into Documents, auto-accept
///   --auto-share-send CODE         send whatever's staged in the ShareInbox with custom code CODE
///   --local                        force croc local-only mode (LAN/sandbox listener check)
///   --no-compress                  disable croc compression (F15)
///   --ask                          require sender-side confirm before send (F19)
///   --relay ADDR                   use a custom relay address (F13); also disables local-only race
///   --hold                         park at the incoming prompt instead of auto-accepting
///   --when-exists keepBoth|replace answer the incoming prompt with this file policy
///                                  (the setting stays Keep Both, so the late answer must reach croc)
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
/// Writes verify-result.txt ("ok success=<bool>" | "error <msg>") to Documents,
/// and verify-code-ready.txt once a send has its code, so a script can start
/// the receiver only after the app is in the room.
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
            || args.contains("--auto-share-send") || args.contains("--auto-store-send")
            || args.contains("--auto-store-receive") || args.contains("--screen")
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
        var sheetPolicy = FilePolicy.keepBoth
        if let i = args.firstIndex(of: "--when-exists"), i + 1 < args.count,
            let policy = FilePolicy(rawValue: args[i + 1])
        {
            sheetPolicy = policy
        }
        if let i = args.firstIndex(of: "--transport"), i + 1 < args.count,
            let transport = Transport(rawValue: args[i + 1])
        {
            controller.settings.transport = transport
        }
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
            await watch(
                controller, resultURL: resultURL, autoAccept: !hold, sheetPolicy: sheetPolicy)
        } else if let i = args.firstIndex(of: "--auto-send"), i + 1 < args.count,
            let ci = args.firstIndex(of: "--code"), ci + 1 < args.count
        {
            controller.startSend(
                urls: [URL(fileURLWithPath: args[i + 1])], customCode: args[ci + 1])
            await watch(controller, resultURL: resultURL, autoAccept: false)
        } else if let i = args.firstIndex(of: "--auto-store-send"), i + 1 < args.count {
            if let j = args.firstIndex(of: "--store-server"), j + 1 < args.count {
                controller.settings.storedServer = args[j + 1]
            }
            var downloads = 1
            if let j = args.firstIndex(of: "--store-downloads"), j + 1 < args.count,
                let n = Int(args[j + 1])
            {
                downloads = n
            }
            controller.startStoreSend(
                urls: [URL(fileURLWithPath: args[i + 1])], downloads: downloads,
                lifetimeSeconds: 3600)
            await watchStoreSend(controller, docs: docs, resultURL: resultURL)
        } else if let i = args.firstIndex(of: "--auto-store-receive"), i + 1 < args.count {
            guard let link = URL(string: args[i + 1]) else {
                try? "error bad link".write(to: resultURL, atomically: true, encoding: .utf8)
                return
            }
            controller.startStoreReceive(link: link, into: docs, folderIsScoped: false)
            await watch(
                controller, resultURL: resultURL, autoAccept: !hold, sheetPolicy: sheetPolicy)
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

    /// The upload leaves its link for the script, then waits for the script's
    /// signal to revoke it, so the script can download in between.
    @MainActor
    private static func watchStoreSend(
        _ controller: TransferController, docs: URL, resultURL: URL
    ) async {
        let linkURL = docs.appendingPathComponent("verify-store-link.txt")
        let signalURL = docs.appendingPathComponent("verify-store-revoke.go")
        func finish(_ result: String) {
            try? result.write(to: resultURL, atomically: true, encoding: .utf8)
        }
        while true {
            try? await Task.sleep(for: .milliseconds(200))
            switch controller.phase {
            case .stored(let receipt):
                if !FileManager.default.fileExists(atPath: linkURL.path) {
                    try? receipt.link.write(to: linkURL, atomically: true, encoding: .utf8)
                }
                guard FileManager.default.fileExists(atPath: signalURL.path) else { continue }
                var descriptor = FetchDescriptor<TransferRecord>(
                    sortBy: [SortDescriptor(\.date, order: .reverse)])
                descriptor.fetchLimit = 1
                guard let history = controller.history,
                    let record = try? history.container.mainContext.fetch(descriptor).first
                else {
                    finish("error no history record for the upload")
                    return
                }
                do {
                    try await controller.revoke(record)
                    finish(
                        record.revokedAt != nil && !controller.canRevoke(record)
                            ? "ok success=true revoked=true" : "error revoke left the record live")
                } catch {
                    finish("error revoke: \(error)")
                }
                return
            case .failed(let message):
                finish("error \(message)")
                return
            default:
                break
            }
        }
    }

    @MainActor
    private static func watch(
        _ controller: TransferController, resultURL: URL, autoAccept: Bool,
        sheetPolicy: FilePolicy = .keepBoth
    ) async {
        var codeReady = false
        func finish(_ result: String) {
            try? result.write(to: resultURL, atomically: true, encoding: .utf8)
            let historyURL = resultURL.deletingLastPathComponent().appendingPathComponent(
                "verify-history.txt")
            try? "records=\(controller.history?.recordCount() ?? -1)".write(
                to: historyURL, atomically: true, encoding: .utf8)
        }
        while true {
            try? await Task.sleep(for: .milliseconds(200))
            switch controller.phase {
            case .waiting where !codeReady:
                codeReady = true
                try? "ready".write(
                    to: resultURL.deletingLastPathComponent().appendingPathComponent(
                        "verify-code-ready.txt"),
                    atomically: true, encoding: .utf8)
            case .incoming where autoAccept:
                controller.respond(accept: true, policy: sheetPolicy)
            case .confirmSend:
                controller.respond(accept: true)
            case .done(let summary, _):
                finish("ok success=\(summary.success)")
                return
            case .failed(let message):
                finish("error \(message)")
                return
            default:
                break
            }
        }
    }
    #endif
}
