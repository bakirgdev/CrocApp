import CrocKit
import Foundation
import Testing

@testable import CrocApp

/// What the tab of the transfer in flight shows, and the phase questions the
/// menu bar asks.
@MainActor @Suite struct TransferTabStateTests {
    @Test func aLivePhaseHasAState() {
        let cases: [(TransferController.Phase, TransferTabState.Kind)] = [
            (.starting, .connecting),
            (.connecting, .connecting),
            (.waiting(code: "wiry-alpha-bravo"), .waiting),
            (.confirmSend, .review),
            (.transferring, .transferring),
        ]
        for (phase, kind) in cases {
            #expect(TransferTabState(phase: phase, direction: .send)?.kind == kind)
        }
    }

    @Test func theTabIsTheOneOfTheTransfersDirection() throws {
        let list: FileList = try Self.decode([
            "files": [["name": "a.txt", "size": 10]], "emptyFolders": 0, "totalSize": 10,
        ])
        let incoming = TransferTabState(
            phase: .incoming(list, conflicts: [], blocked: []), direction: .receive)
        #expect(incoming?.kind == .review)
        #expect(incoming?.screen == .receive)
        #expect(TransferTabState(phase: .confirmSend, direction: .send)?.screen == .send)
    }

    @Test func aFinishedOrFailedTransferLeavesEveryTabAtRest() throws {
        let summary: Summary = try Self.decode(["success": true, "files": 1, "totalSize": 10])
        let failure = TransferFailure(
            EngineFailure(code: .other, message: "boom"), situation: .init())
        #expect(TransferTabState(phase: .idle, direction: .send) == nil)
        #expect(TransferTabState(phase: .done(summary, receivedText: nil), direction: .send) == nil)
        #expect(TransferTabState(phase: .failed(failure), direction: .receive) == nil)
    }

    @Test func theTabSpeaksItsStateInWords() {
        func spoken(_ phase: TransferController.Phase, _ direction: TransferController.Direction)
            -> String?
        {
            TransferTabState(phase: phase, direction: direction)?.spoken
        }
        #expect(spoken(.connecting, .send) == "Send, connecting")
        #expect(
            spoken(.waiting(code: "wiry-alpha-bravo"), .send)
                == "Send, waiting for the other device")
        #expect(spoken(.confirmSend, .send) == "Send, needs your answer")
        #expect(spoken(.transferring, .receive) == "Receive, transferring")
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

    @Test func aPhaseKindIgnoresThePayload() {
        #expect(
            TransferController.Phase.waiting(code: "a-b-c").kind
                == TransferController.Phase.waiting(code: "d-e-f").kind)
        #expect(TransferController.Phase.waiting(code: "a-b-c").kind != .connecting)
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
}
