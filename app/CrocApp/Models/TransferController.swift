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
        case stored(StoredReceipt)
        case failed(TransferFailure)

        /// The case without its payload: what a view keys a cross-fade on, so
        /// a progress tick or a changed offer does not replay it.
        enum Kind: Hashable {
            case idle, starting, waiting, connecting, confirmSend, incoming
            case transferring, done, stored, failed
        }

        var kind: Kind {
            switch self {
            case .idle: .idle
            case .starting: .starting
            case .waiting: .waiting
            case .connecting: .connecting
            case .confirmSend: .confirmSend
            case .incoming: .incoming
            case .transferring: .transferring
            case .done: .done
            case .stored: .stored
            case .failed: .failed
            }
        }

        var needsAnswer: Bool {
            switch self {
            case .confirmSend, .incoming: true
            default: false
            }
        }

        /// Cancel is on screen, or would be: not at the accept gate, where it
        /// would answer the sender on the user's behalf (components.md →
        /// AcceptGate), and not once the transfer has ended.
        var canCancel: Bool {
            switch self {
            case .starting, .waiting, .connecting, .confirmSend, .transferring: true
            default: false
            }
        }

        var shownCode: String? {
            guard case .waiting(let code) = self else { return nil }
            return code
        }
    }

    /// Why a transfer ended other than by its own result. Several can apply
    /// to one transfer (a Cancel tap after the auto-accept block); the later
    /// case outranks the earlier, in the order below, for the failure screen
    /// and the history record alike.
    enum EndReason: Int, Comparable {
        case declined
        /// The user's Cancel, or a Shortcuts action that was cancelled.
        case cancelled
        /// iOS ended the background task, which cancelled the transfer.
        case backgroundExpired
        /// Auto-accept cancelled an offer that holds an unsafe name.
        case unsafeName

        static func < (a: Self, b: Self) -> Bool { a.rawValue < b.rawValue }

        /// A background expiry is recorded as cancelled although the screen says
        /// iOS paused the transfer (known issue); an unsafe name is `.failed`
        /// because the history schema has no blocked case and "Cancelled" reads
        /// as a user action.
        var recordStatus: TransferRecord.Status {
            switch self {
            case .declined: .declined
            case .cancelled, .backgroundExpired: .cancelled
            case .unsafeName: .failed
            }
        }
    }

    /// What the transfer in flight owns. `start` and `reset` replace it, so
    /// nothing outlives its transfer, and a task that outlives its transfer
    /// finds a different `token`.
    private struct Run {
        let token = UUID()
        var endReason: EndReason?
        var streamTask: Task<Void, Never>?
        /// The engine start in flight. Until it returns an ID, cancelling this task
        /// is how a cancel reaches the engine.
        var startTask: Task<EngineTransfer, any Error>?
        /// The engine transfer this run started; every cancel targets it, so a
        /// late cancel cannot reach the next transfer.
        var transferID: TransferID?
        var scopes = SecurityScopes()
        var outDir: URL?
        var receivedText: String?
        /// Arrives just before `.done` on a stored upload.
        var storedReceipt: StoredReceipt?
        var pendingRecord: HistoryDraft?
        var speed = TransferSpeed()
        var sendConfirmArmed = false
        var autoAcceptActive = false
        /// True once any payload bytes moved -- gates the "resume" hint so it
        /// never appears on failures before the transfer started.
        var sawTransferBytes = false

        mutating func end(_ reason: EndReason) { endReason = max(endReason ?? reason, reason) }
    }

    @ObservationIgnored private var run = Run()

    private(set) var phase: Phase = .idle
    private(set) var direction: Direction = .send
    /// The last accepted progress tick of the transfer in flight; nil before
    /// the first one.
    private(set) var progress: TransferProgress? {
        didSet {
            let percent = progress?.percent
            if percent != progressPercent { progressPercent = percent }
        }
    }
    /// `progress` as a whole percent. It changes at most 101 times a transfer,
    /// where `progress` changes at the tick rate, so what shows only the percent
    /// (the menu-bar label) reads this and redraws no more often than it moves.
    private(set) var progressPercent: Int?
    private(set) var speedBytesPerSec: Double = 0
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

    var lastOutputFolder: URL? { run.outDir }

    /// Names (paths relative to the receive folder) the sender offered in the
    /// current or last receive. Shortcuts uses them to hand the files back.
    private(set) var offeredFileNames: [String] = []

    /// File and folder names of the current or last send, from its request.
    /// Empty for a text send, whose payload must never be shown as a name.
    var sentItemNames: [String] {
        switch lastRequest {
        case .sendFiles(let urls, _), .storedSend(let urls, _, _): urls.map(\.lastPathComponent)
        default: []
        }
    }

    /// When the current or last transfer started. The receive result screen
    /// tells a file this receive wrote from an older one by it.
    private(set) var startedAt: Date?

    /// False when the receipt of the link on the `.stored` screen could not
    /// be saved to the Keychain. The vault keeps it until the app quits, so
    /// Revoke works only until then.
    private(set) var storedReceiptSaved = true

    /// The code of the send in flight, once croc has made one. Unlike `phase`
    /// it survives the move to `.connecting`, so a caller that looks late
    /// cannot miss it.
    private(set) var currentCode: String?

    private let engine: any TransferEngine
    private let background = BackgroundCoordinator()
    /// What the transfer in flight, or the last one, started from. `retry()`
    /// runs it again.
    private var lastRequest: TransferRequest?

    /// History sink; set once at app startup. nil in previews.
    @ObservationIgnored var history: HistoryStore?
    /// Codes the user saved: a transfer that used one leaves no code hint in History.
    @ObservationIgnored var savedCodes: SavedCodes?

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
        run = Run()
        lastRequest = request
        startedAt = .now
        direction = request.direction
        isStoredTransfer = request.isStored
        let call = EngineStart(request, settings: settings)
        let relay: AppSettings.RelayKind =
            if case .receive = request { settings.receiveRelayKind } else { settings.relayKind }
        activeRelay = shownRelay ?? relay
        run.sendConfirmArmed =
            request.direction == .send && !request.isStored && settings.bothSidesConfirm
        run.autoAcceptActive = call.autoAccept
        run.pendingRecord = HistoryDraft(request, storedServer: EngineStart.storedServer(settings))
        if case .receive(let code, _, _) = request, savedCodes?.contains(code: code) == true {
            run.pendingRecord?.dropHint()
        }
        var sentFiles: [URL] = []
        switch request {
        case .sendFiles(let urls, _), .storedSend(let urls, _, _):
            run.scopes.open(urls)
            sentFiles = urls
        case .receive(_, let folder, let folderIsScoped),
            .storedReceive(_, let folder, let folderIsScoped):
            run.outDir = folder
            if folderIsScoped { run.scopes.open([folder]) }
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
        try await revoke(receipt)
    }

    /// Revokes the link the `.stored` screen shows. Unlike `revoke(_ record:)`
    /// it needs no history record, so a link sent with Save Transfer History
    /// off can be revoked too; a record, if there is one, is marked. Throws
    /// `EngineFailure`.
    func revoke(_ receipt: StoredReceipt) async throws {
        try await engine.revokeStored(receipt, proxy: EngineStart.proxies(settings))
        vault.remove(id: receipt.id)
        if let record = history?.record(storedID: receipt.id) {
            history?.markRevoked(record)
        }
    }

    /// Answer the accept/decline prompt raised by `.incoming` or `.confirmSend`.
    /// `policy` decides what an accepted receive does with files that already
    /// exist; a send ignores it.
    func respond(accept: Bool, policy: FilePolicy = .keepBoth) {
        // A prompt only shows after the transfer's own events, so its ID exists.
        if let id = run.transferID {
            Task { await engine.respond(id, accept: accept, policy: policy) }
        }
        if accept {
            phase = .connecting
        } else {
            run.end(.declined)
        }
        // Decline: croc notifies the sender (SendError path) and the session
        // ends with a failed/done event; phase advances from the stream.
    }

    /// Stops the transfer for `reason`. Only a `.cancelled` one is the user's
    /// Cancel tap; the others must not read as one (`TransferFailure.endedByUser`).
    func cancel(reason: EndReason = .cancelled) {
        run.end(reason)
        cancelEngineTransfer()
    }

    private func cancelEngineTransfer() {
        // Before the engine has returned an ID, cancel the start itself; run()
        // also cancels by ID once one exists, in case the start finished first.
        guard let id = run.transferID else {
            run.startTask?.cancel()
            return
        }
        Task { await engine.cancel(id) }
    }

    /// Back to idle. Only meaningful from terminal phases. No event follows a
    /// terminal one, but the event loop may still be unwinding (Try Again
    /// resets at once), and cancelling streamTask ends it.
    func reset() {
        run.streamTask?.cancel()
        run.scopes.releaseAll()
        run = Run()
        progress = nil
        speedBytesPerSec = 0
        phase = .idle
    }

    // MARK: - Engine plumbing

    /// The relay the trust UI names. Only a harness run overrides it.
    private var shownRelay: AppSettings.RelayKind? {
        #if DEBUG
        harnessShownRelay
        #else
        nil
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
        background.transferStarted(
            title: title, showFileNames: settings.systemSurfacesShowFileNames
        ) { [weak self] in self?.cancel(reason: .backgroundExpired) }
        // These outlive `reset()`: a Shortcuts action reads them once the
        // transfer is over.
        storedReceiptSaved = true
        offeredFileNames = []
        currentCode = nil
        let token = run.token
        let engine = engine
        run.streamTask = Task {
            do {
                // Its own task, so cancelEngineTransfer() can cancel the start
                // alone; cancelling streamTask would also end the event loop.
                let starting = Task { try await call.run(on: engine) }
                run.startTask = starting
                let transfer = try await starting.value
                run.startTask = nil
                run.transferID = transfer.id
                if run.endReason != nil { cancelEngineTransfer() }
                for await event in transfer.events { handle(event) }
            } catch {
                run.startTask = nil
                // Startup failure before any event flowed -- still tear down
                // the idle-timer lock / BG task requested at the top of run().
                background.transferEnded(success: false)
                // Same precedence as handle(.failed): an expiry that surfaces
                // as a thrown error must keep the resume hint, not fall back
                // to generic copy.
                phase = .failed(TransferFailure(Self.startFailure(error), situation: situation))
                finishRecord(run.endReason?.recordStatus ?? .failed, summary: nil)
            }
            // After a reset, a new start (Try Again) may already hold scopes,
            // and those are not this transfer's to release.
            if run.token == token { run.scopes.releaseAll() }
        }
    }

    private func handle(_ event: TransferEvent) {
        switch event {
        case .codeReady(let code):
            currentCode = code
            if run.pendingRecord?.codeHint.isEmpty == true,
                run.pendingRecord?.keepsNoHint == false
            {
                run.pendingRecord?.codeHint = CodeHint.code(code)
            }
            phase = .waiting(code: code)
        case .connected:
            // Both-sides confirm: gate the send behind an explicit confirm. The pipe write
            // buffers, so confirming before croc reaches its prompt is safe.
            if direction == .send, run.sendConfirmArmed {
                run.sendConfirmArmed = false
                phase = .confirmSend
            } else {
                phase = .connecting
            }
        case .fileList(let list):
            let names = list.files.map(\.name)
            if run.pendingRecord?.isSend == false {
                offeredFileNames = names
                run.pendingRecord?.offer(list)
            }
            let blocked = names.filter { ReceivedName.isUnsafe($0) }
            if run.autoAcceptActive {
                // croc is already proceeding (NoPrompt); the only brake left
                // for unsafe names is killing the transfer.
                if !blocked.isEmpty { cancel(reason: .unsafeName) }
                return
            }
            // Show the sheet immediately; a 10k-file stat scan on the main
            // actor would freeze the accept UI, so conflicts fill in async.
            phase = .incoming(list, conflicts: [], blocked: blocked)
            guard let dir = run.outDir else { return }
            let token = run.token
            Task { [weak self] in
                let conflicts = await Self.scanConflicts(names: names, in: dir)
                guard let self, !conflicts.isEmpty, self.run.token == token,
                    case .incoming = self.phase
                else { return }
                self.phase = .incoming(list, conflicts: conflicts, blocked: blocked)
            }
        case .progress(let p):
            // step "waiting" ticks arrive while the code screen should stay up.
            guard !p.isWaiting else { return }
            // Progress ticks keep flowing while a prompt is unanswered --
            // never clobber .incoming/.confirmSend; respond() moves the
            // phase forward.
            if phase.needsAnswer { return }
            let doneBytes = p.bytesDone
            run.speed.record(doneBytes)
            speedBytesPerSec = run.speed.bytesPerSecond
            if doneBytes > 0 { run.sawTransferBytes = true }
            background.progressChanged(
                // A negative completed count makes the system progress indeterminate.
                bytesDone: p.isBundling ? -1 : doneBytes,
                totalBytes: p.totalSize,
                fileName: p.isBundling ? "" : p.fileName)
            progress = p
            // Only the first tick sets the phase, so whatever observes just
            // the phase does not redraw at the tick rate. Observation may skip
            // an equal value on its own; this does not rely on it.
            if phase != .transferring { phase = .transferring }
        case .text(let t):
            run.receivedText = t
        case .stored(var receipt):
            #if DEBUG
            if let shown = harnessShownLinkOrigin {
                receipt = Self.relinked(receipt, origin: shown)
            }
            #endif
            run.storedReceipt = receipt
            // A failed write is logged by the vault; the link still works,
            // only a revoke after relaunch is lost, and the screen says so.
            storedReceiptSaved = vault.add(receipt)
            run.pendingRecord?.storedID = receipt.id
            run.pendingRecord?.expiresAt = receipt.expiresAt
        case .done(let summary):
            background.transferEnded(success: true)
            // The block's cancel is fire-and-forget, so a small enough transfer
            // can reach .done before the cancellation lands on the engine. The
            // bytes are already written either way; this only stops the UI and
            // the history record reporting a plain success for a blocked one.
            if run.endReason == .unsafeName {
                phase = .failed(.blockedAutoAccept)
                finishRecord(.failed, summary: summary)
            } else if let storedReceipt = run.storedReceipt {
                phase = .stored(storedReceipt)
                settings.recordSuccessfulTransfer()
                finishRecord(.completed, summary: summary)
            } else {
                phase = .done(summary, receivedText: run.receivedText)
                if summary.success { settings.recordSuccessfulTransfer() }
                finishRecord(summary.success ? .completed : .failed, summary: summary)
            }
        case .failed(let failure):
            background.transferEnded(success: false)
            phase = .failed(TransferFailure(failure, situation: situation))
            finishRecord(run.endReason?.recordStatus ?? .failed, summary: nil)
        }
    }

    private var situation: TransferFailure.Situation {
        TransferFailure.Situation(
            direction: direction, isStored: isStoredTransfer, endReason: run.endReason,
            autoAcceptActive: run.autoAcceptActive, bytesMoved: run.sawTransferBytes)
    }

    /// A capture that lands once the next transfer has started must not
    /// attach to that one's record. A transfer that terminates first leaves
    /// `pendingRecord` nil and the record carries no bookmarks, so Send Again
    /// hides rather than breaks.
    private func captureBookmarks(for urls: [URL]) {
        let token = run.token
        Task { [weak self] in
            guard let all = await HistoryDraft.bookmarks(for: urls), let self,
                self.run.token == token
            else { return }
            self.run.pendingRecord?.bookmarks = all
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
        guard let draft = run.pendingRecord else { return }
        run.pendingRecord = nil
        guard settings.saveTransferHistory else { return }
        history?.add(draft.record(status: status, summary: summary, receivedText: run.receivedText))
    }

    private static func startFailure(_ error: any Error) -> EngineFailure {
        switch error {
        case CrocEngineError.startFailed(let failure): failure
        case CrocEngineError.transferActive:
            EngineFailure(code: .transferActive, message: "another transfer is active")
        default: EngineFailure(code: .other, message: "\(error)")
        }
    }
}
