import CrocKit
import Foundation
import Observation

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
        /// A stored upload finished. The receipt holds the link to share.
        case stored(StoredReceipt)
        case failed(String)
    }

    private(set) var phase: Phase = .idle
    private(set) var direction: Direction = .send
    private(set) var speedBytesPerSec: Double = 0
    /// The transfer goes through a stored-transfer server (R18-R20) rather
    /// than a croc peer.
    private(set) var isStoredTransfer = false

    let settings: AppSettings
    let vault: StoredTransferVault

    /// Relay path of the transfer in flight, captured at start so mid-transfer
    /// settings edits don't lie in the trust UI.
    private(set) var activeRelay: AppSettings.RelayKind = .publicDefault

    /// Harness-only (AutoVerify --shown-relay): the relay the trust UI
    /// names, so a run through a local relay photographs like a default one.
    var harnessShownRelay: AppSettings.RelayKind?

    #if DEBUG
    /// Harness-only (AutoVerify --shown-link-origin): scheme and host the
    /// stored link shows and encodes, so a local store server photographs
    /// like a real one. The upload itself still goes to the configured server.
    var harnessShownLinkOrigin: URL?

    /// Swaps scheme, host and port of the link; path and fragment (the key)
    /// stay. A link that fails to parse is left alone.
    private static func relinked(_ receipt: StoredReceipt, origin: URL) -> StoredReceipt {
        guard var parts = URLComponents(string: receipt.link),
            let shown = URLComponents(url: origin, resolvingAgainstBaseURL: false)
        else { return receipt }
        parts.scheme = shown.scheme
        parts.host = shown.host
        parts.port = shown.port
        guard let link = parts.string else { return receipt }
        return StoredReceipt(
            id: receipt.id, origin: receipt.origin, uploadToken: receipt.uploadToken,
            link: link, expiresAt: receipt.expiresAt, downloads: receipt.downloads)
    }
    #endif

    /// Harness-only (AutoVerify --relay): kills the LAN race so the custom
    /// relay path is provably exercised. Not a user setting.
    var harnessDisableLocal = false

    var isActive: Bool {
        if case .idle = phase { return false }
        return true
    }

    var lastOutputFolder: URL? { outDir }

    /// Names (paths relative to the receive folder) the sender offered in the
    /// current or last receive. Shortcuts uses them to hand the files back.
    private(set) var offeredFileNames: [String] = []

    /// The code of the send in flight, once croc has made one. Unlike `phase`
    /// it survives the move to `.connecting`, so a caller that looks late
    /// cannot miss it.
    private(set) var currentCode: String?

    private let engine = CrocEngine()
    private let background = BackgroundCoordinator()
    private var backgroundExpired = false
    private var streamTask: Task<Void, Never>?
    /// The engine transfer this controller started last; every cancel targets it,
    /// so a late cancel cannot reach the next transfer.
    private var transferID: TransferID?
    private var scopedURLs: [URL] = []
    private var cancelRequested = false
    private var declineRequested = false
    /// The current transfer ended because the user tapped Cancel or Decline.
    /// A background-expiry cancel does not count. Haptics read this so a
    /// button press never fires the failure haptic.
    var endedByUser: Bool { (cancelRequested && !backgroundExpired) || declineRequested }
    private var receivedText: String?
    private var outDir: URL?
    private var lastProgressBytes: Int64 = 0
    private var lastProgressDate: Date?
    private var sendConfirmArmed = false
    private var autoAcceptActive = false
    private var blockedAutoAccept = false
    /// Bumped once per `run()`. The async conflict scan captures it and only
    /// writes back if it still matches, so a scan that outlives a fast transfer
    /// cannot deposit its stale results onto the next one's `.incoming`.
    private var transferGeneration = 0
    /// True once any payload bytes moved -- gates the "resume" hint so it
    /// never appears on failures before the transfer started.
    private var sawTransferBytes = false
    /// Arrives just before `.done` on a stored upload.
    private var storedReceipt: StoredReceipt?

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
        var storedID: String?
        var expiresAt: Date?
    }

    init(settings: AppSettings, vault: StoredTransferVault) {
        self.settings = settings
        self.vault = vault
    }

    // MARK: - Intents

    private func baseOptions() -> EngineOptions {
        var o = EngineOptions()
        o.relayAddress = settings.relayAddress
        o.relayAddress6 = settings.relayAddress6
        o.relayPassword = settings.relayPassword
        o.onlyLocal = settings.onlyLocal
        o.disableLocal = harnessDisableLocal
        o.noCompress = settings.noCompress
        o.transport = settings.transport
        o.ask = settings.bothSidesConfirm
        o.curve = settings.curve
        o.hashAlgorithm = settings.hashAlgorithm
        o.throttleUpload = settings.throttleUpload.trimmingCharacters(in: .whitespacesAndNewlines)
        o.noMultiplexing = settings.noMultiplexing
        o.basePort = settings.basePort
        o.transfers = settings.transfers
        o.internalDNS = settings.internalDNS
        o.socks5Proxy = proxies.socks5
        o.httpProxy = proxies.http
        #if os(macOS)
        // iOS has no multicast entitlement (concern 8): the field is hidden
        // there and the engine keeps croc's default group.
        let multicast = settings.multicastAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        if !multicast.isEmpty { o.multicastAddress = multicast }
        #endif
        return o
    }

    /// The Advanced proxies, trimmed. Credentials may be inside: pass them on,
    /// never log or describe them.
    private var proxies: ProxySettings {
        ProxySettings(
            socks5: settings.socks5Proxy.trimmingCharacters(in: .whitespacesAndNewlines),
            http: settings.httpProxy.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    func startSend(urls: [URL], customCode: String) {
        guard !isActive else { return }
        direction = .send
        isStoredTransfer = false
        activeRelay = harnessShownRelay ?? settings.relayKind
        sendConfirmArmed = settings.bothSidesConfirm
        autoAcceptActive = false
        beginFileSend(urls: urls, codeHint: Self.codeHint(customCode))
        let paths = urls.map(\.path)
        var options = baseOptions()
        options.customCode = customCode
        options.workDir = FileManager.default.temporaryDirectory.path
        options.zipFolder = settings.zipFolder
        options.gitIgnore = settings.useGitIgnore
        options.exclude = settings.excludeList
        run { try await self.engine.startSend(paths: paths, text: nil, options: options) }
    }

    /// Uploads `urls` (regular files only) encrypted to the stored-transfer
    /// server in Settings (R18). Ends in `.stored(receipt)`; the receipt also
    /// goes to the vault so History can revoke it.
    func startStoreSend(urls: [URL], downloads: Int, lifetimeSeconds: Int) {
        guard !isActive else { return }
        direction = .send
        isStoredTransfer = true
        activeRelay = harnessShownRelay ?? settings.relayKind
        sendConfirmArmed = false
        autoAcceptActive = false
        let server = settings.storedServer.trimmingCharacters(in: .whitespacesAndNewlines)
        beginFileSend(
            urls: urls, codeHint: URL(string: server).map(Self.codeHint(storedLink:)) ?? "")
        let paths = urls.map(\.path)
        var options = StoredSendOptions()
        options.server = server
        options.downloads = downloads
        options.lifetimeSeconds = lifetimeSeconds
        options.proxy = proxies
        run { try await self.engine.startStoreSend(paths: paths, options: options) }
    }

    private func beginFileSend(urls: [URL], codeHint: String) {
        // startAccessing returns false for non-scoped URLs (e.g. some drops);
        // keep every path regardless, only track the ones needing release.
        scopedURLs = urls.filter { $0.startAccessingSecurityScopedResource() }
        pendingRecord = PendingRecord(
            isSend: true, isText: false,
            names: urls.prefix(TransferRecord.maxNames).map(\.lastPathComponent),
            fileCount: urls.count, totalBytes: 0,
            codeHint: codeHint,
            bookmarks: [])
        // Up to maxBookmarks (200) bookmarkData calls, off the main actor so a
        // slow volume can't stall the send tap. Security scope is held until
        // releaseScopedURLs, so the URLs stay readable throughout. A transfer
        // that terminates before this lands leaves pendingRecord nil and the
        // record simply carries no bookmarks -- the same outcome as the
        // existing all-or-nothing fallback, so "Send Again" is hidden rather
        // than broken.
        if urls.count <= TransferRecord.maxBookmarks {
            Task { [weak self] in
                let all = await Task.detached(priority: .userInitiated) {
                    urls.compactMap { SecurityScopedBookmark.create(for: $0) }
                }.value
                guard let self, all.count == urls.count else { return }
                self.pendingRecord?.bookmarks = all
            }
        }
    }

    func startSendText(_ text: String, customCode: String) {
        guard !isActive else { return }
        direction = .send
        isStoredTransfer = false
        activeRelay = harnessShownRelay ?? settings.relayKind
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
        isStoredTransfer = false
        beginReceive(
            into: folder, folderIsScoped: folderIsScoped, codeHint: Self.codeHint(code),
            relay: settings.receiveRelayKind)
        var options = baseOptions()
        options.outDir = folder.path
        options.peerIP = settings.peerIP.trimmingCharacters(in: .whitespacesAndNewlines)
        // Auto-accept uses the setting; otherwise the incoming sheet's answer
        // replaces it.
        options.whenFileExists = settings.whenFileExists
        // Ask forces croc's receiver prompt even under NoPrompt, and the
        // engine's AutoAccept path closes the prompt pipe (EOF = decline),
        // so Ask wins when both are on.
        options.autoAccept = settings.autoAccept && !settings.bothSidesConfirm
        autoAcceptActive = options.autoAccept
        run { try await self.engine.startReceive(code: code, options: options) }
    }

    /// Opens a stored link (R20): the incoming preview, then the same accept
    /// and Keep Both / Replace answer as a live receive. Auto-accept does not
    /// apply; the engine always waits for `respond`.
    func startStoreReceive(link: URL, into folder: URL, folderIsScoped: Bool) {
        guard !isActive else { return }
        direction = .receive
        isStoredTransfer = true
        beginReceive(
            into: folder, folderIsScoped: folderIsScoped, codeHint: Self.codeHint(storedLink: link),
            relay: settings.relayKind)
        autoAcceptActive = false
        let path = folder.path
        let link = link.absoluteString
        let proxy = proxies
        run { try await self.engine.startStoreReceive(link: link, outDir: path, proxy: proxy) }
    }

    private func beginReceive(
        into folder: URL, folderIsScoped: Bool, codeHint: String, relay: AppSettings.RelayKind
    ) {
        activeRelay = harnessShownRelay ?? relay
        sendConfirmArmed = false
        outDir = folder
        if folderIsScoped, folder.startAccessingSecurityScopedResource() {
            scopedURLs.append(folder)
        }
        pendingRecord = PendingRecord(
            isSend: false, isText: false, names: [], fileCount: 0, totalBytes: 0,
            codeHint: codeHint, bookmarks: [])
    }

    /// Whether History can offer Revoke: an unexpired, unrevoked upload whose
    /// receipt this device still holds.
    func canRevoke(_ record: TransferRecord, now: Date = .now) -> Bool {
        guard let id = record.storedID, record.revokedAt == nil,
            let expiresAt = record.expiresAt, expiresAt > now
        else { return false }
        return vault.receipt(id: id) != nil
    }

    /// Deletes a stored upload from its server and marks its record (R19). A
    /// server that no longer has it counts as revoked. Runs alongside any
    /// active transfer. Throws `EngineFailure`; show
    /// `friendlyMessage(for:…, stored: true)`.
    func revoke(_ record: TransferRecord) async throws {
        guard let id = record.storedID, let receipt = vault.receipt(id: id) else {
            throw EngineFailure(code: .other, message: "no receipt for this upload")
        }
        try await engine.revokeStored(receipt, proxy: proxies)
        vault.remove(id: id)
        history?.markRevoked(record)
    }

    /// Answer the accept/decline prompt raised by `.incoming` or `.confirmSend`.
    /// `policy` decides what an accepted receive does with files that already
    /// exist; a send ignores it.
    func respond(accept: Bool, policy: FilePolicy = .keepBoth) {
        Task { await engine.respond(accept: accept, policy: policy) }
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
        // Before the engine has started there is nothing to cancel yet; run()
        // cancels as soon as the ID exists.
        guard let id = transferID else { return }
        Task { await engine.cancel(id) }
    }

    /// Back to idle. Only meaningful from terminal phases; the stream has
    /// already finished there, so cancelling streamTask is a no-op safety.
    func reset() {
        streamTask?.cancel()
        streamTask = nil
        releaseScopedURLs()
        receivedText = nil
        storedReceipt = nil
        outDir = nil
        speedBytesPerSec = 0
        backgroundExpired = false
        phase = .idle
    }

    // MARK: - Engine plumbing

    private func run(_ start: @escaping () async throws -> EngineTransfer) {
        phase = .starting
        let title =
            switch direction {
            case .send: "Sending with CrocApp"
            case .receive: "Receiving with CrocApp"
            }
        background.transferStarted(title: title) { [weak self] in
            guard let self else { return }
            self.backgroundExpired = true
            self.cancel()
        }
        cancelRequested = false
        declineRequested = false
        blockedAutoAccept = false
        transferGeneration += 1
        sawTransferBytes = false
        receivedText = nil
        storedReceipt = nil
        offeredFileNames = []
        currentCode = nil
        speedBytesPerSec = 0
        lastProgressDate = nil
        lastProgressBytes = 0
        transferID = nil
        streamTask = Task {
            do {
                var transfer: EngineTransfer
                do {
                    transfer = try await start()
                } catch CrocEngineError.transferActive {
                    // Brief window after `done` where the engine still holds
                    // the previous transfer (bridge doc) -- retry once.
                    try await Task.sleep(for: .milliseconds(300))
                    transfer = try await start()
                }
                transferID = transfer.id
                if cancelRequested { cancel() }
                for await event in transfer.events { handle(event) }
            } catch {
                // Startup failure before any event flowed -- still tear down
                // the idle-timer lock / BG task requested at the top of run().
                background.transferEnded(success: false)
                // Same precedence as handle(.failed): an expiry that surfaces
                // as a thrown error must keep the resume hint, not fall back
                // to generic copy.
                if backgroundExpired {
                    phase = .failed(backgroundExpiredCopy)
                } else {
                    let failure: EngineFailure
                    if case CrocEngineError.startFailed(let f) = error {
                        failure = f
                    } else {
                        failure = EngineFailure(code: .other, message: "\(error)")
                    }
                    phase = .failed(
                        Self.friendlyMessage(
                            for: failure, cancelRequested: cancelRequested,
                            declineRequested: declineRequested, stored: isStoredTransfer))
                }
                finishRecord(cancelRequested ? .cancelled : .failed, summary: nil)
            }
            releaseScopedURLs()
        }
    }

    private func handle(_ event: TransferEvent) {
        switch event {
        case .codeReady(let code):
            currentCode = code
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
                offeredFileNames = names
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
            // Show the sheet immediately; a 10k-file stat scan on the main
            // actor would freeze the accept UI, so conflicts fill in async.
            phase = .incoming(list, conflicts: [], blocked: blocked)
            guard let dir = outDir else { return }
            let generation = transferGeneration
            Task { [weak self] in
                let conflicts = await Self.scanConflicts(names: names, in: dir)
                guard let self, !conflicts.isEmpty, self.transferGeneration == generation,
                    case .incoming = self.phase
                else { return }
                self.phase = .incoming(list, conflicts: conflicts, blocked: blocked)
            }
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
        case .stored(var receipt):
            #if DEBUG
            if let shown = harnessShownLinkOrigin {
                receipt = Self.relinked(receipt, origin: shown)
            }
            #endif
            storedReceipt = receipt
            // A failed write is logged by the vault; the link still works,
            // only a revoke after relaunch is lost.
            vault.add(receipt)
            pendingRecord?.storedID = receipt.id
            pendingRecord?.expiresAt = receipt.expiresAt
        case .done(let summary):
            background.transferEnded(success: true)
            // cancel() is fire-and-forget, so a small enough transfer can reach
            // .done before the block's cancellation lands on the engine. The
            // bytes are already written either way; this only stops the UI and
            // the history record reporting a plain success for a blocked one.
            if blockedAutoAccept {
                phase = .failed(Self.blockedAutoAcceptCopy)
                finishRecord(.failed, summary: summary)
            } else if let storedReceipt {
                phase = .stored(storedReceipt)
                finishRecord(.completed, summary: summary)
            } else {
                phase = .done(summary, receivedText: receivedText)
                finishRecord(summary.success ? .completed : .failed, summary: summary)
            }
        case .failed(let failure):
            background.transferEnded(success: false)
            if blockedAutoAccept {
                phase = .failed(Self.blockedAutoAcceptCopy)
            } else if backgroundExpired {
                phase = .failed(backgroundExpiredCopy)
            } else if autoAcceptActive, !cancelRequested, failure.code == .refused {
                // This side's prompt refused without anyone answering it. croc
                // forces the receiver prompt whenever the remote sender ran
                // --ask, regardless of NoPrompt; engine auto-accept has already
                // closed the prompt pipe, so GetInput hits EOF. While
                // autoAcceptActive is true respond() is never called, so
                // declineRequested cannot be set, and the cancel paths are
                // excluded above -- what is left can only be this.
                phase = .failed(
                    "The sender asked to confirm this transfer manually, which auto-accept can't answer. Turn off Auto-Accept Transfers in Settings and try again, or ask the sender to resend without their confirmation option."
                )
            } else {
                var copy = Self.friendlyMessage(
                    for: failure, cancelRequested: cancelRequested,
                    declineRequested: declineRequested, stored: isStoredTransfer)
                // A stored transfer cannot resume; it starts over.
                if sawTransferBytes && !cancelRequested && !declineRequested && !isStoredTransfer {
                    copy += Self.resumeHint
                }
                phase = .failed(copy)
            }
            // blockedAutoAccept outranks cancelRequested: the block issues the
            // cancel itself, and "Cancelled" in history reads as a user action.
            // .failed is the closest existing status; a dedicated case would be
            // a schema change.
            let status: TransferRecord.Status
            if blockedAutoAccept {
                status = .failed
            } else if cancelRequested {
                status = .cancelled
            } else if declineRequested {
                status = .declined
            } else {
                status = .failed
            }
            finishRecord(status, summary: nil)
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
        speedBytesPerSec =
            speedBytesPerSec == 0 ? instant : 0.25 * instant + 0.75 * speedBytesPerSec
        lastProgressDate = now
        lastProgressBytes = doneBytes
    }

    private func releaseScopedURLs() {
        for url in scopedURLs { url.stopAccessingSecurityScopedResource() }
        scopedURLs = []
    }

    private static func scanConflicts(names: [String], in dir: URL) async -> [String] {
        await Task.detached(priority: .userInitiated) {
            names.filter {
                FileManager.default.fileExists(atPath: dir.appendingPathComponent($0).path)
            }
        }.value
    }

    /// A stored link carries its id in the path and its key in the fragment,
    /// so history keeps only the server's host.
    static func codeHint(storedLink url: URL) -> String {
        url.host(percentEncoded: false) ?? ""
    }

    /// Enough to recognise a transfer in history, not enough to reuse the
    /// code. A generated code's first word ("wiry-…", or "7291-…" for a
    /// legacy code) is a third of it at most; any other shape is likely a
    /// reusable custom code, so only its first two characters are kept.
    static func codeHint(_ code: String) -> String {
        let t = code.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return "" }
        let segments = t.split(separator: "-", omittingEmptySubsequences: false)
        if segments.count >= 3, let first = segments.first, (1...5).contains(first.count) {
            return first + "-…"
        }
        return String(t.prefix(2)) + "…"
    }

    private func finishRecord(_ status: TransferRecord.Status, summary: Summary?) {
        guard var p = pendingRecord else { return }
        pendingRecord = nil
        if let summary {
            p.totalBytes = summary.totalSize
            if summary.files > 0 { p.fileCount = summary.files }
        }
        if receivedText != nil { p.isText = true }
        history?.add(
            TransferRecord(
                isSend: p.isSend, status: status, isText: p.isText,
                fileCount: p.fileCount, totalBytes: p.totalBytes,
                names: p.names, codeHint: p.codeHint, bookmarks: p.bookmarks,
                storedID: p.storedID, expiresAt: p.expiresAt))
    }

    // MARK: - Error copy

    /// Used from both `.done` and `.failed`: a blocked transfer can terminate
    /// either way depending on whether the cancel beat the last event.
    private static let blockedAutoAcceptCopy =
        "Blocked: this transfer contained unsafe file names, so auto-accept cancelled it."

    /// Used from both `handle(.failed)` and `run()`'s catch. A stored
    /// transfer cannot resume (concern 4), so it says to start over.
    private var backgroundExpiredCopy: String {
        switch (isStoredTransfer, direction) {
        case (false, _): "iOS paused the transfer in the background." + Self.resumeHint
        case (true, .send): "Sending was interrupted: iOS stopped it in the background. Try again."
        case (true, .receive):
            "Receiving was interrupted: iOS stopped it in the background. Open the link again."
        }
    }

    /// Keep Both saves a partly received file as a new copy, so only Replace
    /// resumes it.
    private static let resumeHint =
        " Start the same transfer again; replacing the partly received files resumes it."

    /// `stored` words network failures for a stored-transfer server (a store
    /// call reports them as `relayUnreachable`) instead of a relay or peer.
    static func friendlyMessage(
        for failure: EngineFailure, cancelRequested: Bool, declineRequested: Bool,
        stored: Bool = false
    ) -> String {
        if cancelRequested { return "Transfer cancelled." }
        if declineRequested { return "You declined the transfer." }
        if stored, failure.code == .relayUnreachable || failure.code == .connectionLost {
            return
                "Couldn't reach the link server. Check your internet connection and try again."
        }
        // Never echo failure.message: croc adds new error text every release,
        // and a recovered Go panic arrives with a full stack trace attached.
        switch failure.code {
        case .peerVersion:
            return "The other device runs an older croc. Both sides need croc 11 or newer."
        case .relayUnreachable:
            return "Couldn't reach the relay. Check your internet connection."
        case .noPublicRelay:
            return
                "No public relay answered. Check your internet connection, or turn on Local Network Only in Settings if both devices are on the same network."
        case .declined:
            return "The other device declined or cancelled the transfer."
        case .refused:
            return "You declined the transfer."
        case .roomFull:
            return "That code is already in use. Try a different code."
        case .badPassword:
            return "The relay rejected its password. Check the relay password in Settings."
        case .wrongCode:
            return "The codes don't match. Check the code on both devices and try again."
        case .cancelled:
            return "Transfer cancelled."
        case .connectionLost:
            return "Lost connection to the other device."
        case .storeLimit:
            return
                "The link server refused this send: it is over the server's size, file count or download limit, or too many sends were made recently."
        case .storeExpired:
            return "This link has expired, was revoked, or has no downloads left."
        case .invalidSetting:
            return
                "An Advanced setting can't be used. Check the proxies, addresses, ports and send speed limit in Settings > Advanced."
        case .other:
            return "Transfer failed. Try again, or check your connection."
        }
    }
}
