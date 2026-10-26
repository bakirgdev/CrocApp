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

    /// A stuck engine refuses every later start, so a Cancel tap must not hide it.
    @Test func aStuckEngineWinsOverLocalIntent() {
        #expect(
            message(.engineStuck, cancel: true, decline: true)
                == "The cancelled transfer didn't stop. Quit and reopen CrocApp to transfer again.")
        let stored = TransferController.friendlyMessage(
            for: EngineFailure(code: .engineStuck, message: "x"), cancelRequested: true,
            declineRequested: false, stored: true)
        #expect(
            stored
                == "The cancelled transfer didn't stop. Quit and reopen CrocApp to transfer again.")
    }

    @Test(arguments: [
        (
            EngineFailure.Code.peerVersion,
            "The other device runs an older croc. Both sides need croc 11 or newer."
        ),
        (.relayUnreachable, "Couldn't reach the relay. Check your internet connection."),
        (
            .noPublicRelay,
            "No public relay answered. Check your internet connection, or turn on Local Network Only in Settings if both devices are on the same network."
        ),
        (.declined, "The other device declined or cancelled the transfer."),
        (.refused, "You declined the transfer."),
        (.roomFull, "That code is already in use. Try a different code."),
        (.badPassword, "The relay rejected its password. Check the relay password in Settings."),
        (.wrongCode, "The codes don't match. Check the code on both devices and try again."),
        (.cancelled, "Transfer cancelled."),
        (.connectionLost, "Lost connection to the other device."),
        (
            .storeLimit,
            "The link server refused this send: it is over the server's size, file count or download limit, or too many sends were made recently."
        ),
        (.storeExpired, "This link has expired, was revoked, or has no downloads left."),
        (
            .invalidSetting,
            "An Advanced setting can't be used. Check the proxies, addresses, ports and send speed limit in Settings > Advanced."
        ),
        (.transferActive, "Another transfer is still running. Wait for it to end, then try again."),
        (
            .engineStuck,
            "The cancelled transfer didn't stop. Quit and reopen CrocApp to transfer again."
        ),
        (
            .joinedEarly,
            "The other device wasn't sending yet. Start the send there first, then enter the code again."
        ),
        (.other, "Transfer failed. Try again, or check your connection."),
    ])
    func mapsEveryCode(code: EngineFailure.Code, expected: String) {
        #expect(message(code) == expected)
    }

    /// A store call reports a network failure as `relayUnreachable`; no relay is involved.
    @Test(arguments: [EngineFailure.Code.relayUnreachable, .connectionLost])
    func storedNetworkFailureNamesTheServer(code: EngineFailure.Code) {
        let copy = TransferController.friendlyMessage(
            for: EngineFailure(code: code, message: "x"), cancelRequested: false,
            declineRequested: false, stored: true)
        #expect(
            copy
                == "Couldn't reach the link server. Check your internet connection and try again."
        )
    }

    @Test func storedKeepsStoreCodesAndLocalIntent() {
        let expired = TransferController.friendlyMessage(
            for: EngineFailure(code: .storeExpired, message: "x"), cancelRequested: false,
            declineRequested: false, stored: true)
        #expect(expired == "This link has expired, was revoked, or has no downloads left.")
        let cancelled = TransferController.friendlyMessage(
            for: EngineFailure(code: .relayUnreachable, message: "x"), cancelRequested: true,
            declineRequested: false, stored: true)
        #expect(cancelled == "Transfer cancelled.")
    }

    @Test(arguments: ["", "room full", "panic: runtime error\ngoroutine 1 [running]:"])
    func neverEchoesEngineText(text: String) {
        #expect(message(.other, text) == "Transfer failed. Try again, or check your connection.")
    }
}
