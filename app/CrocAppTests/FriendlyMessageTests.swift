import CrocKit
import Testing

@testable import CrocApp

@Suite struct FriendlyMessageTests {
    private func message(
        _ code: EngineFailure.Code, _ text: String = "croc text", cancel: Bool = false,
        decline: Bool = false
    ) -> String {
        TransferController.friendlyMessage(
            for: EngineFailure(code: code, message: text), cancelRequested: cancel,
            declineRequested: decline)
    }

    @Test func localIntentWinsOverEngineCode() {
        #expect(message(.refused, cancel: true) == "Transfer cancelled.")
        #expect(message(.cancelled, decline: true) == "You declined the transfer.")
        #expect(message(.roomFull, cancel: true, decline: true) == "Transfer cancelled.")
    }

    @Test(arguments: [
        (
            EngineFailure.Code.peerVersion,
            "The other device runs an older croc. Both sides need croc 11 or newer."
        ),
        (.relayUnreachable, "Couldn't reach the relay. Check your internet connection."),
        (
            .noPublicRelay,
            "No public relay answered. Check your internet connection, or turn on Local network only in Settings if both devices are on the same network."
        ),
        (.declined, "The other side declined or cancelled the transfer."),
        (.refused, "You declined the transfer."),
        (.roomFull, "That code is already in use. Try a different code."),
        (.badPassword, "The relay rejected its password. Check the relay password in Settings."),
        (.wrongCode, "The codes don't match. Check the code on both devices and try again."),
        (.cancelled, "Transfer cancelled."),
        (.connectionLost, "Lost connection to the other device."),
        (.other, "Transfer failed. Try again, or check your connection."),
    ])
    func mapsEveryCode(code: EngineFailure.Code, expected: String) {
        #expect(message(code) == expected)
    }

    @Test(arguments: ["", "room full", "panic: runtime error\ngoroutine 1 [running]:"])
    func neverEchoesEngineText(text: String) {
        #expect(message(.other, text) == "Transfer failed. Try again, or check your connection.")
    }
}
