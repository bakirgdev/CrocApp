import Foundation
import Observation
import CrocKit

/// The app-side state machine over CrocEngine. Views render `phase` and call
/// the intent methods; nothing else in the app touches CrocKit directly.
@MainActor
@Observable
final class TransferController {
    enum Direction { case send, receive }

    enum Phase {
        case idle
        case starting
        case waiting(code: String)
        case connecting
        case confirmSend
        case incoming(FileList, conflicts: [String], blocked: [String])
        case transferring(TransferProgress)
        case done(Summary, receivedText: String?)
        case failed(String)
    }

    private(set) var phase: Phase = .idle
    private(set) var direction: Direction = .send
    private(set) var speedBytesPerSec: Double = 0

    let settings: AppSettings

    /// Relay path of the transfer in flight, captured at start so mid-transfer
    /// settings edits don't lie in the trust UI.
    private(set) var activeRelay: AppSettings.RelayKind = .publicDefault

    /// Harness-only (AutoVerify --relay): kills the LAN race so the custom
    /// relay path is provably exercised. Not a user setting.
    var harnessDisableLocal = false

    var isActive: Bool {
        if case .idle = phase { return false }
        return true
    }

    var lastOutputFolder: URL? { outDir }

    private let engine = CrocEngine()
    private let background = BackgroundCoordinator()
    private var backgroundExpired = false
    private var streamTask: Task<Void, Never>?
    private var scopedURLs: [URL] = []
    private var cancelRequested = false
    private var declineRequested = false
    private var receivedText: String?
    private var outDir: URL?
    private var lastProgressBytes: Int64 = 0
    private var lastProgressDate: Date?
    private var sendConfirmArmed = false
    private var autoAcceptActive = false
    private var blockedAutoAccept = false
    /// True once any payload bytes moved -- gates the "resume" hint so it
    /// never appears on failures before the transfer started.
    private var sawTransferBytes = false

    /// History sink; set once at app startup. nil in previews.
    @ObservationIgnored var history: HistoryStore?
    private var pendingRecord: PendingRecord?

    /// Snapshot of what we know about the in-flight transfer, finalized into
    /// a TransferRecord at the terminal event.
    private struct PendingRecord {
        var isSend: Bool
        var isText: Bool
        var names: [String]
        var fileCount: Int
        var totalBytes: Int64
        var codeHint: String
        var bookmarks: [Data]
    }

    init(settings: AppSettings) {
        self.settings = settings
    }

    // MARK: - Intents

    private func baseOptions() -> EngineOptions {
        var o = EngineOptions()
        let relays = settings.engineRelayAddresses
        o.relayAddress = relays.v4
        o.relayAddress6 = relays.v6
        o.relayPassword = settings.effectiveRelayPassword
        o.onlyLocal = settings.onlyLocal
        o.disableLocal = harnessDisableLocal
        o.noCompress = settings.noCompress
        o.ask = settings.bothSidesConfirm
        return o
    }

    func startSend(urls: [URL], customCode: String) {
        guard !isActive else { return }
        direction = .send
        activeRelay = settings.relayKind
        sendConfirmArmed = settings.bothSidesConfirm
        autoAcceptActive = false
        // startAccessing returns false for non-scoped URLs (e.g. some drops);
        // keep every path regardless, only track the ones needing release.
        scopedURLs = urls.filter { $0.startAccessingSecurityScopedResource() }
        let bookmarks: [Data]
        if urls.count <= TransferRecord.maxBookmarks {
            let all = urls.compactMap { Self.bookmark(for: $0) }
            bookmarks = all.count == urls.count ? all : []
        } else {
            bookmarks = []
        }
        pendingRecord = PendingRecord(
            isSend: true, isText: false,
            names: urls.prefix(TransferRecord.maxNames).map(\.lastPathComponent),
            fileCount: urls.count, totalBytes: 0,
            codeHint: Self.codeHint(customCode),
            bookmarks: bookmarks)
        let paths = urls.map(\.path)
        var options = baseOptions()
        options.customCode = customCode
        options.workDir = FileManager.default.temporaryDirectory.path
        options.zipFolder = settings.zipFolder
        options.gitIgnore = settings.useGitIgnore
        options.exclude = settings.excludeList
        run { try await self.engine.startSend(paths: paths, text: nil, options: options) }
    }

    func startSendText(_ text: String, customCode: String) {
        guard !isActive else { return }
        direction = .send
        activeRelay = settings.relayKind
        sendConfirmArmed = settings.bothSidesConfirm
        autoAcceptActive = false
        pendingRecord = PendingRecord(
            isSend: true, isText: true, names: [], fileCount: 0, totalBytes: 0,
            codeHint: Self.codeHint(customCode), bookmarks: [])
        var options = baseOptions()
        options.customCode = customCode
        options.workDir = FileManager.default.temporaryDirectory.path
        run { try await self.engine.startSend(paths: [], text: text, options: options) }
    }

    func startReceive(code: String, into folder: URL, folderIsScoped: Bool) {
        guard !isActive else { return }
        direction = .receive
        activeRelay = settings.relayKind
        sendConfirmArmed = false
        outDir = folder
        if folderIsScoped, folder.startAccessingSecurityScopedResource() {
            scopedURLs.append(folder)
        }
        pendingRecord = PendingRecord(
            isSend: false, isText: false, names: [], fileCount: 0, totalBytes: 0,
            codeHint: Self.codeHint(code), bookmarks: [])
        var options = baseOptions()
        options.outDir = folder.path
        // Conflicts are surfaced in the incoming sheet before accept; from
        // there "Accept" means replace (croc resumes partial files itself).
        options.overwrite = true
        // Ask forces croc's receiver prompt even under NoPrompt, and the
        // engine's AutoAccept path closes the prompt pipe (EOF = decline),
        // so Ask wins when both are on.
        options.autoAccept = settings.autoAccept && !settings.bothSidesConfirm
        autoAcceptActive = options.autoAccept
        run { try await self.engine.startReceive(code: code, options: options) }
    }

    /// Answer the accept/decline prompt raised by `.incoming`.
    func respond(accept: Bool) {
        Task { await engine.respond(accept: accept) }
        if accept {
            phase = .connecting
        } else {
            declineRequested = true
        }
        // Decline: croc notifies the sender (SendError path) and the session
        // ends with a failed/done event; phase advances from the stream.
    }

    func cancel() {
        cancelRequested = true
        Task { await engine.cancel() }
    }

    /// Back to idle. Only meaningful from terminal phases; the stream has
    /// already finished there, so cancelling streamTask is a no-op safety.
    func reset() {
        streamTask?.cancel()
        streamTask = nil
        releaseScopedURLs()
        receivedText = nil
        outDir = nil
        speedBytesPerSec = 0
        backgroundExpired = false
        phase = .idle
    }

    // MARK: - Engine plumbing

    private func run(_ start: @escaping () async throws -> AsyncStream<TransferEvent>) {
        phase = .starting
        background.transferStarted(title: direction == .send ? "Sending with CrocApp" : "Receiving with CrocApp") { [weak self] in
            guard let self else { return }
            self.backgroundExpired = true
            self.cancel()
        }
        cancelRequested = false
        declineRequested = false
        blockedAutoAccept = false
        sawTransferBytes = false
        receivedText = nil
        speedBytesPerSec = 0
        lastProgressDate = nil
        lastProgressBytes = 0
        streamTask = Task {
            do {
                var stream: AsyncStream<TransferEvent>
                do {
                    stream = try await start()
                } catch CrocEngineError.transferActive {
                    // Brief window after `done` where the engine still holds
                    // the previous transfer (bridge doc) -- retry once.
                    try await Task.sleep(for: .milliseconds(300))
                    stream = try await start()
                }
                for await event in stream { handle(event) }
            } catch {
                // Startup failure before any event flowed -- still tear down
                // the idle-timer lock / BG task requested at the top of run().
                background.transferEnded(success: false)
                phase = .failed(Self.friendlyMessage(for: "\(error)", cancelRequested: cancelRequested, declineRequested: declineRequested))
                finishRecord(cancelRequested ? .cancelled : .failed, summary: nil)
            }
            releaseScopedURLs()
        }
    }

    private func handle(_ event: TransferEvent) {
        switch event {
        case .codeReady(let code):
            if pendingRecord?.codeHint.isEmpty == true {
                pendingRecord?.codeHint = Self.codeHint(code)
            }
            phase = .waiting(code: code)
        case .connected:
            // F19: gate the send behind an explicit confirm. The pipe write
            // buffers, so confirming before croc reaches its prompt is safe.
            if direction == .send, sendConfirmArmed {
                sendConfirmArmed = false
                phase = .confirmSend
            } else {
                phase = .connecting
            }
        case .fileList(let list):
            let names = list.files.map(\.name)
            if pendingRecord?.isSend == false {
                pendingRecord?.names = Array(names.prefix(TransferRecord.maxNames))
                pendingRecord?.fileCount = list.files.count
                pendingRecord?.totalBytes = list.totalSize
            }
            let blocked = names.filter { ReceivedName.isUnsafe($0) }
            if autoAcceptActive {
                // croc is already proceeding (NoPrompt); the only brake left
                // for unsafe names is killing the transfer.
                if !blocked.isEmpty {
                    blockedAutoAccept = true
                    cancel()
                }
                return
            }
            let conflicts: [String]
            if let outDir {
                conflicts = names.filter {
                    FileManager.default.fileExists(atPath: outDir.appendingPathComponent($0).path)
                }
            } else {
                conflicts = []
            }
            phase = .incoming(list, conflicts: conflicts, blocked: blocked)
        case .progress(let p):
            // step "waiting" ticks arrive while the code screen should stay up.
            guard p.step != "waiting" else { return }
            // Progress ticks keep flowing while a prompt is unanswered --
            // never clobber .incoming/.confirmSend; respond() moves the
            // phase forward.
            if case .incoming = phase { return }
            if case .confirmSend = phase { return }
            updateSpeed(p)
            if p.bytesFinished + p.fileSent > 0 { sawTransferBytes = true }
            background.progressChanged(
                bytesDone: p.bytesFinished + p.fileSent,
                totalBytes: p.totalSize,
                fileName: p.fileName)
            phase = .transferring(p)
        case .text(let t):
            receivedText = t
        case .done(let summary):
            background.transferEnded(success: true)
            phase = .done(summary, receivedText: receivedText)
            finishRecord(summary.success ? .completed : .failed, summary: summary)
        case .failed(let message):
            background.transferEnded(success: false)
            if blockedAutoAccept {
                phase = .failed("Blocked: this transfer contained unsafe file names, so auto-accept cancelled it.")
            } else if backgroundExpired {
                phase = .failed("iOS paused the transfer in the background. Start the same transfer again — croc resumes partially transferred files.")
            } else {
                var copy = Self.friendlyMessage(for: message, cancelRequested: cancelRequested, declineRequested: declineRequested)
                if sawTransferBytes && !cancelRequested && !declineRequested {
                    copy += " Start the same transfer again — croc resumes partially transferred files."
                }
                phase = .failed(copy)
            }
            finishRecord(cancelRequested ? .cancelled : declineRequested ? .declined : .failed,
                         summary: nil)
            // Phase 1 contract: consumer must cancel the engine on .failed so
            // the Go session releases and the next transfer can start.
            Task { await engine.cancel() }
        }
    }

    private func updateSpeed(_ p: TransferProgress) {
        let doneBytes = p.bytesFinished + p.fileSent
        let now = Date()
        guard let last = lastProgressDate else {
            lastProgressDate = now
            lastProgressBytes = doneBytes
            return
        }
        let dt = now.timeIntervalSince(last)
        guard dt > 0.2 else { return }
        let instant = Double(doneBytes - lastProgressBytes) / dt
        speedBytesPerSec = speedBytesPerSec == 0 ? instant : 0.25 * instant + 0.75 * speedBytesPerSec
        lastProgressDate = now
        lastProgressBytes = doneBytes
    }

    private func releaseScopedURLs() {
        scopedURLs.forEach { $0.stopAccessingSecurityScopedResource() }
        scopedURLs = []
    }

    /// First code segment only ("7291-…") — enough to recognise a transfer,
    /// useless to an attacker, and codes are single-use anyway.
    private static func codeHint(_ code: String) -> String {
        let t = code.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return "" }
        guard let first = t.split(separator: "-").first, first.count < t.count else {
            return String(t.prefix(4)) + "…"
        }
        return first + "-…"
    }

    private static func bookmark(for url: URL) -> Data? {
        #if os(macOS)
        try? url.bookmarkData(options: .withSecurityScope,
                              includingResourceValuesForKeys: nil, relativeTo: nil)
        #else
        try? url.bookmarkData()
        #endif
    }

    private func finishRecord(_ status: TransferRecord.Status, summary: Summary?) {
        guard var p = pendingRecord else { return }
        pendingRecord = nil
        if let summary {
            p.totalBytes = summary.totalSize
            if summary.files > 0 { p.fileCount = summary.files }
        }
        if receivedText != nil { p.isText = true }
        history?.add(TransferRecord(
            isSend: p.isSend, status: status, isText: p.isText,
            fileCount: p.fileCount, totalBytes: p.totalBytes,
            names: p.names, codeHint: p.codeHint, bookmarks: p.bookmarks))
    }

    // MARK: - Error copy

    static func friendlyMessage(for raw: String, cancelRequested: Bool, declineRequested: Bool) -> String {
        if cancelRequested { return "Transfer cancelled." }
        if declineRequested { return "You declined the transfer." }
        let m = raw.lowercased()
        // Local cancel during the accept prompt also surfaces "refused files";
        // that case is caught by cancelRequested above.
        if m.contains("refused files") { return "The other side declined the transfer." }
        if m.contains("room full") { return "That code is already in use. Try a different code." }
        if m.contains("no such host") || m.contains("connection refused")
            || m.contains("i/o timeout") || m.contains("dial tcp") {
            return "Couldn't reach the relay. Check your internet connection."
        }
        if m.contains("bad password") {
            return "Wrong code phrase, or the sender is no longer available."
        }
        if m.contains("broken pipe") || m.contains("connection reset") || m.contains("unexpected eof") {
            return "Lost connection to the other device."
        }
        return "Transfer failed: \(raw)"
    }
}
