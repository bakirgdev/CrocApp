import CrocKit
import Foundation
import Observation
import SwiftData
import Synchronization
import Testing

@testable import CrocApp

/// Drives `TransferController` through `FakeTransferEngine`: the phase each
/// event leads to, the failure it ends with, what reaches the engine, and the
/// history record each path leaves.
@MainActor @Suite struct TransferControllerTests {
    private let engine = FakeTransferEngine()
    private let settings: AppSettings
    private let vaultSecrets = FakeSecretStore()
    private let vault: StoredTransferVault
    private let history: HistoryStore
    private let controller: TransferController

    /// Never created: a missing file has no bookmark, and a missing folder no
    /// conflicts, so neither background task can change what a test sees.
    private let file = URL(filePath: "/CrocAppTests.missing/notes.txt")
    private let folder = FileManager.default.temporaryDirectory.appending(
        path: "CrocAppTests.\(UUID().uuidString)")

    private static let code = "wiry-alpha-bravo"

    init() {
        settings = AppSettings(storage: MemorySettingsStorage(), secrets: FakeSecretStore())
        vault = StoredTransferVault(secrets: vaultSecrets)
        history = HistoryStore(container: HistoryStore.makeContainer(inMemory: true))
        controller = TransferController(settings: settings, vault: vault, engine: engine)
        controller.history = history
    }

    // MARK: - Send

    @Test func sendGoesFromCodeToDone() async throws {
        #expect(controller.start(.sendFiles(urls: [file], code: "")))
        #expect(controller.phase == .starting)
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
        #expect(controller.phase == .transferring)
        #expect(controller.progress?.fileSent == 40)

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

    @Test func savingHistoryOffRecordsNoFinishedTransfer() async throws {
        settings.saveTransferHistory = false
        controller.start(.sendFiles(urls: [file], code: ""))
        try await waitForTransfer()
        try await deliver(.codeReady(Self.code))
        try await deliver(.connected)
        try await deliver(.done(Self.summary(files: 1, totalSize: 100)))

        #expect(try #require(controller.phase.result).summary.success)
        #expect(history.recordCount() == 0)
    }

    @Test func aCustomCodeSendLeavesNoHintInHistory() async throws {
        controller.start(.sendFiles(urls: [file], code: "mom-blue-tiger"))
        try await waitForTransfer()
        try await deliver(.codeReady("mom-blue-tiger"))
        try await deliver(.connected)
        try await deliver(.done(Self.summary(files: 1, totalSize: 100)))

        #expect(try onlyRecord().codeHint == "")
    }

    @Test func aReceiveWithASavedCodeLeavesNoHintInHistory() async throws {
        let saved = SavedCodes(secrets: FakeSecretStore())
        saved.save(SavedCode(name: "Mom", code: "mom-blue-tiger"))
        controller.savedCodes = saved
        controller.start(.receive(code: " mom-blue-tiger ", folder: folder, folderIsScoped: false))
        try await waitForTransfer()
        try await deliver(.failed(EngineFailure(code: .refused, message: "refused files")))

        #expect(try onlyRecord().codeHint == "")
    }

    @Test func aReceiveWithAnotherCodeStillKeepsItsHint() async throws {
        let saved = SavedCodes(secrets: FakeSecretStore())
        saved.save(SavedCode(name: "Mom", code: "mom-blue-tiger"))
        controller.savedCodes = saved
        controller.start(.receive(code: Self.code, folder: folder, folderIsScoped: false))
        try await waitForTransfer()
        try await deliver(.failed(EngineFailure(code: .refused, message: "refused files")))

        #expect(try onlyRecord().codeHint == "wiry-…")
    }

    @Test func savingHistoryOffRecordsNoFailedTransferEither() async throws {
        settings.saveTransferHistory = false
        await engine.failNextStart(
            with: .startFailed(EngineFailure(code: .relayUnreachable, message: "i/o timeout")))
        controller.start(.receive(code: Self.code, folder: folder, folderIsScoped: false))
        try await waitUntil("the start to fail") { controller.phase.name == "failed" }

        #expect(history.recordCount() == 0)
    }

    @Test func savingHistoryOffKeepsTheRecordsAlreadyThere() async throws {
        history.add(
            TransferRecord(
                isSend: false, status: .completed, isText: false, fileCount: 2, totalBytes: 20,
                names: ["old.txt", "older.txt"], codeHint: "wiry-…", bookmarks: []))
        settings.saveTransferHistory = false
        controller.start(.sendFiles(urls: [file], code: ""))
        try await waitForTransfer()
        try await deliver(.codeReady(Self.code))
        try await deliver(.connected)
        try await deliver(.done(Self.summary(files: 1, totalSize: 100)))

        let record = try onlyRecord()
        #expect(record.names == ["old.txt", "older.txt"], "the new transfer left no record")
    }

    @Test func savingHistoryBackOnRecordsAgain() async throws {
        settings.saveTransferHistory = false
        settings.saveTransferHistory = true
        controller.start(.sendFiles(urls: [file], code: ""))
        try await waitForTransfer()
        try await deliver(.codeReady(Self.code))
        try await deliver(.connected)
        try await deliver(.done(Self.summary(files: 1, totalSize: 100)))

        #expect(try onlyRecord().names == ["notes.txt"])
    }

    @Test func confirmOnBothSidesHoldsTheSendUntilAccepted() async throws {
        settings.bothSidesConfirm = true
        controller.start(.sendFiles(urls: [file], code: ""))
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
        controller.start(.sendFiles(urls: [file], code: ""))
        try await waitForTransfer()
        try await deliver(.codeReady(Self.code))

        #expect(!controller.start(.sendFiles(urls: [file], code: "other-code-word")))
        #expect(
            !controller.start(
                .receive(code: "other-code-word", folder: folder, folderIsScoped: false)))
        #expect(controller.phase.waitingCode == Self.code)
        #expect(controller.direction == .send)

        try await deliver(.connected)
        #expect(await engine.starts.count == 1)
        await engine.finish()
    }

    // MARK: - Receive

    @Test func manualReceiveShowsTheOfferAndRecordsADecline() async throws {
        controller.start(.receive(code: Self.code, folder: folder, folderIsScoped: false))
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
        let failure = try #require(controller.phase.failure)
        #expect(failure == .declinedByUser)
        #expect(failure.endedByUser)
        #expect(failure.detail == nil, "the user's own decline is not a failure")
        #expect(failure.remedy == nil)

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

        controller.start(.receive(code: Self.code, folder: folder, folderIsScoped: false))
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
        controller.start(.receive(code: Self.code, folder: folder, folderIsScoped: false))
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
        controller.start(.receive(code: Self.code, folder: folder, folderIsScoped: false))
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
        #expect(controller.phase.failure == .blockedAutoAccept)
        #expect(try onlyRecord().status == .failed, "a block is not a user cancel")
        #expect(
            controller.phase.failure?.endedByUser == false,
            "the user tapped nothing, so the failure haptic plays")
        #expect(await engine.cancels == [id])
    }

    @Test func autoAcceptExplainsASenderWhoAskedToConfirm() async throws {
        settings.autoAccept = true
        controller.start(.receive(code: Self.code, folder: folder, folderIsScoped: false))
        try await waitForTransfer()
        try await deliver(.connected)
        try await deliver(.fileList(Self.fileList(["notes.txt"])))

        try await deliver(.failed(EngineFailure(code: .refused, message: "refused files")))
        let failure = try #require(controller.phase.failure)
        #expect(failure == .autoAcceptCannotConfirm)
        #expect(failure.remedy == .openSettings(.general))
        #expect(await engine.cancels.isEmpty)
        #expect(!failure.endedByUser)
        #expect(try onlyRecord().status == .failed)
    }

    @Test func textReceiveEndsWithTheText() async throws {
        controller.start(.receive(code: Self.code, folder: folder, folderIsScoped: false))
        try await waitForTransfer()
        try await deliver(.text("hello"))
        try await deliver(.done(Self.summary(files: 0, totalSize: 5)))

        let done = try #require(controller.phase.result)
        #expect(done.receivedText == "hello")
        #expect(try onlyRecord().isText)
    }

    @Test(arguments: [true, false])
    func resumeHintNeedsBytesToHaveMoved(bytesMoved: Bool) async throws {
        controller.start(.receive(code: Self.code, folder: folder, folderIsScoped: false))
        try await waitForTransfer()
        try await deliver(.connected)
        try await deliver(.progress(Self.progress(sent: bytesMoved ? 40 : 0)))

        try await deliver(.failed(EngineFailure(code: .connectionLost, message: "EOF")))
        let failure = try #require(controller.phase.failure)
        #expect((failure.detail == TransferFailure.resumeHint) == bytesMoved)
        #expect(failure.remedy == .tryAgain)
        #expect(try onlyRecord().status == .failed)
    }

    // MARK: - Start and cancel

    @Test func cancelBeforeTheEngineAnswersReachesTheTransferOnceStarted() async throws {
        await engine.holdNextStart()
        controller.start(.sendFiles(urls: [file], code: ""))
        try await waitUntil("the start to be held") { await engine.isHoldingStart }

        controller.cancel()
        #expect(await engine.cancels.isEmpty, "no ID to cancel yet")

        await engine.releaseStart()
        try await waitForTransfer()
        #expect(await engine.cancelledStarts == 1, "the cancel reached the start itself")
        let id = try #require(await engine.transferIDs.first)
        try await waitUntil("the deferred cancel") { await engine.cancels == [id] }

        try await deliver(.failed(EngineFailure(code: .cancelled, message: "context canceled")))
        #expect(controller.phase.failure == .cancelledByUser)
        #expect(controller.phase.failure?.endedByUser == true)
        #expect(try onlyRecord().status == .cancelled)
        #expect(await engine.cancels == [id], "cancelled once")
    }

    /// The engine frees itself before its terminal event, so a busy engine
    /// means a transfer that is really running: no retry.
    @Test func aBusyEngineFailsTheStartWithoutRetry() async throws {
        await engine.failNextStart(with: .transferActive)
        controller.start(.sendFiles(urls: [file], code: ""))
        try await waitUntil("the start to fail") { controller.phase.name == "failed" }

        let failure = try #require(controller.phase.failure)
        #expect(failure.remedy == .tryAgain, "the user may try again once it ends")
        #expect(failure.detail != nil)
        #expect(await engine.starts.count == 1)
        #expect(try onlyRecord().status == .failed)
    }

    @Test func aStartRightAfterTheLastEventStarts() async throws {
        controller.start(.receive(code: Self.code, folder: folder, folderIsScoped: false))
        try await waitForTransfer()
        try await deliver(.failed(EngineFailure(code: .joinedEarly, message: "flate")))
        #expect(
            controller.phase.failure?.remedy == nil,
            "the sender's code may change, so the same code may not work")
        #expect(await engine.starts.count == 1, "no automatic retry")

        controller.reset()
        controller.start(.receive(code: Self.code, folder: folder, folderIsScoped: false))
        try await waitUntil("the second start") { await engine.starts.count == 2 }
        try await waitForTransfer()
        #expect(await engine.transferIDs.count == 2, "the engine took it at once")
        #expect(controller.phase.name == "starting")
        await engine.finish()
    }

    /// The engine's watchdog ends a cancel croc never honoured. Its failure
    /// wins over the cancel, because only a relaunch helps.
    @Test func aStuckEngineAfterCancelAsksForARelaunch() async throws {
        controller.start(.sendFiles(urls: [file], code: ""))
        try await waitForTransfer()
        try await deliver(.codeReady(Self.code))
        controller.cancel()
        let id = try #require(await engine.transferIDs.first)
        try await waitUntil("the engine to get the cancel") { await engine.cancels == [id] }

        try await deliver(.failed(EngineFailure(code: .engineStuck, message: "did not return")))
        #expect(controller.phase.failure == .engineStuck)
        #expect(controller.phase.failure?.remedy == nil)
        #expect(try onlyRecord().status == .cancelled)

        controller.reset()
        await engine.failNextStart(
            with: .startFailed(EngineFailure(code: .engineStuck, message: "never returned")))
        controller.start(.receive(code: Self.code, folder: folder, folderIsScoped: false))
        try await waitUntil("the start to fail") { controller.phase.name == "failed" }
        #expect(controller.phase.failure == .engineStuck)
        #expect(!controller.retry(), "only a relaunch helps")
    }

    @Test func startFailureShowsItsCopyAndIsRecorded() async throws {
        await engine.failNextStart(
            with: .startFailed(EngineFailure(code: .relayUnreachable, message: "i/o timeout")))
        controller.start(.receive(code: Self.code, folder: folder, folderIsScoped: false))
        try await waitUntil("the start to fail") { controller.phase.name == "failed" }

        let failure = try #require(controller.phase.failure)
        #expect(failure.remedy == .tryAgain)
        #expect(!failure.endedByUser)
        #expect(await engine.starts.count == 1, "no automatic retry")
        let record = try onlyRecord()
        #expect(!record.isSend)
        #expect(record.status == .failed)
    }

    // MARK: - Try Again

    @Test func retryRunsTheSameRequestAgain() async throws {
        await engine.failNextStart(
            with: .startFailed(EngineFailure(code: .relayUnreachable, message: "i/o timeout")))
        controller.start(.receive(code: Self.code, folder: folder, folderIsScoped: false))
        try await waitUntil("the start to fail") { controller.phase.name == "failed" }
        #expect(controller.phase.failure?.remedy == .tryAgain)

        #expect(controller.retry())
        #expect(controller.phase == .starting)
        try await waitForTransfer()
        let starts = await engine.starts
        try #require(starts.count == 2)
        for start in starts {
            guard case .receive(let code, let options) = start else {
                Issue.record("started \(start), not a receive")
                continue
            }
            #expect(code == Self.code)
            #expect(options.outDir == folder.path)
        }
        #expect(controller.direction == .receive)

        try await deliver(.done(Self.summary()))
        #expect(controller.phase.result != nil)
        let records = try history.container.mainContext.fetch(FetchDescriptor<TransferRecord>())
        #expect(
            records.map(\.status).sorted { $0.rawValue < $1.rawValue } == [.completed, .failed])
    }

    @Test func retryKeepsTheSendAndItsCode() async throws {
        controller.start(.sendFiles(urls: [file], code: "custom-code-word"))
        try await waitForTransfer()
        try await deliver(.connected)
        try await deliver(.failed(EngineFailure(code: .connectionLost, message: "EOF")))

        #expect(controller.retry())
        // The last stream has ended, so the engine reads as drained until the
        // second start replaces it.
        try await waitUntil("the second start") { await engine.starts.count == 2 }
        try await waitForTransfer()
        let starts = await engine.starts
        guard case .send(let paths, let text, let options) = starts[1] else {
            Issue.record("started \(starts[1]), not a send")
            return
        }
        #expect(paths == [file.path])
        #expect(text == nil)
        #expect(options.customCode == "custom-code-word")
        await engine.finish()
    }

    /// Try Again never appears where retrying cannot help, and nothing else
    /// can run it either.
    @Test func retryNeedsATryAgainFailure() async throws {
        #expect(!controller.retry(), "nothing has run yet")

        controller.start(.receive(code: Self.code, folder: folder, folderIsScoped: false))
        try await waitForTransfer()
        #expect(!controller.retry(), "a transfer is running")

        try await deliver(.failed(EngineFailure(code: .wrongCode, message: "bad")))
        #expect(controller.phase.failure?.remedy == nil)
        #expect(!controller.retry(), "the user must change the code")
        #expect(await engine.starts.count == 1)
        #expect(controller.phase.name == "failed")
    }

    // MARK: - Progress

    /// Ticks arrive at about 10 Hz. Only the first one changes `phase`, so a
    /// view that reads just the phase does not redraw at that rate.
    @Test func progressTicksChangeProgressAndNotPhase() async throws {
        controller.start(.sendFiles(urls: [file], code: ""))
        try await waitForTransfer()
        try await deliver(.connected)
        try await deliver(.progress(Self.progress(sent: 40)))
        #expect(controller.phase == .transferring)

        let phaseChanged = ChangeFlag()
        let progressChanged = ChangeFlag()
        withObservationTracking {
            _ = controller.phase
        } onChange: {
            phaseChanged.set()
        }
        withObservationTracking {
            _ = controller.progress
        } onChange: {
            progressChanged.set()
        }
        try await deliver(.progress(Self.progress(sent: 60)))

        #expect(controller.progress?.fileSent == 60)
        #expect(progressChanged.isSet)
        #expect(!phaseChanged.isSet)
        #expect(controller.phase == .transferring)
        await engine.finish()
    }

    // MARK: - Stored transfers

    @Test func storedSendEndsOnItsReceipt() async throws {
        settings.storedServer = "https://store.example"
        controller.start(.storedSend(urls: [file], downloads: 2, lifetimeSeconds: 3600))
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
        #expect(controller.phase == .transferring)

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

    @Test func startRecordsWhenTheTransferStarted() async {
        #expect(controller.startedAt == nil)
        let before = Date.now
        controller.start(.sendFiles(urls: [file], code: ""))
        let startedAt = controller.startedAt
        #expect(startedAt.map { $0 >= before && $0 <= .now } == true)
        await engine.finish()
    }

    @Test func storedReceiptSavedFollowsTheVaultWrite() async throws {
        #expect(controller.storedReceiptSaved)
        vaultSecrets.failWrites = true
        try await runStoredSend()
        #expect(controller.phase.storedReceipt == Self.receipt)
        #expect(!controller.storedReceiptSaved, "the Keychain write failed")
        #expect(vault.receipt(id: Self.receipt.id) == Self.receipt, "kept for this launch")
    }

    @Test func storedReceiptSavedStaysTrueWhenTheVaultSaves() async throws {
        try await runStoredSend()
        #expect(controller.storedReceiptSaved)
    }

    @Test func startResetsStoredReceiptSaved() async throws {
        vaultSecrets.failWrites = true
        try await runStoredSend()
        #expect(!controller.storedReceiptSaved)

        controller.reset()
        #expect(controller.start(.sendFiles(urls: [file], code: "")))
        #expect(controller.storedReceiptSaved)
        await engine.finish()
    }

    // MARK: - Revoke from the link screen

    @Test func revokingTheShownLinkRemovesItAndMarksItsRecord() async throws {
        try await runStoredSend()
        let record = try onlyRecord()
        #expect(record.revokedAt == nil)

        try await controller.revoke(Self.receipt)

        #expect(await engine.revokes == [Self.receipt])
        #expect(vault.receipt(id: Self.receipt.id) == nil)
        #expect(record.revokedAt != nil)
    }

    @Test func revokingNeedsNoHistoryRecord() async throws {
        settings.saveTransferHistory = false
        try await runStoredSend()
        #expect(history.recordCount() == 0)

        try await controller.revoke(Self.receipt)

        #expect(await engine.revokes == [Self.receipt])
        #expect(vault.receipt(id: Self.receipt.id) == nil)
        #expect(history.recordCount() == 0)
    }

    @Test func aFailedRevokeKeepsTheLinkAndItsRecord() async throws {
        try await runStoredSend()
        let record = try onlyRecord()
        await engine.failRevokes(with: EngineFailure(code: .relayUnreachable, message: "timeout"))

        await #expect(throws: EngineFailure.self) { try await controller.revoke(Self.receipt) }

        #expect(vault.receipt(id: Self.receipt.id) == Self.receipt)
        #expect(record.revokedAt == nil)
    }

    private static let receipt = StoredReceipt(
        id: "up1", origin: "https://store.example", uploadToken: "token",
        link: "https://store.example/s/up1#v1.key",
        expiresAt: Date(timeIntervalSince1970: 2_000_000_000), downloads: 2)

    /// A stored send taken to its link screen, with its history record.
    private func runStoredSend() async throws {
        settings.storedServer = "https://store.example"
        controller.start(.storedSend(urls: [file], downloads: 2, lifetimeSeconds: 3600))
        try await waitForTransfer()
        try await deliver(.stored(Self.receipt))
        try await deliver(.done(Self.summary()))
        try #require(controller.phase.storedReceipt == Self.receipt)
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

/// Set from an observation's `onChange`, which may run on any thread.
private nonisolated final class ChangeFlag: Sendable {
    private let value = Mutex(false)
    var isSet: Bool { value.withLock { $0 } }
    func set() { value.withLock { $0 = true } }
}

/// Case names and payloads, for checks that ignore the rest of a phase.
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

    var failure: TransferFailure? {
        guard case .failed(let failure) = self else { return nil }
        return failure
    }
}
