import Testing

@testable import CrocApp

/// History keeps a code hint, never enough of a code to reuse it (R12d).
@Suite struct CodeHintTests {
    @Test(arguments: [
        ("wiry-buzz-grope", "wiry-…"),
        (" wiry-buzz-grope\t", "wiry-…"),
        ("7020-alpha-beta-gamma", "7020-…"),
    ])
    func generatedShapeKeepsTheFirstWord(code: String, hint: String) {
        #expect(TransferController.codeHint(code) == hint)
    }

    @Test(arguments: [
        ("averylongsecret-1", "av…"),
        ("abcdef", "ab…"),
        ("correct-horse-battery", "co…"),
        ("my-secret", "my…"),
    ])
    func customCodesKeepTwoCharacters(code: String, hint: String) {
        #expect(TransferController.codeHint(code) == hint)
    }

    @Test func emptyCodeHasNoHint() {
        #expect(TransferController.codeHint("  ") == "")
    }
}
