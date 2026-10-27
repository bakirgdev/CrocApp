import CrocKit
import Foundation
import Testing

@testable import CrocApp

/// One `AppRouter.path` drives both layouts (design/platforms.md → Layout by
/// width): the stack under Home in compact width, the sidebar row and its
/// detail's pushed screens in regular width.
@MainActor @Suite struct AppRouterLayoutTests {
    private let router = AppRouter()

    // MARK: - Selection and detail path

    @Test func anEmptyPathSelectsSend() {
        #expect(router.selection == .send)
        #expect(router.detailPath.isEmpty)
    }

    @Test func thePathStartsAtTheSelectedRow() {
        router.path = [.receive, .howItWorks]
        #expect(router.selection == .receive)
        #expect(router.detailPath == [.howItWorks])
    }

    @Test func selectingARowReplacesThePathAndPopsTheDetail() {
        router.path = [.send, .howItWorks]
        router.selection = .history
        #expect(router.path == [.history])
        #expect(router.detailPath.isEmpty)
    }

    @Test func pushingInTheDetailKeepsTheRow() {
        router.path = [.receive]
        router.detailPath = [.howItWorks]
        #expect(router.path == [.receive, .howItWorks])
        #expect(router.selection == .receive)
    }

    @Test func aPathThatStartsOutsideTheRowsLeavesSendSelected() {
        router.path = [.howItWorks]
        #expect(router.selection == .send)
        #expect(router.detailPath == [.howItWorks])

        router.detailPath = [.howItWorks, .advancedSettings]
        #expect(router.path == [.howItWorks, .advancedSettings])
        router.detailPath = []
        #expect(router.path.isEmpty)
    }

    @Test func theSidebarRowsFollowThePlatform() {
        #if os(macOS)
        #expect(AppRouter.SidebarItem.rows == [.send, .receive, .history])
        // The Mac has the Settings scene, so Settings is a screen pushed in
        // the detail, never a row.
        router.path = [.settings]
        #expect(router.selection == .send)
        #expect(router.detailPath == [.settings])
        #else
        #expect(AppRouter.SidebarItem.rows == [.send, .receive, .history, .settings])
        router.path = [.settings, .advancedSettings]
        #expect(router.selection == .settings)
        #expect(router.detailPath == [.advancedSettings])
        #endif
    }

    @Test func aTransfersDirectionNamesItsRow() {
        #expect(AppRouter.SidebarItem(direction: .send) == .send)
        #expect(AppRouter.SidebarItem(direction: .receive) == .receive)
    }

    // MARK: - Entry points land in the layout

    @Test func everyEntryPointLandsOnItsRow() throws {
        router.openSend(with: [URL(filePath: "/tmp/a.txt")])
        #expect(router.selection == .send)
        #expect(router.detailPath.isEmpty)

        router.openReceive()
        #expect(router.selection == .receive)

        router.open(try #require(TransferLink.parse("wiry-alpha-bravo")))
        #expect(router.selection == .receive)
        #expect(router.pendingReceive == .code("wiry-alpha-bravo"))

        router.openSend(text: "hello")
        #expect(router.selection == .send)
        #expect(router.pendingSendText == "hello")
    }

    @Test func menuCommandsNavigate() {
        router.showHistory()
        #expect(router.selection == .history)

        router.showHowItWorks()
        router.showHowItWorks()
        #expect(router.path == [.history, .howItWorks], "pushed once, on what is open")
        #expect(router.selection == .history)

        router.showSettings()
        #expect(router.path == [.settings])
    }

    @Test func nothingNavigatesWhileATransferIsActive() throws {
        let controller = TransferController(
            settings: AppSettings(storage: MemorySettingsStorage(), secrets: FakeSecretStore()),
            vault: StoredTransferVault(secrets: FakeSecretStore()),
            engine: FakeTransferEngine())
        router.attach(controller: controller)
        router.path = [.history]
        #expect(!router.isBusy)

        #expect(controller.start(.sendFiles(urls: [URL(filePath: "/tmp/a.txt")], code: "")))
        #expect(router.isBusy)

        let file = URL(filePath: "/tmp/b.txt")
        router.openSend(with: [file])
        router.openSend(text: "hello")
        router.open(try #require(TransferLink.parse("wiry-alpha-bravo")))

        #expect(router.path == [.history], "the user stays where they are")
        #expect(router.pendingSendURLs == [file])
        #expect(router.pendingSendText == "hello")
        #expect(router.pendingReceive == .code("wiry-alpha-bravo"), "kept for the next Receive")
        controller.cancel()
    }
}

/// What the sidebar row of the transfer in flight shows (design/components.md →
/// SidebarRow), and the phase questions the menu bar asks.
@MainActor @Suite struct SidebarRowStateTests {
    @Test func aLivePhaseHasAState() {
        let cases: [(TransferController.Phase, SidebarRowState.Kind)] = [
            (.starting, .connecting),
            (.connecting, .connecting),
            (.waiting(code: "wiry-alpha-bravo"), .waiting),
            (.confirmSend, .review),
        ]
        for (phase, kind) in cases {
            let state = SidebarRowState(phase: phase, progress: nil)
            #expect(state?.kind == kind)
            #expect(state?.percent == nil)
        }
    }

    @Test func anIncomingRequestAsksForAReview() throws {
        let list: FileList = try Self.decode([
            "files": [["name": "a.txt", "size": 10]], "emptyFolders": 0, "totalSize": 10,
        ])
        let state = SidebarRowState(
            phase: .incoming(list, conflicts: [], blocked: []), progress: nil)
        #expect(state?.kind == .review)
    }

    @Test func aFinishedOrFailedTransferLeavesTheRowAtRest() throws {
        let summary: Summary = try Self.decode(["success": true, "files": 1, "totalSize": 10])
        let failure = TransferFailure(
            EngineFailure(code: .other, message: "boom"), situation: .init())
        #expect(SidebarRowState(phase: .idle, progress: nil) == nil)
        #expect(SidebarRowState(phase: .done(summary, receivedText: nil), progress: nil) == nil)
        #expect(SidebarRowState(phase: .failed(failure), progress: nil) == nil)
    }

    @Test func transferringShowsTheWholeTransfersIntegerPercent() throws {
        let half = try Self.progress(finished: 30, sent: 20, total: 100)
        #expect(SidebarRowState(phase: .transferring, progress: half)?.percent == 50)

        let third = try Self.progress(finished: 0, sent: 1, total: 3)
        #expect(SidebarRowState.percent(of: third) == 33)

        let over = try Self.progress(finished: 90, sent: 40, total: 100)
        #expect(SidebarRowState.percent(of: over) == 100, "never past 100")
    }

    @Test func anUnknownTotalHasNoPercent() throws {
        #expect(SidebarRowState(phase: .transferring, progress: nil)?.percent == nil)
        let unknown = try Self.progress(finished: 0, sent: 5, total: 0)
        #expect(SidebarRowState(phase: .transferring, progress: unknown)?.percent == nil)
    }

    @Test func aProgressTickChangesThePercentAndNotThePhaseKind() throws {
        let early = SidebarRowState(
            phase: .transferring, progress: try Self.progress(finished: 0, sent: 10, total: 100))
        let later = SidebarRowState(
            phase: .transferring, progress: try Self.progress(finished: 0, sent: 11, total: 100))
        #expect(early != later)
        #expect(early?.kind == later?.kind, "what is announced watches the kind only")
    }

    @Test func theRowSpeaksItsStateInWords() {
        #expect(SidebarRow.spoken(.send, .connecting, percent: nil) == "Send, connecting")
        #expect(
            SidebarRow.spoken(.send, .waiting, percent: nil)
                == "Send, waiting for the other device")
        #expect(
            SidebarRow.spoken(.receive, .review, percent: nil) == "Receive, needs your answer")
        #expect(SidebarRow.spoken(.send, .transferring, percent: 42) == "Send, 42 percent")
        #expect(SidebarRow.spoken(.receive, .transferring, percent: nil) == "Receive, transferring")
    }

    // MARK: - Phase questions

    @Test func onlyAQuestionNeedsAnAnswer() throws {
        let list: FileList = try Self.decode([
            "files": [["name": "a.txt", "size": 10]], "emptyFolders": 0, "totalSize": 10,
        ])
        #expect(TransferController.Phase.confirmSend.needsAnswer)
        #expect(TransferController.Phase.incoming(list, conflicts: [], blocked: []).needsAnswer)
        #expect(!TransferController.Phase.transferring.needsAnswer)
        #expect(!TransferController.Phase.idle.needsAnswer)
    }

    @Test func cancelIsOfferedUntilTheTransferEndsExceptAtTheAcceptGate() throws {
        let list: FileList = try Self.decode([
            "files": [["name": "a.txt", "size": 10]], "emptyFolders": 0, "totalSize": 10,
        ])
        let summary: Summary = try Self.decode(["success": true, "files": 1, "totalSize": 10])
        for phase in [
            TransferController.Phase.starting, .waiting(code: "wiry-alpha-bravo"), .connecting,
            .confirmSend, .transferring,
        ] {
            #expect(phase.canCancel)
        }
        #expect(!TransferController.Phase.incoming(list, conflicts: [], blocked: []).canCancel)
        #expect(!TransferController.Phase.idle.canCancel)
        #expect(!TransferController.Phase.done(summary, receivedText: nil).canCancel)
    }

    @Test func onlyAWaitingSendHasACodeToCopy() {
        #expect(
            TransferController.Phase.waiting(code: "wiry-alpha-bravo").shownCode
                == "wiry-alpha-bravo")
        #expect(TransferController.Phase.connecting.shownCode == nil)
        #expect(TransferController.Phase.transferring.shownCode == nil)
    }

    // FileList, TransferProgress and Summary have no public initializer; the
    // engine decodes them from JSON, and so do these.

    private static func decode<T: Decodable>(_ object: [String: Any]) throws -> T {
        try JSONDecoder().decode(T.self, from: JSONSerialization.data(withJSONObject: object))
    }

    private static func progress(finished: Int, sent: Int, total: Int) throws -> TransferProgress {
        try decode([
            "currentFile": 0, "totalFiles": 1, "fileName": "notes.txt", "fileSent": sent,
            "fileSize": total, "bytesFinished": finished, "totalSize": total,
            "step": "transferring",
        ])
    }
}
