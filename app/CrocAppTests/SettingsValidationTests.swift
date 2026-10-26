import CrocKit
import Testing

@testable import CrocApp

/// The engine decides what each field accepts (`EngineSetting`, with its full
/// tables in `crocmobile/network_test.go`). These check that every form check
/// reaches it: nil for a good value, the field's own text for a bad one.
@MainActor @Suite struct SettingsValidationTests {
    struct Field: Sendable, CustomTestStringConvertible {
        let name: String
        let check: @MainActor @Sendable (String) -> String?
        let message: String
        let valid: [String]
        let invalid: [String]

        var testDescription: String { name }
    }

    nonisolated static let fields = [
        Field(
            name: "SOCKS5 proxy", check: { AppSettings.socks5ProxyError($0) },
            message: "Enter host:port, or an address starting with socks5:// or socks5h://.",
            valid: [
                "", "  ", "127.0.0.1:1080", "socks5://user:secret@proxy.example:1080",
                "socks5h://[::1]:1080", " SOCKS5://proxy.example:1080 ",
            ],
            invalid: [
                "proxy.example", "http://proxy.example:1080", "socks5://:1080",
                "proxy.example:70000", "::1:1080",
            ]),
        Field(
            name: "HTTP proxy", check: { AppSettings.httpProxyError($0) },
            message: "Enter host:port, or an address starting with http:// or https://.",
            valid: ["", "proxy.example:3128", "https://user:secret@proxy.example:443/"],
            invalid: ["socks5://proxy.example:1080", "user:secret@proxy.example", "http://:3128"]),
        Field(
            name: "multicast address", check: { AppSettings.multicastAddressError($0) },
            message: "Enter an IPv4 multicast address from 224.0.0.0 to 239.255.255.255.",
            valid: ["", "239.255.255.250", " 224.0.0.1 "],
            invalid: ["10.0.0.1", "ff02::1", "239.255.255.0250", "239.255.255.256"]),
        Field(
            name: "sender IP", check: { AppSettings.senderIPError($0) },
            message:
                "Enter the sender's address and port, such as 192.168.1.20:9009. The port must be a number from 1 to 65535.",
            valid: ["", "10.0.0.1:9009", "[::1]:9009", " 192.168.1.20:65535 "],
            invalid: ["10.0.0.1", "sender.local:9009", "10.0.0.1:0", "10.0.0.1:65536", "::1:9009"]),
        Field(
            name: "send speed limit", check: { AppSettings.throttleError($0) },
            message: "Enter a speed such as 500k, 2m or 1g, or leave it blank for no limit.",
            valid: ["", "500k", "2M", "1g", "1000", "10"],
            // "5": croc quietly ignores a one-character value.
            invalid: ["5", "k", "0k", "-5k", "1.5m", "5kb"]),
        Field(
            name: "link server", check: { AppSettings.storedServerError($0) },
            message:
                "Enter the server's address only, such as https://getcroc.com. It must use https, or http for localhost.",
            valid: [
                "https://getcroc.com", "https://getcroc.com/", "  https://example.org:8443  ",
                "http://localhost:8080", "http://127.0.0.1:9", "http://[::1]:8080",
            ],
            // Blank is refused here, unlike the Advanced fields.
            invalid: [
                "http://example.com", "http://localhost.example.com", "getcroc.com", "", "   ",
                "https://getcroc.com/s/abc", "https://getcroc.com?x=1",
                "https://user:pw@getcroc.com",
            ]),
    ]

    @Test(arguments: fields)
    func acceptsAValidValue(_ field: Field) {
        for value in field.valid {
            #expect(field.check(value) == nil, "\(field.name) refused \"\(value)\"")
        }
    }

    @Test(arguments: fields)
    func refusesAnInvalidValueWithItsMessage(_ field: Field) {
        for value in field.invalid {
            #expect(field.check(value) == field.message, "\(field.name) accepted \"\(value)\"")
        }
    }

    @Test func defaultsAreValid() {
        let defaults = AppSettings.advancedDefaults
        #expect(AppSettings.multicastAddressError(defaults.multicastAddress) == nil)
        #expect(AppSettings.throttleError(defaults.throttleUpload) == nil)
        #expect(AppSettings.senderIPError(defaults.peerIP) == nil)
        #expect(AppSettings.storedServerError(AppSettings.defaultStoredServer) == nil)
    }
}
