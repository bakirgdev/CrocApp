import AppIntents
import CrocKit
import Foundation
import SwiftData

#if os(macOS)
import ServiceManagement
#endif

/// Launch-argument harness for scripted verification.
///   --auto-receive CODE            receive into Documents, auto-accept
///   --auto-send PATH --code CODE   send PATH with custom code CODE
///   --auto-store-send PATH         "Send as link" PATH (to --store-server URL, allowing --store-downloads N,
///                                  default 1), write the link to verify-store-link.txt, then wait for
///                                  verify-store-revoke.go in Documents and revoke the upload
///   --auto-store-receive LINK      receive a stored link into Documents, auto-accept
///   --auto-intent send-files|send-text|receive --intent-arg ARG
///                                  run that Shortcuts action's perform() with ARG (a path, the text, or
///                                  a code); the sends write their code to verify-code.txt, receive
///                                  auto-accepts and lists the returned file names in verify-result.txt
///   --auto-menubar-send PATH      send PATH through the menu-bar view model (macOS); the generated
///                                  code goes to verify-code.txt
///   --auto-menubar-clipboard       send the pasteboard text through the menu-bar view model (macOS)
///   --auto-login-item              register Open at login, record the system status, unregister,
///                                  record it again (macOS)
///   --auto-share-send CODE         send whatever's staged in the ShareInbox with custom code CODE
///   --local                        force croc local-only mode (LAN/sandbox listener check)
///   --no-compress                  disable croc compression
///   --ask                          require sender-side confirm before send
///   --relay ADDR                   use a custom relay address (the LAN route stays on)
///   --disable-local                turn the LAN route off, so success provably went through the
///                                  relay; value-less, so on macOS it goes last
///   --relay-password PW            the custom relay's password (croc's default applies without it)
///   --shown-relay default          make the trust UI name the public relay whatever --relay says
///   --shown-link-origin ORIGIN     make a stored link show and encode ORIGIN (scheme and host, e.g.
///                                  https://getcroc.com) instead of the --store-server's; the upload
///                                  still goes to --store-server
///   --throttle RATE                cap the upload rate for a send, e.g. 4m (croc's --throttleUpload)
///   --hold                         park at the incoming prompt instead of auto-accepting
///   --when-exists keepBoth|replace answer the incoming prompt with this file policy
///                                  (the setting stays Keep Both, so the late answer must reach croc)
///   --screen ROUTE                 navigate to home|send|receive|settings|advanced|howItWorks|history|
///                                  onboarding on launch; combines with the --auto-* modes
///   --stage PATH                   preload PATH into the Send screen's staged list (repeatable)
///   --seed-history                 fill the (in-memory) history store with showcase records
/// --auto-send takes its two values non-adjacently (separated by the --code
/// flag, not `--auto-send PATH CODE`): two bare positional arguments in a row
/// makes AppKit treat the launch as a file-open request and it never creates
/// the default window, so ContentView's .task (and this whole harness) never
/// runs -- confirmed via `sample` on the hung process (idle in NSApplication's
/// event loop, no window ever attached). Splitting them with a flag avoids it.
/// On macOS, AppKit reads `--flag value` pairs as defaults and a bare leftover token as a file to
/// open, so a flag without a value (--hold, --seed-history) must come last.
/// Writes verify-result.txt ("ok success=<bool>" | "error <msg>") to Documents,
/// and verify-code-ready.txt once a send has its code, so a script can start
/// the receiver only after the app is in the room. For scripts that need to
/// know when a screen holds still: verify-ready.txt appears once --screen,
/// --stage and --seed-history are applied and the push animation has settled,
/// and verify-phase.txt always holds the transfer's current phase (waiting,
/// incoming conflicts=N, transferring percent=N, done, ...).
/// --hold, --screen, --stage, --seed-history, --relay-password, --shown-relay
/// and --throttle
/// exist for scripts/capture-screenshots.sh rather than the verify-*.sh runs:
/// the harness drives the controller directly, so without them the UI sits on
/// HomeView while the transfer runs behind it, and no screen holds still to
/// photograph.
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
            || args.contains("--auto-menubar-send") || args.contains("--auto-menubar-clipboard")
            || args.contains("--auto-login-item") || args.contains("--auto-intent")
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
        // CrocAppApp.init built the settings on in-memory storage and secrets for
        // a harness run, so they start at their defaults and these overrides
        // never reach UserDefaults or the Keychain.
        if args.contains("--local") { controller.settings.onlyLocal = true }
        if args.contains("--no-compress") { controller.settings.noCompress = true }
        if args.contains("--ask") { controller.settings.bothSidesConfirm = true }
        var sheetPolicy = FilePolicy.keepBoth
        if let i = args.firstIndex(of: "--when-exists"), i + 1 < args.count,
            let policy = FilePolicy(rawValue: args[i + 1])
        {
            sheetPolicy = policy
        }
        if let i = args.firstIndex(of: "--relay"), i + 1 < args.count {
            controller.settings.relayAddress = args[i + 1]
        }
        // Kill the LAN race so success provably went through the relay.
        if args.contains("--disable-local") { controller.harnessDisableLocal = true }
        if let i = args.firstIndex(of: "--relay-password"), i + 1 < args.count {
            controller.settings.relayPassword = args[i + 1]
        }
        if let i = args.firstIndex(of: "--shown-relay"), i + 1 < args.count,
            args[i + 1] == "default"
        {
            controller.harnessShownRelay = .publicDefault
        }
        if let i = args.firstIndex(of: "--shown-link-origin"), i + 1 < args.count {
            controller.harnessShownLinkOrigin = URL(string: args[i + 1])
        }
        if let i = args.firstIndex(of: "--throttle"), i + 1 < args.count {
            controller.settings.throttleUpload = args[i + 1]
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
        announceReady(docs: docs)
        let hold = args.contains("--hold")
        #if os(macOS)
        if await runMenuBarModes(args: args, controller: controller, resultURL: resultURL) {
            return
        }
        #endif

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
                lifetimeSeconds: 86_400)
            await watchStoreSend(controller, docs: docs, resultURL: resultURL)
        } else if let i = args.firstIndex(of: "--auto-store-receive"), i + 1 < args.count {
            guard let link = URL(string: args[i + 1]) else {
                try? "error bad link".write(to: resultURL, atomically: true, encoding: .utf8)
                return
            }
            controller.startStoreReceive(link: link, into: docs, folderIsScoped: false)
            await watch(
                controller, resultURL: resultURL, autoAccept: !hold, sheetPolicy: sheetPolicy)
        } else if let i = args.firstIndex(of: "--auto-intent"), i + 1 < args.count,
            let ai = args.firstIndex(of: "--intent-arg"), ai + 1 < args.count
        {
            await runIntent(
                args[i + 1], argument: args[ai + 1], controller: controller, resultURL: resultURL)
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
    /// Calls an App Intent's `perform()` directly: Shortcuts cannot be driven
    /// from a script, so this is the nearest proof that the actions work
    /// against the CLI. The send actions return at the code, so the watch
    /// that follows carries each to its end. The dependencies are set by hand:
    /// outside Shortcuts' own flow, reading an unset one is a fatal error.
    @MainActor
    private static func runIntent(
        _ name: String, argument: String, controller: TransferController, resultURL: URL
    ) async {
        func finish(_ result: String) {
            try? result.write(to: resultURL, atomically: true, encoding: .utf8)
        }
        let codeURL = resultURL.deletingLastPathComponent().appendingPathComponent(
            "verify-code.txt")
        do {
            switch name {
            case "send-files":
                let intent = SendFilesIntent()
                intent.controller = controller
                intent.files = [IntentFile(fileURL: URL(fileURLWithPath: argument))]
                let code = try await intent.perform().value
                try code?.write(to: codeURL, atomically: true, encoding: .utf8)
                await watch(controller, resultURL: resultURL, autoAccept: false)
            case "send-text":
                let intent = SendTextIntent()
                intent.controller = controller
                intent.text = argument
                let code = try await intent.perform().value
                try code?.write(to: codeURL, atomically: true, encoding: .utf8)
                await watch(controller, resultURL: resultURL, autoAccept: false)
            case "receive":
                controller.settings.autoAccept = true
                let intent = ReceiveIntent()
                intent.controller = controller
                intent.outputFolder = OutputFolderStore()
                intent.codeOrLink = argument
                let files = try await intent.perform().value ?? []
                let names = files.compactMap { $0.fileURL?.lastPathComponent }.joined(
                    separator: ",")
                finish("ok success=true files=\(names)")
            default:
                finish("error unknown intent \(name)")
            }
        } catch {
            finish("error \(error)")
        }
    }
    #endif

    #if DEBUG && os(macOS)
    /// The macOS-only modes. True when one of them ran.
    @MainActor
    private static func runMenuBarModes(
        args: [String], controller: TransferController, resultURL: URL
    ) async -> Bool {
        func fail(_ message: String) {
            try? "error \(message)".write(to: resultURL, atomically: true, encoding: .utf8)
        }
        let quickSend = MenuBarQuickSend(controller: controller)
        if let i = args.firstIndex(of: "--auto-menubar-send"), i + 1 < args.count {
            guard quickSend.send(urls: [URL(fileURLWithPath: args[i + 1])]) else {
                fail("menu-bar send did not start")
                return true
            }
            await watch(controller, resultURL: resultURL, autoAccept: false)
        } else if args.contains("--auto-menubar-clipboard") {
            guard quickSend.sendClipboardText() else {
                fail("menu-bar clipboard send did not start")
                return true
            }
            await watch(controller, resultURL: resultURL, autoAccept: false)
        } else if args.contains("--auto-login-item") {
            runLoginItemCheck(resultURL: resultURL)
        } else {
            return false
        }
        return true
    }

    /// Leaves the login item as it found it. The status reads come from the
    /// system, so this proves the toggle's model matches `SMAppService`.
    @MainActor
    private static func runLoginItemCheck(resultURL: URL) {
        let item = LoginItem()
        let before = item.status
        func finish(_ result: String) {
            try? result.write(to: resultURL, atomically: true, encoding: .utf8)
        }
        item.setRegistered(true)
        let registered = item.status
        let toggleOn = item.isRegistered
        item.setRegistered(false)
        let after = item.status
        if let message = item.errorMessage {
            finish("error \(message)")
        } else {
            finish(
                "ok before=\(before.rawValue) registered=\(registered.rawValue) toggleOn=\(toggleOn)"
                    + " after=\(after.rawValue) toggleOff=\(!item.isRegistered)")
        }
    }
    #endif

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
        case "advanced": AppRouter.shared.path = [.settings, .advancedSettings]
        case "howItWorks": AppRouter.shared.path = [.howItWorks]
        case "history": AppRouter.shared.path = [.history]
        default: break  // home and onboarding both start from an empty path
        }
    }

    /// Writes verify-ready.txt once the requested screen has been on display
    /// long enough for its push animation to finish. Does not wait, so a
    /// transfer mode starts at once.
    @MainActor
    private static func announceReady(docs: URL) {
        guard requestedRoute() != nil else { return }
        let readyURL = docs.appendingPathComponent("verify-ready.txt")
        Task {
            try? await Task.sleep(for: .seconds(1))
            try? "ready".write(to: readyURL, atomically: true, encoding: .utf8)
        }
    }

    /// Showcase records for the history screenshot: sends and receives,
    /// every status, a text snippet and a stored link, from minutes to weeks
    /// old. Names and sizes match the payloads capture-screenshots.sh builds.
    /// Safe because every harness run gets an in-memory container
    /// (CrocAppApp.init), so this can never reach the user's real store.
    @MainActor
    private static func seedHistory(_ history: HistoryStore?) {
        guard let history else { return }
        let hour = 3600.0
        let day = 24 * hour
        let samples:
            [(
                send: Bool, status: TransferRecord.Status, text: Bool, bytes: Int64,
                names: [String], count: Int, hint: String, ago: Double, stored: Bool
            )] = [
                (
                    false, .completed, false, 177_000,
                    ["Quarterly-Report.pdf", "Ridge-Sunrise.jpg", "Meeting-Notes.md"], 3, "cape-…",
                    12 * 60, false
                ),
                (true, .completed, true, 148, [], 1, "wiry-…", 2 * hour, false),
                (
                    true, .completed, false, 55_000, ["Design-Assets.zip"], 1,
                    "getcroc.com", 5 * hour, true
                ),
                (
                    false, .completed, false, 24_100_000, ["Soundtrack.wav"], 1, "junky-…",
                    1.2 * day,
                    false
                ),
                (
                    true, .declined, false, 184_000, ["Contract-Draft.pdf"], 1, "lint-…", 2 * day,
                    false
                ),
                (
                    false, .failed, false, 96_000_000, ["Field-Recordings.zip"], 1, "mild-…",
                    4 * day,
                    false
                ),
                (
                    true, .completed, false, 18_600_000,
                    ["Slides.pdf", "Cover-Art.png", "Speaker-Notes.md", "Demo-Reel.mov"], 4, "op…",
                    6 * day, false
                ),
                (
                    false, .cancelled, false, 412_000_000,
                    ["Raw-Scans.zip"], 1, "tamer-…", 9 * day, false
                ),
                (
                    true, .completed, false, 7_800_000, ["Project-Archive.zip"], 1, "fuzzy-…",
                    21 * day, false
                ),
                (
                    false, .completed, false, 1_200_000, ["Receipts.pdf"], 1, "rope-…", 35 * day,
                    false
                ),
            ]
        for sample in samples {
            let record = TransferRecord(
                isSend: sample.send, status: sample.status, isText: sample.text,
                fileCount: sample.count, totalBytes: sample.bytes, names: sample.names,
                codeHint: sample.hint, bookmarks: [],
                storedID: sample.stored ? "showcase-link" : nil,
                expiresAt: sample.stored ? Date(timeIntervalSinceNow: 2 * day) : nil)
            record.date = Date(timeIntervalSinceNow: -sample.ago)
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

    private static func phaseLabel(_ phase: TransferController.Phase) -> String {
        switch phase {
        case .idle: "idle"
        case .starting: "starting"
        case .waiting: "waiting"
        case .connecting: "connecting"
        case .confirmSend: "confirmSend"
        case .incoming(_, let conflicts, _): "incoming conflicts=\(conflicts.count)"
        case .transferring(let p):
            "transferring percent=\(p.totalSize > 0 ? Int(100 * (p.bytesFinished + p.fileSent) / p.totalSize) : 0)"
        case .done: "done"
        case .stored: "stored"
        case .failed(let message): "failed \(message)"
        }
    }

    @MainActor
    private static func watch(
        _ controller: TransferController, resultURL: URL, autoAccept: Bool,
        sheetPolicy: FilePolicy = .keepBoth
    ) async {
        var codeReady = false
        var lastLabel = ""
        let phaseURL = resultURL.deletingLastPathComponent().appendingPathComponent(
            "verify-phase.txt")
        func finish(_ result: String) {
            try? result.write(to: resultURL, atomically: true, encoding: .utf8)
            let historyURL = resultURL.deletingLastPathComponent().appendingPathComponent(
                "verify-history.txt")
            try? "records=\(controller.history?.recordCount() ?? -1)".write(
                to: historyURL, atomically: true, encoding: .utf8)
        }
        while true {
            try? await Task.sleep(for: .milliseconds(200))
            let label = phaseLabel(controller.phase)
            if label != lastLabel {
                lastLabel = label
                try? label.write(to: phaseURL, atomically: true, encoding: .utf8)
            }
            switch controller.phase {
            case .waiting(let code) where !codeReady:
                codeReady = true
                try? code.write(
                    to: resultURL.deletingLastPathComponent().appendingPathComponent(
                        "verify-code.txt"),
                    atomically: true, encoding: .utf8)
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
