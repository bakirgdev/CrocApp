import CrocKit
import Foundation
import SwiftData
import Testing

@testable import CrocApp

/// Drives `TransferController` through `FakeTransferEngine`: the phase each
/// event leads to, the failure copy, what reaches the engine, and the history
/// record each path leaves.
@MainActor @Suite struct TransferControllerTests {
    private let engine = FakeTransferEngine()
    private let settings: AppSettings
    private let vault: StoredTransferVault
    private let history: HistoryStore
    private let controller: TransferController

    /// Never created: a missing file has no bookmark, and a missing folder no
    /// conflicts, so neither background task can change what a test sees.
    private let file = URL(filePath: "/CrocAppTests.missing/notes.txt")
    private let folder = FileManager.default.temporaryDirectory.appending(
        path: "CrocAppTests.\(UUID().uuidString)")

    private static let code = "wiry-alpha-bravo"
    private static let blockedCopy =
        "Blocked: this transfer contained unsafe file names, so auto-accept cancelled it."
    private static let resumeHint =
        " Start the same transfer again; replacing the partly received files resumes it."

    init() throws {
        let suiteName = "CrocAppTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        settings = AppSettings(defaults: defaults, secrets: FakeSecretStore())
        // Settings a test changes stay in memory, so the suite's file can go now.
        settings.persist = false
        defaults.removePersistentDomain(forName: suiteName)
        vault = StoredTransferVault(secrets: FakeSecretStore())
        history = HistoryStore(container: HistoryStore.makeContainer(inMemory: true))
        controller = TransferController(settings: settings, vault: vault, engine: engine)
        controller.history = history
    }

    // MARK: - Send

    @Test func sendGoesFromCodeToDone() async throws {
        controller.startSend(urls: [file], customCode: "")
        #expect(controller.phase.name == "starting")
        try await waitForTransfer()
        let start = try await firstStart()
        guard case .send(let paths, let text, let options) = start else {
            Issue.record("started \(start), not a send")
            return
        }
        #expect(paths == [file.path])
        #expect(text == nil)
        #expect(!options.ask)

        try await deliver(.codeReady(Self.code))
        #expect(controller.phase.waitingCode == Self.code)
        #expect(controller.currentCode == Self.code)

        try await deliver(.progress(Self.progress(step: "waiting")))
        #expect(controller.phase.waitingCode == Self.code, "a waiting tick keeps the code up")

        try await deliver(.connected)
        #expect(controller.phase.name == "connecting")
        #expect(controller.currentCode == Self.code, "the code outlives .waiting")

        try await deliver(.progress(Self.progress(sent: 40)))
        #expect(controller.phase.name == "transferring")

        try await deliver(.done(Self.summary(files: 1, totalSize: 100)))
        let done = try #require(controller.phase.result)
        #expect(done.summary.success)
        #expect(done.receivedText == nil)

        let record = try onlyRecord()
        #expect(record.isSend)
        #expect(record.status == .completed)
        #expect(record.codeHint == "wiry-…", "backfilled from the generated code")
        #expect(record.names == ["notes.txt"])
        #expect(record.fileCount == 1)
        #expect(record.totalBytes == 100)
        #expect(!record.isText)
    }

    @Test func confirmOnBothSidesHoldsTheSendUntilAccepted() async throws {
        settings.bothSidesConfirm = true
        controller.startSend(urls: [file], customCode: "")
        try await waitForTransfer()
        let start = try await firstStart()
        guard case .send(_, _, let options) = start else {
            Issue.record("started \(start), not a send")
            return
        }
        #expect(options.ask)

        try await deliver(.codeReady(Self.code))
        try await deliver(.connected)
        #expect(controller.phase.name == "confirmSend")

        try await deliver(.progress(Self.progress()))
        #expect(controller.phase.name == "confirmSend", "a tick must not clobber the prompt")

        controller.respond(accept: true)
        #expect(controller.phase.name == "connecting")
        try await waitUntil("the engine to get the answer") { await engine.responses.count == 1 }
        #expect(await engine.responses == [.init(accept: true, policy: .keepBoth)])
        await engine.finish()
    }

    @Test func aSecondStartWhileActiveStartsNothing() async throws {
        controller.startSend(urls: [file], customCode: "")
        try await waitForTransfer()
        try await deliver(.codeReady(Self.code))

        controller.startSend(urls: [file], customCode: "other-code-word")
        controller.startReceive(code: "other-code-word", into: folder, folderIsScoped: false)
        #expect(controller.phase.waitingCode == Self.code)
        #expect(controller.direction == .send)

        try await deliver(.connected)
        #expect(await engine.starts.count == 1)
        await engine.finish()
    }

    // MARK: - Receive

    @Test func manualReceiveShowsTheOfferAndRecordsADecline() async throws {
        controller.startReceive(code: Self.code, into: folder, folderIsScoped: false)
        try await waitForTransfer()
        let start = try await firstStart()
        guard case .receive(let code, let options) = start else {
            Issue.record("started \(start), not a receive")
            return
        }
        #expect(code == Self.code)
        #expect(options.outDir == folder.path)
        #expect(!options.autoAccept)

        try await deliver(.connected)
        try await deliver(.fileList(Self.fileList(["notes.txt", "../escape.txt"])))
        let offer = try #require(controller.phase.offer)
        #expect(offer.names == ["notes.txt", "../escape.txt"])
        #expect(offer.blocked == ["../escape.txt"])
        #expect(offer.conflicts.isEmpty)
        #expect(controller.offeredFileNames == ["notes.txt", "../escape.txt"])

        try await deliver(.progress(Self.progress()))
        #expect(controller.phase.name == "incoming", "a tick must not clobber the prompt")

        controller.respond(accept: false)
        try await waitUntil("the engine to get the answer") { await engine.responses.count == 1 }
        #expect(await engine.responses == [.init(accept: false, policy: .keepBoth)])
        #expect(controller.phase.name == "incoming", "the stream, not the tap, ends a decline")

        try await deliver(.failed(EngineFailure(code: .refused, message: "refused files")))
        #expect(controller.phase.failureCopy == "You declined the transfer.")
        #expect(controller.endedByUser)

        let record = try onlyRecord()
        #expect(!record.isSend)
        #expect(record.status == .declined)
        #expect(record.names == ["notes.txt", "../escape.txt"])
        #expect(record.fileCount == 2)
        #expect(record.totalBytes == 20)
        #expect(record.codeHint == "wiry-…")
    }

    @Test func incomingListsFilesThatAlreadyExist() async throws {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        try Data("old".utf8).write(to: folder.appending(path: "notes.txt"))

        controller.startReceive(code: Self.code, into: folder, folderIsScoped: false)
        try await waitForTransfer()
        try await deliver(.fileList(Self.fileList(["notes.txt", "new.txt"])))

        try await waitUntil("the conflict scan") {
            controller.phase.offer?.conflicts == ["notes.txt"]
        }
        #expect(controller.phase.offer?.blocked == [])
        await engine.finish()
    }

    @Test func confirmOnBothSidesTurnsReceiveAutoAcceptOff() async throws {
        settings.autoAccept = true
        settings.bothSidesConfirm = true
        controller.startReceive(code: Self.code, into: folder, folderIsScoped: false)
        try await waitForTransfer()
        let start = try await firstStart()
        guard case .receive(_, let options) = start else {
            Issue.record("started \(start), not a receive")
            return
        }
        #expect(!options.autoAccept)
        #expect(options.ask)

        try await deliver(.fileList(Self.fileList(["notes.txt"])))
        #expect(controller.phase.name == "incoming")
        await engine.finish()
    }

    @Test(arguments: [true, false])
    func autoAcceptCancelsAnOfferWithAnUnsafeName(endsWithDone: Bool) async throws {
        settings.autoAccept = true
        controller.startReceive(code: Self.code, into: folder, folderIsScoped: false)
        try await waitForTransfer()
        let start = try await firstStart()
        guard case .receive(_, let options) = start else {
            Issue.record("started \(start), not a receive")
            return
        }
        #expect(options.autoAccept)
        let id = try #require(await engine.transferIDs.last)

        try await deliver(.connected)
        try await deliver(.fileList(Self.fileList(["notes.txt", "/etc/hosts"])))
        #expect(controller.phase.name == "connecting", "no prompt under auto-accept")
        try await waitUntil("the engine to get the cancel") { await engine.cancels == [id] }

        // The cancel is fire-and-forget, so a small transfer can still finish.
        if endsWithDone {
            try await deliver(.done(Self.summary(files: 2, totalSize: 20)))
        } else {
            try await deliver(.failed(EngineFailure(code: .cancelled, message: "context canceled")))
        }
        #expect(controller.phase.failureCopy == Self.blockedCopy)
        #expect(try onlyRecord().status == .failed, "a block is not a user cancel")
        #expect(!controller.endedByUser, "the user tapped nothing, so the failure haptic plays")
        #expect(await engine.cancels == [id])
    }

    @Test func autoAcceptExplainsASenderWhoAskedToConfirm() async throws {
        settings.autoAccept = true
        controller.startReceive(code: Self.code, into: folder, folderIsScoped: false)
        try await waitForTransfer()
        try await deliver(.connected)
        try await deliver(.fileList(Self.fileList(["notes.txt"])))

        try await deliver(.failed(EngineFailure(code: .refused, message: "refused files")))
        #expect(
            controller.phase.failureCopy
                == "The sender asked to confirm this transfer manually, which auto-accept can't answer. Turn off Auto-Accept Transfers in Settings and try again, or ask the sender to resend without their confirmation option."
        )
        #expect(await engine.cancels.isEmpty)
        #expect(!controller.endedByUser)
        #expect(try onlyRecord().status == .failed)
    }

    @Test func textReceiveEndsWithTheText() async throws {
        controller.startReceive(code: Self.code, into: folder, folderIsScoped: false)
        try await waitForTransfer()
        try await deliver(.text("hello"))
        try await deliver(.done(Self.summary(files: 0, totalSize: 5)))

        let done = try #require(controller.phase.result)
        #expect(done.receivedText == "hello")
        #expect(try onlyRecord().isText)
    }

    @Test(arguments: [true, false])
    func resumeHintNeedsBytesToHaveMoved(bytesMoved: Bool) async throws {
        controller.startReceive(code: Self.code, into: folder, folderIsScoped: false)
        try await waitForTransfer()
        try await deliver(.connected)
        try await deliver(.progress(Self.progress(sent: bytesMoved ? 40 : 0)))

        try await deliver(.failed(EngineFailure(code: .connectionLost, message: "EOF")))
        let copy = "Lost connection to the other device." + (bytesMoved ? Self.resumeHint : "")
        #expect(controller.phase.failureCopy == copy)
        #expect(try onlyRecord().status == .failed)
    }

    // MARK: - Start and cancel

    @Test func cancelBeforeTheEngineAnswersReachesTheTransferOnceStarted() async throws {
        await engine.holdNextStart()
        controller.startSend(urls: [file], customCode: "")
        try await waitUntil("the start to be held") { await engine.isHoldingStart }

        controller.cancel()
        #expect(await engine.cancels.isEmpty, "no ID to cancel yet")

        await engine.releaseStart()
        try await waitForTransfer()
        #expect(await engine.cancelledStarts == 1, "the cancel reached the start itself")
        let id = try #require(await engine.transferIDs.first)
        try await waitUntil("the deferred cancel") { await engine.cancels == [id] }

        try await deliver(.failed(EngineFailure(code: .cancelled, message: "context canceled")))
        #expect(controller.phase.failureCopy == "Transfer cancelled.")
        #expect(try onlyRecord().status == .cancelled)
        #expect(await engine.cancels == [id], "cancelled once")
    }

    /// The engine frees itself before its terminal event, so a busy engine
    /// means a transfer that is really running: no retry.
    @Test func aBusyEngineFailsTheStartWithoutRetry() async throws {
        await engine.failNextStart(with: .transferActive)
        controller.startSend(urls: [file], customCode: "")
        try await waitUntil("the start to fail") { controller.phase.name == "failed" }

        #expect(
            controller.phase.failureCopy
                == "Another transfer is still running. Wait for it to end, then try again.")
        #expect(await engine.starts.count == 1)
        #expect(try onlyRecord().status == .failed)
    }

    @Test func aStartRightAfterTheLastEventStarts() async throws {
        controller.startReceive(code: Self.code, into: folder, folderIsScoped: false)
        try await waitForTransfer()
        try await deliver(.failed(EngineFailure(code: .joinedEarly, message: "flate")))
        #expect(
            controller.phase.failureCopy
                == "The other device wasn't sending yet. Start the send there first, then enter the code again."
        )
        #expect(await engine.starts.count == 1, "no automatic retry")

        controller.reset()
        controller.startReceive(code: Self.code, into: folder, folderIsScoped: false)
        try await waitUntil("the second start") { await engine.starts.count == 2 }
        try await waitForTransfer()
        #expect(await engine.transferIDs.count == 2, "the engine took it at once")
        #expect(controller.phase.name == "starting")
        await engine.finish()
    }

    /// The engine's watchdog ends a cancel croc never honoured. Its copy wins
    /// over "Transfer cancelled.", because only a relaunch helps.
    @Test func aStuckEngineAfterCancelAsksForARelaunch() async throws {
        controller.startSend(urls: [file], customCode: "")
        try await waitForTransfer()
        try await deliver(.codeReady(Self.code))
        controller.cancel()
        let id = try #require(await engine.transferIDs.first)
        try await waitUntil("the engine to get the cancel") { await engine.cancels == [id] }

        try await deliver(.failed(EngineFailure(code: .engineStuck, message: "did not return")))
        #expect(
            controller.phase.failureCopy
                == "The cancelled transfer didn't stop. Quit and reopen CrocApp to transfer again.")
        #expect(try onlyRecord().status == .cancelled)

        controller.reset()
        await engine.failNextStart(
            with: .startFailed(EngineFailure(code: .engineStuck, message: "never returned")))
        controller.startReceive(code: Self.code, into: folder, folderIsScoped: false)
        try await waitUntil("the start to fail") { controller.phase.name == "failed" }
        #expect(
            controller.phase.failureCopy
                == "The cancelled transfer didn't stop. Quit and reopen CrocApp to transfer again.")
    }

    @Test func startFailureShowsItsCopyAndIsRecorded() async throws {
        await engine.failNextStart(
            with: .startFailed(EngineFailure(code: .relayUnreachable, message: "i/o timeout")))
        controller.startReceive(code: Self.code, into: folder, folderIsScoped: false)
        try await waitUntil("the start to fail") { controller.phase.name == "failed" }

        #expect(
            controller.phase.failureCopy
                == "Couldn't reach the relay. Check your internet connection.")
        #expect(await engine.starts.count == 1, "only transferActive is retried")
        let record = try onlyRecord()
        #expect(!record.isSend)
        #expect(record.status == .failed)
    }

    // MARK: - Stored transfers

    @Test func storedSendEndsOnItsReceipt() async throws {
        settings.storedServer = "https://store.example"
        controller.startStoreSend(urls: [file], downloads: 2, lifetimeSeconds: 3600)
        #expect(controller.isStoredTransfer)
        try await waitForTransfer()
        let start = try await firstStart()
        guard case .storeSend(let paths, let options) = start else {
            Issue.record("started \(start), not a stored send")
            return
        }
        #expect(paths == [file.path])
        #expect(options.server == "https://store.example")
        #expect(options.downloads == 2)
        #expect(options.lifetimeSeconds == 3600)

        try await deliver(.progress(Self.progress(sent: 50)))
        #expect(controller.phase.name == "transferring")

        let receipt = StoredReceipt(
            id: "up1", origin: "https://store.example", uploadToken: "token",
            link: "https://store.example/s/up1#v1.key",
            expiresAt: Date(timeIntervalSince1970: 2_000_000_000), downloads: 2)
        try await deliver(.stored(receipt))
        try await deliver(.done(Self.summary()))

        #expect(controller.phase.storedReceipt == receipt)
        #expect(vault.receipt(id: "up1") == receipt)
        let record = try onlyRecord()
        #expect(record.status == .completed)
        #expect(record.storedID == "up1")
        #expect(record.expiresAt == receipt.expiresAt)
        #expect(record.codeHint == "store.example")
    }

    // MARK: - Helpers

    /// Polls `condition` until it holds, then fails the test after `timeout`.
    /// The controller handles events and calls the engine on its own tasks,
    /// so a test cannot await either directly.
    private func waitUntil(
        _ what: String, timeout: Duration = .seconds(30),
        sourceLocation: SourceLocation = #_sourceLocation,
        _ condition: () async -> Bool
    ) async throws {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: timeout)
        var met = await condition()
        while !met, clock.now < deadline {
            try await Task.sleep(for: .milliseconds(5))
            met = await condition()
        }
        try #require(
            met, "timed out after \(timeout) waiting for \(what)", sourceLocation: sourceLocation)
    }

    /// Waits until a start has returned and the controller listens for events.
    private func waitForTransfer(
        sourceLocation: SourceLocation = #_sourceLocation
    ) async throws {
        try await waitUntil("the transfer to start", sourceLocation: sourceLocation) {
            await engine.isDrained
        }
    }

    /// Emits `event` and waits until the controller has handled it.
    private func deliver(
        _ event: TransferEvent, sourceLocation: SourceLocation = #_sourceLocation
    ) async throws {
        await engine.emit(event)
        try await waitUntil("the controller to handle \(event)", sourceLocation: sourceLocation) {
            await engine.isDrained
        }
    }

    private func firstStart(
        sourceLocation: SourceLocation = #_sourceLocation
    ) async throws -> FakeTransferEngine.Start {
        try #require(await engine.starts.first, sourceLocation: sourceLocation)
    }

    private func onlyRecord(
        sourceLocation: SourceLocation = #_sourceLocation
    ) throws -> TransferRecord {
        let records = try history.container.mainContext.fetch(FetchDescriptor<TransferRecord>())
        try #require(records.count == 1, "history records", sourceLocation: sourceLocation)
        return records[0]
    }

    // FileList, TransferProgress and Summary have no public initializer; the
    // engine decodes them from JSON, and so do these.

    private static func decode<T: Decodable>(_ object: [String: Any]) throws -> T {
        try JSONDecoder().decode(T.self, from: JSONSerialization.data(withJSONObject: object))
    }

    private static func fileList(_ names: [String]) throws -> FileList {
        try decode([
            "files": names.map { ["name": $0, "size": 10] as [String: Any] },
            "emptyFolders": 0,
            "totalSize": 10 * names.count,
        ])
    }

    private static func progress(step: String = "transferring", sent: Int = 0) throws
        -> TransferProgress
    {
        try decode([
            "currentFile": 1, "totalFiles": 1, "fileName": "notes.txt", "fileSent": sent,
            "fileSize": 100, "bytesFinished": 0, "totalSize": 100, "step": step,
        ])
    }

    private static func summary(files: Int = 1, totalSize: Int = 100) throws -> Summary {
        try decode(["success": true, "files": files, "totalSize": totalSize])
    }
}

/// `Phase` is not `Equatable`; tests compare its case name and payloads.
extension TransferController.Phase {
    var name: String {
        switch self {
        case .idle: "idle"
        case .starting: "starting"
        case .waiting: "waiting"
        case .connecting: "connecting"
        case .confirmSend: "confirmSend"
        case .incoming: "incoming"
        case .transferring: "transferring"
        case .done: "done"
        case .stored: "stored"
        case .failed: "failed"
        }
    }

    var waitingCode: String? {
        guard case .waiting(let code) = self else { return nil }
        return code
    }

    var offer: (names: [String], conflicts: [String], blocked: [String])? {
        guard case .incoming(let list, let conflicts, let blocked) = self else { return nil }
        return (list.files.map(\.name), conflicts, blocked)
    }

    var result: (summary: Summary, receivedText: String?)? {
        guard case .done(let summary, let receivedText) = self else { return nil }
        return (summary, receivedText)
    }

    var storedReceipt: StoredReceipt? {
        guard case .stored(let receipt) = self else { return nil }
        return receipt
    }

    var failureCopy: String? {
        guard case .failed(let copy) = self else { return nil }
        return copy
    }
}
