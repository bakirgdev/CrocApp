import CrocKit
import Foundation
import Testing

@testable import CrocApp

/// Advanced settings (R25): persistence, the proxies' Keychain-only storage and reset.
@Suite struct AppSettingsAdvancedTests {
    private let suiteName = "CrocAppTests.\(UUID().uuidString)"
    private let defaults: UserDefaults
    private let secrets = FakeSecretStore()

    init() throws {
        defaults = try #require(UserDefaults(suiteName: suiteName))
    }

    private func cleanUp() {
        defaults.removePersistentDomain(forName: suiteName)
    }

    private func makeSettings() -> AppSettings {
        AppSettings(defaults: defaults, secrets: secrets)
    }

    private func setNonDefaults(_ s: AppSettings) {
        s.curve = .ed25519
        s.hashAlgorithm = .md5
        s.throttleUpload = "500k"
        s.noMultiplexing = true
        s.basePort = 9100
        s.transfers = 2
        s.multicastAddress = "224.0.0.251"
        s.peerIP = "10.0.0.1:9100"
        s.internalDNS = true
        s.socks5Proxy = "socks5://user:secret@proxy.example:1080"
        s.httpProxy = "http://user:secret@proxy.example:3128"
    }

    @Test func freshDefaultsAreCrocs() {
        defer { cleanUp() }
        let s = makeSettings()
        #expect(s.curve == .p256)
        #expect(s.hashAlgorithm == .xxhash)
        #expect(s.throttleUpload == "")
        #expect(!s.noMultiplexing)
        #expect(s.basePort == 9009)
        #expect(s.transfers == 4)
        #expect(s.multicastAddress == "239.255.255.250")
        #expect(s.peerIP == "")
        #expect(!s.internalDNS)
        #expect(s.socks5Proxy == "")
        #expect(s.httpProxy == "")
        #expect(s.advancedIsDefault)
    }

    @Test func changesSurviveARelaunch() {
        defer { cleanUp() }
        setNonDefaults(makeSettings())

        let r = makeSettings()
        #expect(r.curve == .ed25519)
        #expect(r.hashAlgorithm == .md5)
        #expect(r.throttleUpload == "500k")
        #expect(r.noMultiplexing)
        #expect(r.basePort == 9100)
        #expect(r.transfers == 2)
        #expect(r.multicastAddress == "224.0.0.251")
        #expect(r.peerIP == "10.0.0.1:9100")
        #expect(r.internalDNS)
        #expect(r.socks5Proxy == "socks5://user:secret@proxy.example:1080")
        #expect(r.httpProxy == "http://user:secret@proxy.example:3128")
        #expect(!r.advancedIsDefault)
    }

    /// Two settings saved under each other's key would still pass the test above.
    @Test func eachSettingPersistsAlone() {
        defer { cleanUp() }
        let edits: [(String, (AppSettings) -> Void)] = [
            ("curve", { $0.curve = .p521 }),
            ("hash", { $0.hashAlgorithm = .imohash }),
            ("throttle", { $0.throttleUpload = "2m" }),
            ("multiplexing", { $0.noMultiplexing = true }),
            ("basePort", { $0.basePort = 9100 }),
            ("transfers", { $0.transfers = 2 }),
            ("multicast", { $0.multicastAddress = "224.0.0.251" }),
            ("peerIP", { $0.peerIP = "10.0.0.1:9009" }),
            ("dns", { $0.internalDNS = true }),
            ("socks5", { $0.socks5Proxy = "proxy.example:1080" }),
            ("http", { $0.httpProxy = "proxy.example:3128" }),
        ]
        for (name, edit) in edits {
            defaults.removePersistentDomain(forName: suiteName)
            secrets.items.removeAll()
            edit(makeSettings())
            let r = makeSettings()
            let changed = [
                "curve": r.curve != .p256, "hash": r.hashAlgorithm != .xxhash,
                "throttle": r.throttleUpload != "", "multiplexing": r.noMultiplexing,
                "basePort": r.basePort != 9009, "transfers": r.transfers != 4,
                "multicast": r.multicastAddress != "239.255.255.250", "peerIP": r.peerIP != "",
                "dns": r.internalDNS, "socks5": r.socks5Proxy != "", "http": r.httpProxy != "",
            ]
            for (other, isChanged) in changed {
                #expect(isChanged == (other == name), "set \(name), read \(other)")
            }
        }
    }

    @Test func unknownCurveAndHashReadAsDefaults() {
        defer { cleanUp() }
        defaults.set("curve25519", forKey: "settings.advanced.curve")
        defaults.set("sha1", forKey: "settings.advanced.hashAlgorithm")
        let s = makeSettings()
        #expect(s.curve == .p256)
        #expect(s.hashAlgorithm == .xxhash)
    }

    /// A proxy URL can hold a password: it belongs in the Keychain, never in the plist.
    @Test func proxiesLiveOnlyInTheSecretStore() {
        defer { cleanUp() }
        setNonDefaults(makeSettings())

        #expect(secrets.items["advanced.socks5Proxy"] == "socks5://user:secret@proxy.example:1080")
        #expect(secrets.items["advanced.httpProxy"] == "http://user:secret@proxy.example:3128")
        let stored = defaults.persistentDomain(forName: suiteName) ?? [:]
        #expect(!stored.keys.contains { $0.lowercased().contains("proxy") })
        #expect(!String(describing: stored).contains("secret"))
        #expect(!String(describing: stored).contains("proxy.example"))
    }

    @Test func blankProxyDeletesTheKeychainItem() {
        defer { cleanUp() }
        let s = makeSettings()
        s.socks5Proxy = "proxy.example:1080"
        s.httpProxy = "proxy.example:3128"
        #expect(secrets.items.count == 2)

        s.socks5Proxy = ""
        s.httpProxy = "   "
        #expect(secrets.items.isEmpty)
        #expect(makeSettings().socks5Proxy == "")
    }

    @Test func persistOffWritesNoProxy() {
        defer { cleanUp() }
        let s = makeSettings()
        s.persist = false
        s.socks5Proxy = "proxy.example:1080"
        s.basePort = 9100
        s.resetToDefaults()
        s.httpProxy = "proxy.example:3128"
        #expect(secrets.items.isEmpty)
        #expect(defaults.persistentDomain(forName: suiteName)?.isEmpty ?? true)
    }

    /// A harness run's reset must not blank proxies a real user saved.
    @Test func harnessResetKeepsSavedProxies() {
        defer { cleanUp() }
        secrets.items["advanced.socks5Proxy"] = "proxy.example:1080"
        let s = makeSettings()
        s.persist = false
        s.resetToDefaults()
        #expect(s.socks5Proxy == "")
        #expect(secrets.items["advanced.socks5Proxy"] == "proxy.example:1080")
    }

    @Test func resetAdvancedRestoresEveryDefaultAndPersists() {
        defer { cleanUp() }
        let s = makeSettings()
        setNonDefaults(s)
        s.relayAddress = "relay.example:9009"

        s.resetAdvancedToDefaults()

        #expect(s.advancedIsDefault)
        let r = makeSettings()
        #expect(r.advancedIsDefault)
        #expect(r.curve == .p256)
        #expect(r.basePort == 9009)
        #expect(r.socks5Proxy == "")
        #expect(secrets.items.isEmpty, "reset deletes the saved proxies")
        #expect(r.relayAddress == "relay.example:9009", "reset leaves the other settings alone")
    }

    @Test func receiveRelayKindFollowsTheSenderIP() {
        defer { cleanUp() }
        let s = makeSettings()
        #expect(s.receiveRelayKind == .publicDefault)
        s.peerIP = "10.0.0.1:9009"
        #expect(s.receiveRelayKind == .directToSender)
        #expect(s.relayKind == .publicDefault, "a send is not affected by the sender IP")
        s.peerIP = "  "
        #expect(s.receiveRelayKind == .publicDefault)
        s.onlyLocal = true
        #expect(s.receiveRelayKind == .localOnly)
    }
}
