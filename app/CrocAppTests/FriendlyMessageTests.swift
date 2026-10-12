import Testing

@testable import CrocApp

@Suite struct FriendlyMessageTests {
    private func message(_ raw: String, cancel: Bool = false, decline: Bool = false) -> String {
        TransferController.friendlyMessage(
            for: raw, cancelRequested: cancel, declineRequested: decline)
    }

    @Test func localIntentWinsOverEngineText() {
        #expect(message("refused files", cancel: true) == "Transfer cancelled.")
        #expect(message("refused files", decline: true) == "You declined the transfer.")
        #expect(message("room full", cancel: true, decline: true) == "Transfer cancelled.")
    }

    @Test(arguments: [
        ("peer refused files", "The other side declined the transfer."),
        ("Room Full", "That code is already in use. Try a different code."),
        (
            "dial tcp: lookup 1.getcroc.com: no such host",
            "Couldn't reach the relay. Check your internet connection."
        ),
        ("connection refused", "Couldn't reach the relay. Check your internet connection."),
        ("read tcp: i/o timeout", "Couldn't reach the relay. Check your internet connection."),
        ("bad password", "Wrong code phrase, or the sender is no longer available."),
        ("write: broken pipe", "Lost connection to the other device."),
        ("connection reset by peer", "Lost connection to the other device."),
        ("unexpected EOF", "Lost connection to the other device."),
    ])
    func mapsKnownEngineErrors(raw: String, expected: String) {
        #expect(message(raw) == expected)
    }

    @Test(arguments: ["", "something new in croc", "panic: runtime error\ngoroutine 1 [running]:"])
    func neverEchoesUnknownEngineText(raw: String) {
        #expect(message(raw) == "Transfer failed. Try again, or check your connection.")
    }
}
