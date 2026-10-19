import Foundation
import Testing

@testable import CrocApp

/// History keeps a code hint, never enough of a code to reuse it.
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

    /// A stored link's id is in its path and its key in the fragment.
    @Test(arguments: [
        ("https://getcroc.com/s/AbCdEf0123456789#v1.c2VjcmV0LWtleS1tYXRlcmlhbA", "getcroc.com"),
        ("http://localhost:8080/s/AbCdEf0123456789#v1.c2VjcmV0", "localhost"),
        ("https://getcroc.com", "getcroc.com"),
    ])
    func storedLinkKeepsOnlyTheHost(link: String, hint: String) throws {
        let url = try #require(URL(string: link))
        let h = TransferController.codeHint(storedLink: url)
        #expect(h == hint)
        #expect(!h.contains("AbCdEf"))
        #expect(!h.contains("c2Vj"))
    }
}
