import Foundation
import Testing

@testable import CrocApp

/// R22: every accepted form parses to the same code; anything else is nil.
@Suite struct TransferLinkTests {
    private let code = "7020-alpha-beta-gamma"

    @Test(arguments: [
        "7020-alpha-beta-gamma",
        "  7020-alpha-beta-gamma\n",
        "croc://7020-alpha-beta-gamma",
        "crocapp://receive?code=7020-alpha-beta-gamma",
        "CrocApp://Receive?code=7020-alpha-beta-gamma",
        "https://crocapp.dev/r/#7020-alpha-beta-gamma",
        "https://crocapp.dev/r#7020-alpha-beta-gamma",
        "https://CrocApp.dev/r/#7020-alpha-beta-gamma",
        "https://getcroc.com/?code=7020-alpha-beta-gamma",
        "https://getcroc.com?code=7020-alpha-beta-gamma",
    ])
    func everyCodeFormParsesToTheCode(raw: String) {
        #expect(TransferLink.parse(raw) == .code("7020-alpha-beta-gamma"))
    }

    @Test func percentEncodedCodesAreDecoded() {
        #expect(
            TransferLink.parse("crocapp://receive?code=a%26b-c%20d") == nil,
            "a decoded space is not a code")
        #expect(
            TransferLink.parse("crocapp://receive?code=ab%26cd-ef") == .code("ab&cd-ef"))
        #expect(TransferLink.parse("https://crocapp.dev/r/#ab%26cd-ef") == .code("ab&cd-ef"))
    }

    @Test(arguments: [
        "",
        "   ",
        "short",
        "two words here",
        "croc://short",
        "croc://",
        "crocapp://receive",
        "crocapp://receive?code=short",
        "crocapp://send?code=7020-alpha-beta-gamma",
        "https://crocapp.dev/r/",
        "https://crocapp.dev/r/#short",
        "https://crocapp.dev/other/#7020-alpha-beta-gamma",
        "http://crocapp.dev/r/#7020-alpha-beta-gamma",
        "https://evil.example/r/#7020-alpha-beta-gamma",
        "https://crocapp.dev.evil.example/r/#7020-alpha-beta-gamma",
        "https://user@crocapp.dev/r/#7020-alpha-beta-gamma",
        "https://getcroc.com/?code=short",
        "https://getcroc.com/other?code=7020-alpha-beta-gamma",
        "http://getcroc.com/?code=7020-alpha-beta-gamma",
        "ftp://crocapp.dev/r/#7020-alpha-beta-gamma",
        "mailto://x",
    ])
    func everythingElseIsRejected(raw: String) {
        #expect(TransferLink.parse(raw) == nil)
    }

    @Test(arguments: [
        "https://getcroc.com/s/AAAAAAAAAAAAAAAAAAAAAA#v1.AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA",
        "https://example.org:8443/s/AAAAAAAAAAAAAAAAAAAAAA/#v1.AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA",
        "http://localhost:8080/s/AAAAAAAAAAAAAAAAAAAAAA#v1.AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA",
        "http://127.0.0.1:8080/s/AAAAAAAAAAAAAAAAAAAAAA#v1.AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA",
        "http://[::1]:8080/s/AAAAAAAAAAAAAAAAAAAAAA#v1.AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA",
    ])
    func storedLinksKeepTheirURL(raw: String) {
        #expect(TransferLink.parse(raw) == .stored(URL(string: raw)!))
    }

    @Test(arguments: [
        "http://getcroc.com/s/AAAAAAAAAAAAAAAAAAAAAA#v1.AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA",
        "http://example.org/s/AAAAAAAAAAAAAAAAAAAAAA#v1.AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA",
        "http://localhost.evil.example/s/AAAAAAAAAAAAAAAAAAAAAA#v1.AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA",
        "https://getcroc.com/s/AAAAAAAAAAAAAAAAAAAAAA",
        "https://getcroc.com/s/AAAAAAAAAAAAAAAAAAAAAA#",
        "https://getcroc.com/s/AAAAAAAAAAAAAAAAAAAAAA#v1.",
        "https://getcroc.com/s/AAAAAAAAAAAAAAAAAAAAAA#v2.AAAA",
        "https://getcroc.com/s/AAAAAAAAAAAAAAAAAAAAAA?x=1#v1.AAAA",
        "https://getcroc.com/s/#v1.AAAA",
        "https://getcroc.com/s#v1.AAAA",
        "https://getcroc.com/s/a/b#v1.AAAA",
        "https://getcroc.com/t/AAAAAAAAAAAAAAAAAAAAAA#v1.AAAA",
        "https://user:pw@getcroc.com/s/AAAAAAAAAAAAAAAAAAAAAA#v1.AAAA",
    ])
    func malformedOrInsecureStoredLinksAreRejected(raw: String) {
        #expect(TransferLink.parse(raw) == nil)
    }

    @Test func webURLRoundTripsThroughTheParser() {
        for code in [code, "ab&cd-ef", "a#b?c-d/e", "ünï-cödé-phrase"] {
            let url = TransferLink.webURL(forCode: code)
            #expect(url?.absoluteString.hasPrefix("https://crocapp.dev/r/#") == true)
            #expect(url.flatMap { TransferLink.parse($0.absoluteString) } == .code(code))
        }
    }

    @Test func webURLKeepsTheCodeInTheFragmentOnly() throws {
        let url = try #require(TransferLink.webURL(forCode: code))
        #expect(url.absoluteString == "https://crocapp.dev/r/#7020-alpha-beta-gamma")
        #expect(url.query == nil)
    }
}
