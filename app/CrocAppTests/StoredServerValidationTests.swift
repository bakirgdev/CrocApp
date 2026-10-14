import Testing

@testable import CrocApp

@Suite struct StoredServerValidationTests {
    @Test(arguments: [
        "https://getcroc.com", "https://getcroc.com/", "  https://example.org:8443  ",
        "http://localhost:8080", "http://127.0.0.1:9", "http://[::1]:8080",
    ])
    func acceptsAnOrigin(_ text: String) {
        #expect(AppSettings.storedServerError(text) == nil)
    }

    @Test(arguments: [
        "http://example.com", "http://localhost.example.com", "ftp://getcroc.com", "getcroc.com",
        "", "   ", "https://", "https://getcroc.com/s/abc", "https://getcroc.com?x=1",
        "https://getcroc.com#frag", "https://user:pw@getcroc.com",
    ])
    func rejectsAnythingElse(_ text: String) {
        #expect(AppSettings.storedServerError(text) != nil)
    }

    @Test func plainHttpErrorNamesTheRule() {
        #expect(AppSettings.storedServerError("http://example.com")?.contains("https") == true)
    }

    @Test func defaultServerIsValid() {
        #expect(AppSettings.storedServerError(AppSettings.defaultStoredServer) == nil)
    }
}
