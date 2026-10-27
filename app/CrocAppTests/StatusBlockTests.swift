import CrocKit
import Foundation
import Testing

@testable import CrocApp

/// The StatusBlock each finished transfer ends on: a croc result that is not
/// marked successful never shows as a success.
@MainActor @Suite struct StatusBlockTests {
    private func summary(success: Bool, files: Int = 2, totalSize: Int = 100) throws -> Summary {
        try JSONDecoder().decode(
            Summary.self,
            from: JSONSerialization.data(withJSONObject: [
                "success": success, "files": files, "totalSize": totalSize,
            ]))
    }

    @Test(arguments: [TransferController.Direction.send, .receive])
    func anUnsuccessfulResultIsAFailure(direction: TransferController.Direction) throws {
        let expected = TransferFailure.finishedWithProblems(direction: direction)

        let block = StatusBlock(
            summary: try summary(success: false), receivedText: nil, direction: direction)

        #expect(block.kind == .error)
        #expect(block.title == expected.title)
        #expect(block.detail == expected.detail)
    }

    @Test func anUnsuccessfulReceivedTextIsStillAFailure() throws {
        let block = StatusBlock(
            summary: try summary(success: false), receivedText: "hello", direction: .receive)

        #expect(block.kind == .error)
        #expect(block.title == TransferFailure.finishedWithProblems(direction: .receive).title)
    }

    @Test func aSuccessfulReceivedTextSaysSo() throws {
        let block = StatusBlock(
            summary: try summary(success: true), receivedText: "hello", direction: .receive)

        #expect(block.kind == .success)
        #expect(block.title == String(localized: "Received text"))
        #expect(block.detail == nil)
    }

    @Test func aSuccessfulTransferSaysItIsComplete() throws {
        let block = StatusBlock(
            summary: try summary(success: true), receivedText: nil, direction: .send)

        #expect(block.kind == .success)
        #expect(block.title == String(localized: "Transfer complete"))
        #expect(block.detail != nil)
    }
}
