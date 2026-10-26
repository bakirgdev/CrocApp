import Foundation
import Testing

@testable import CrocKit

/// `EngineSetting.validate` is a thin call into `ValidateSetting`; the per-value
/// tables live in `crocmobile/network_test.go`. These pin the Swift side: every
/// case reaches a real engine check, and a refusal arrives as `invalidSetting`.
@Suite struct EngineSettingTests {
    /// One value the engine accepts for each setting.
    private static let valid: [EngineSetting: String] = [
        .socks5Proxy: "proxy.example:1080",
        .httpProxy: "http://proxy.example:3128",
        .throttleUpload: "500k",
        .multicastAddress: "239.255.255.250",
        .peerIP: "10.0.0.1:9009",
        .storeServer: "https://getcroc.com",
    ]

    /// One value the engine refuses for each setting.
    private static let invalid: [EngineSetting: String] = [
        .socks5Proxy: "proxy.example",
        .httpProxy: "ftp://proxy.example:21",
        .throttleUpload: "5",
        .multicastAddress: "10.0.0.1",
        .peerIP: "10.0.0.1",
        .storeServer: "http://example.com",
    ]

    @Test(arguments: EngineSetting.allCases)
    func engineKnowsEverySetting(_ setting: EngineSetting) throws {
        // An unknown name would fail with code `other`, even for a valid value.
        try setting.validate(try #require(Self.valid[setting]))
    }

    @Test(arguments: EngineSetting.allCases)
    func refusalIsInvalidSetting(_ setting: EngineSetting) throws {
        let value = try #require(Self.invalid[setting])
        do {
            try setting.validate(value)
            Issue.record("\(setting) accepted \(value)")
        } catch let failure as EngineFailure {
            #expect(failure.code == .invalidSetting)
        }
    }

    @Test func blankIsValidExceptForTheServer() throws {
        for setting in EngineSetting.allCases where setting != .storeServer {
            try setting.validate("")
        }
        #expect(throws: EngineFailure.self) { try EngineSetting.storeServer.validate("") }
    }

    @Test func proxyRefusalNeverQuotesTheValue() {
        let value = "socks5://user:hunter2@nohost"
        for setting in [EngineSetting.socks5Proxy, .httpProxy] {
            do {
                try setting.validate(value)
                Issue.record("\(setting) accepted a proxy without a port")
            } catch let failure as EngineFailure {
                #expect(!failure.message.contains("hunter2"))
                #expect(!failure.message.contains("nohost"))
            } catch {
                Issue.record("unexpected error \(error)")
            }
        }
    }
}
