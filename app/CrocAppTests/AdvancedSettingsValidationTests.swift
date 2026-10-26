import CrocKit
import Testing

@testable import CrocApp

/// The accept and reject tables mirror `crocmobile/network_test.go`
/// (`TestValidateNetworkOptions`, `TestRelayPorts`), so the form and the engine
/// agree on what a value means.
@Suite struct AdvancedSettingsValidationTests {
    @Test(arguments: [
        "", "   ", "127.0.0.1:1080", "proxy.example:1080",
        "socks5://user:secret@proxy.example:1080",
        "socks5h://proxy.example:1080", "SOCKS5://proxy.example:1080",
        " socks5://proxy.example:1080 ",
        "socks5://[::1]:1080",
    ])
    func socks5Accepts(_ text: String) {
        #expect(AppSettings.socks5ProxyError(text) == nil)
    }

    @Test(arguments: [
        "proxy.example", "http://user:secret@proxy.example:1080", "socks5://:1080",
        "user:secret@proxy.example", "socks5://proxy.example", "proxy.example:port",
        "proxy.example:0", "proxy.example:70000", "socks5://proxy.example:1080 extra",
    ])
    func socks5Rejects(_ text: String) {
        #expect(AppSettings.socks5ProxyError(text) != nil)
    }

    @Test(arguments: [
        "", "proxy.example:3128", "http://user:secret@proxy.example:3128",
        " https://proxy.example:443 ",
        "https://proxy.example:443/", "http://[::1]:3128",
    ])
    func httpAccepts(_ text: String) {
        #expect(AppSettings.httpProxyError(text) == nil)
    }

    @Test(arguments: [
        "socks5://user:secret@proxy.example:1080", "user:secret@proxy.example", "proxy.example",
        "ftp://proxy.example:21", "http://:3128",
    ])
    func httpRejects(_ text: String) {
        #expect(AppSettings.httpProxyError(text) != nil)
    }

    /// A proxy URL can carry a password, so the message must not repeat it.
    @Test func proxyErrorsNeverQuoteTheValue() {
        let value = "socks5://user:hunter2@nohost"
        let messages = [
            AppSettings.socks5ProxyError(value), AppSettings.httpProxyError(value),
        ]
        for message in messages {
            #expect(message != nil)
            #expect(message?.contains("hunter2") == false)
            #expect(message?.contains("nohost") == false)
        }
    }

    @Test(arguments: ["", "239.255.255.250", "224.0.0.251", "239.255.255.255", " 224.0.0.1 "])
    func multicastAccepts(_ text: String) {
        #expect(AppSettings.multicastAddressError(text) == nil)
    }

    @Test(arguments: [
        "10.0.0.1", "ff02::1", "not an address", "223.255.255.255", "240.0.0.0", "239.255.255",
        "239.255.255.256", "239.255.255.250.1", "239.255.255.0250",
    ])
    func multicastRejects(_ text: String) {
        #expect(AppSettings.multicastAddressError(text) != nil)
    }

    @Test(arguments: ["", "10.0.0.1:9009", "[::1]:9009", " 192.168.1.20:65535 ", "[fe80::1]:1"])
    func senderIPAccepts(_ text: String) {
        #expect(AppSettings.senderIPError(text) == nil)
    }

    @Test(arguments: [
        "10.0.0.1", "sender.local:9009", "10.0.0.1:0", "10.0.0.1:http", "10.0.0.1:65536",
        "::1:9009", "[::1]", "[::1]9009", "[not-ip]:9009", "[fe80::1%en0]:9009", ":9009",
    ])
    func senderIPRejects(_ text: String) {
        #expect(AppSettings.senderIPError(text) != nil)
    }

    @Test(arguments: ["", "  ", "500k", "500K", "2m", "2M", "1g", "1G", "1000", "10", "99k"])
    func throttleAccepts(_ text: String) {
        #expect(AppSettings.throttleError(text) == nil)
    }

    @Test(arguments: [
        "k", "xk", "5", "0k", "0", "00", "-5k", "+5k", "1.5m", "5kb", "5 k", "fast",
        "99999999999999999999k", "٣k",
    ])
    func throttleRejects(_ text: String) {
        #expect(AppSettings.throttleError(text) != nil)
    }

    @Test func defaultsAreValid() {
        let defaults = AppSettings.advancedDefaults
        #expect(AppSettings.multicastAddressError(defaults.multicastAddress) == nil)
        #expect(AppSettings.throttleError(defaults.throttleUpload) == nil)
        #expect(AppSettings.senderIPError(defaults.peerIP) == nil)
    }
}
