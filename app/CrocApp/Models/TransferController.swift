import CrocKit
import Foundation
import Observation

/// The app-side state machine over a `TransferEngine` (`CrocEngine` in the
/// app). Views render `phase` and call `start(_:)`, `respond`, `cancel`,
/// `retry` and `reset`; nothing else in the app starts or answers a transfer.
@MainActor
@Observable
final class TransferController {
    enum Direction { case send, receive }

    enum Phase: Equatable {
        case idle
        case starting
        case waiting(code: String)
        case connecting
        case confirmSend
        case incoming(FileList, conflicts: [String], blocked: [String])
        /// Bytes are moving. How far is `progress`, so a tick leaves the
        /// phase alone.
        case transferring
        case done(Summary, receivedText: String?)
        /// A stored upload finished. The receipt holds the link to share.
        case stored(StoredReceipt)
        case failed(TransferFailure)
    }

    private(set) var phase: Phase = .idle
    private(set) var direction: Direction = .send
    /// The last accepted progress tick of the transfer in flight; nil before
    /// the first one.
    private(set) var progress: TransferProgress?
    private(set) var speedBytesPerSec: Double = 0
    /// The transfer goes through a stored-transfer server rather
    /// than a croc peer.
    private(set) var isStoredTransfer = false

    let settings: AppSettings
    let vault: StoredTransferVault

    /// Relay path of the transfer in flight, captured at start so mid-transfer
    /// settings edits don't lie in the trust UI.
    private(set) var activeRelay: AppSettings.RelayKind = .publicDefault

    #if DEBUG
    /// Harness-only (AutoVerify --shown-relay): the relay the trust UI
    /// names, so a run through a local relay photographs like a default one.
    var harnessShownRelay: AppSettings.RelayKind?

    /// Harness-only (AutoVerify --disable-local): kills the LAN race so the
    /// custom relay path is provably exercised. Not a user setting.
    var harnessDisableLocal = false

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

    private let engine: any TransferEngine
    private let background = BackgroundCoordinator()
    /// What the transfer in flight, or the last one, started from. `retry()`
    /// runs it again.
    private var lastRequest: TransferRequest?
    private var backgroundExpired = false
    private var streamTask: Task<Void, Never>?
    /// The engine start in flight. Until it returns an ID, cancelling this task
    /// is how a cancel reaches the engine.
    private var startTask: Task<EngineTransfer, any Error>?
    /// The engine transfer this controller started last; every cancel targets it,
    /// so a late cancel cannot reach the next transfer.
    private var transferID: TransferID?
    @ObservationIgnored private var scopes = SecurityScopes()
    private var cancelRequested = false
    private var declineRequested = false
    private var receivedText: String?
    private var outDir: URL?
    @ObservationIgnored private var speed = TransferSpeed()
    private var sendConfirmArmed = false
    private var autoAcceptActive = false
    private var blockedAutoAccept = false
    /// Bumped once per `run()`. The async conflict scan, the bookmark capture
    /// and the end of the event loop capture it and act only if it still
    /// matches, so work that outlives a fast transfer cannot land on the next
    /// one.
    private var transferGeneration = 0
    /// True once any payload bytes moved -- gates the "resume" hint so it
    /// never appears on failures before the transfer started.
    private var sawTransferBytes = false
    /// Arrives just before `.done` on a stored upload.
    private var storedReceipt: StoredReceipt?

    /// History sink; set once at app startup. nil in previews.
    @ObservationIgnored var history: HistoryStore?
    @ObservationIgnored private var pendingRecord: HistoryDraft?

    init(
        settings: AppSettings, vault: StoredTransferVault,
        engine: any TransferEngine = CrocEngine()
    ) {
        self.settings = settings
        self.vault = vault
        self.engine = engine
    }

    // MARK: - Intents

    /// Starts `request`. While a transfer is active this does nothing and
    /// returns false.
    @discardableResult
    func start(_ request: TransferRequest) -> Bool {
        guard !isActive else { return false }
        lastRequest = request
        direction = request.direction
        isStoredTransfer = request.isStored
        let call = EngineStart(request, settings: settings, disableLocal: disablesLocal)
        let relay: AppSettings.RelayKind =
            if case .receive = request { settings.receiveRelayKind } else { settings.relayKind }
        activeRelay = shownRelay ?? relay
        // Both-sides confirm holds a live send at .confirmSend once connected.
        sendConfirmArmed =
            request.direction == .send && !request.isStored && settings.bothSidesConfirm
        autoAcceptActive = call.autoAccept
        pendingRecord = HistoryDraft(request, storedServer: EngineStart.storedServer(settings))
        outDir = nil
        var sentFiles: [URL] = []
        switch request {
        case .sendFiles(let urls, _), .storedSend(let urls, _, _):
            scopes.open(urls)
            sentFiles = urls
        case .receive(_, let folder, let folderIsScoped),
            .storedReceive(_, let folder, let folderIsScoped):
            outDir = folder
            if folderIsScoped { scopes.open([folder]) }
        case .sendText:
            break
        }
        run(call)
        if !sentFiles.isEmpty { captureBookmarks(for: sentFiles) }
        return true
    }

    /// Runs the last request again with the same inputs. Only a failure whose
    /// remedy is Try Again allows it; anything else does nothing and returns
    /// false.
    @discardableResult
    func retry() -> Bool {
        guard case .failed(let failure) = phase, failure.remedy == .tryAgain,
            let request = lastRequest
        else { return false }
        reset()
        return start(request)
    }

    /// Whether History can offer Revoke: an unexpired, unrevoked upload whose
    /// receipt this device still holds.
    func canRevoke(_ record: TransferRecord, now: Date = .now) -> Bool {
        guard let id = record.storedID, record.revokedAt == nil,
            let expiresAt = record.expiresAt, expiresAt > now
        else { return false }
        return vault.receipt(id: id) != nil
    }

    /// Deletes a stored upload from its server and marks its record. A
    /// server that no longer has it counts as revoked. Runs alongside any
    /// active transfer. Throws `EngineFailure`; show it as a
    /// `TransferFailure` with `isStored` set.
    func revoke(_ record: TransferRecord) async throws {
        guard let id = record.storedID, let receipt = vault.receipt(id: id) else {
            throw EngineFailure(code: .other, message: "no receipt for this upload")
        }
        try await engine.revokeStored(receipt, proxy: EngineStart.proxies(settings))
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
        cancelEngineTransfer()
    }

    /// Stops the engine transfer without recording a Cancel tap, so the
    /// auto-accept block does not read as one (`TransferFailure.endedByUser`).
    private func cancelEngineTransfer() {
        // Before the engine has returned an ID, cancel the start itself; run()
        // also cancels by ID once one exists, in case the start finished first.
        guard let id = transferID else {
            startTask?.cancel()
            return
        }
        Task { await engine.cancel(id) }
    }

    /// Back to idle. Only meaningful from terminal phases. No event follows a
    /// terminal one, but the event loop may still be unwinding (Try Again
    /// resets at once), and cancelling streamTask ends it.
    func reset() {
        streamTask?.cancel()
        streamTask = nil
        scopes.releaseAll()
        receivedText = nil
        storedReceipt = nil
        outDir = nil
        progress = nil
        speedBytesPerSec = 0
        backgroundExpired = false
        phase = .idle
    }

    // MARK: - Engine plumbing

    /// The relay the trust UI names and whether the LAN route is off. Only a
    /// harness run overrides either.
    private var shownRelay: AppSettings.RelayKind? {
        #if DEBUG
        harnessShownRelay
        #else
        nil
        #endif
    }

    private var disablesLocal: Bool {
        #if DEBUG
        harnessDisableLocal
        #else
        false
        #endif
    }

    private func run(_ call: EngineStart) {
        phase = .starting
        let title =
            switch direction {
            case .send:
                String(
                    localized: "Sending with CrocApp",
                    comment: "Title of the iOS Live Activity while sending.")
            case .receive:
                String(
                    localized: "Receiving with CrocApp",
                    comment: "Title of the iOS Live Activity while receiving.")
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
        let generation = transferGeneration
        sawTransferBytes = false
        receivedText = nil
        storedReceipt = nil
        offeredFileNames = []
        currentCode = nil
        progress = nil
        speed = TransferSpeed()
        speedBytesPerSec = 0
        transferID = nil
        let engine = engine
        streamTask = Task {
            do {
                // Its own task, so cancelEngineTransfer() can cancel the start
                // alone; cancelling streamTask would also end the event loop.
                let starting = Task { try await call.run(on: engine) }
                startTask = starting
                let transfer = try await starting.value
                startTask = nil
                transferID = transfer.id
                if cancelRequested { cancelEngineTransfer() }
                for await event in transfer.events { handle(event) }
            } catch {
                startTask = nil
                // Startup failure before any event flowed -- still tear down
                // the idle-timer lock / BG task requested at the top of run().
                background.transferEnded(success: false)
                // Same precedence as handle(.failed): an expiry that surfaces
                // as a thrown error must keep the resume hint, not fall back
                // to generic copy.
                phase = .failed(TransferFailure(Self.startFailure(error), situation: situation))
                finishRecord(cancelRequested ? .cancelled : .failed, summary: nil)
            }
            // After a reset, a new start (Try Again) may already hold scopes,
            // and those are not this transfer's to release.
            if transferGeneration == generation { scopes.releaseAll() }
        }
    }

    private func handle(_ event: TransferEvent) {
        switch event {
        case .codeReady(let code):
            currentCode = code
            if pendingRecord?.codeHint.isEmpty == true {
                pendingRecord?.codeHint = CodeHint.code(code)
            }
            phase = .waiting(code: code)
        case .connected:
            // Both-sides confirm: gate the send behind an explicit confirm. The pipe write
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
                pendingRecord?.offer(list)
            }
            let blocked = names.filter { ReceivedName.isUnsafe($0) }
            if autoAcceptActive {
                // croc is already proceeding (NoPrompt); the only brake left
                // for unsafe names is killing the transfer.
                if !blocked.isEmpty {
                    blockedAutoAccept = true
                    cancelEngineTransfer()
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
            let doneBytes = p.bytesFinished + p.fileSent
            speed.record(doneBytes)
            speedBytesPerSec = speed.bytesPerSecond
            if doneBytes > 0 { sawTransferBytes = true }
            background.progressChanged(
                bytesDone: doneBytes,
                totalBytes: p.totalSize,
                fileName: p.fileName)
            progress = p
            // Only the first tick sets the phase, so whatever observes just
            // the phase does not redraw at the tick rate. Observation may skip
            // an equal value on its own; this does not rely on it.
            if phase != .transferring { phase = .transferring }
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
            // The block's cancel is fire-and-forget, so a small enough transfer
            // can reach .done before the cancellation lands on the engine. The
            // bytes are already written either way; this only stops the UI and
            // the history record reporting a plain success for a blocked one.
            if blockedAutoAccept {
                phase = .failed(.blockedAutoAccept)
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
            phase = .failed(TransferFailure(failure, situation: situation))
            // blockedAutoAccept outranks cancelRequested, in case Cancel was
            // also tapped: "Cancelled" in history reads as a user action.
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

    /// What the failure copy is chosen by, besides the engine's code.
    private var situation: TransferFailure.Situation {
        TransferFailure.Situation(
            direction: direction, isStored: isStoredTransfer, cancelRequested: cancelRequested,
            declineRequested: declineRequested, backgroundExpired: backgroundExpired,
            blockedAutoAccept: blockedAutoAccept, autoAcceptActive: autoAcceptActive,
            bytesMoved: sawTransferBytes)
    }

    /// A capture that lands once the next transfer has started must not
    /// attach to that one's record. A transfer that terminates first leaves
    /// `pendingRecord` nil and the record carries no bookmarks, so Send Again
    /// hides rather than breaks.
    private func captureBookmarks(for urls: [URL]) {
        let generation = transferGeneration
        Task { [weak self] in
            guard let all = await HistoryDraft.bookmarks(for: urls), let self,
                self.transferGeneration == generation
            else { return }
            self.pendingRecord?.bookmarks = all
        }
    }

    private static func scanConflicts(names: [String], in dir: URL) async -> [String] {
        await Task.detached(priority: .userInitiated) {
            names.filter {
                FileManager.default.fileExists(atPath: dir.appendingPathComponent($0).path)
            }
        }.value
    }

    /// Runs at `.done`, `.failed` and the startup `catch`. It clears the draft
    /// first, so a double terminal event records once, and it must run while
    /// `receivedText` is still set.
    private func finishRecord(_ status: TransferRecord.Status, summary: Summary?) {
        guard let draft = pendingRecord else { return }
        pendingRecord = nil
        guard settings.saveTransferHistory else { return }
        history?.add(draft.record(status: status, summary: summary, receivedText: receivedText))
    }

    /// A start error as the failure the copy is chosen by.
    private static func startFailure(_ error: any Error) -> EngineFailure {
        switch error {
        case CrocEngineError.startFailed(let failure): failure
        case CrocEngineError.transferActive:
            EngineFailure(code: .transferActive, message: "another transfer is active")
        default: EngineFailure(code: .other, message: "\(error)")
        }
    }
}
