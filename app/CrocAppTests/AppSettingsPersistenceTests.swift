import Foundation
import Testing

@testable import CrocApp

/// Each test gets its own defaults suite, so the host app's real settings are never touched.
/// The relay password (Keychain) is left to the migration tests over an injected store.
@Suite struct AppSettingsPersistenceTests {
    private let suiteName = "CrocAppTests.\(UUID().uuidString)"
    private let defaults: UserDefaults

    init() throws {
        defaults = try #require(UserDefaults(suiteName: suiteName))
    }

    private func cleanUp() {
        defaults.removePersistentDomain(forName: suiteName)
    }

    @Test func freshDefaultsGiveBlankSettings() {
        defer { cleanUp() }
        let s = AppSettings(defaults: defaults)
        #expect(s.relayAddress == "")
        #expect(s.relayAddress6 == "")
        #expect(!s.onlyLocal)
        #expect(!s.noCompress)
        #expect(!s.zipFolder)
        #expect(s.excludePatterns == "")
        #expect(!s.useGitIgnore)
        #expect(!s.autoAccept)
        #expect(!s.bothSidesConfirm)
        #expect(s.relayKind == .publicDefault)
    }

    @Test func changesSurviveARelaunch() {
        defer { cleanUp() }
        let s = AppSettings(defaults: defaults)
        s.relayAddress = "relay.example:9009"
        s.relayAddress6 = "[::1]:9009"
        s.onlyLocal = true
        s.noCompress = true
        s.zipFolder = true
        s.excludePatterns = "node_modules\n.git"
        s.useGitIgnore = true
        s.autoAccept = true
        s.bothSidesConfirm = true

        let r = AppSettings(defaults: defaults)
        #expect(r.relayAddress == "relay.example:9009")
        #expect(r.relayAddress6 == "[::1]:9009")
        #expect(r.onlyLocal)
        #expect(r.noCompress)
        #expect(r.zipFolder)
        #expect(r.excludeList == ["node_modules", ".git"])
        #expect(r.useGitIgnore)
        #expect(r.autoAccept)
        #expect(r.bothSidesConfirm)
    }

    /// Every bool on at once cannot catch two settings saved under each other's key.
    @Test func eachBoolPersistsAlone() {
        defer { cleanUp() }
        let bools: [(String, ReferenceWritableKeyPath<AppSettings, Bool>)] = [
            ("onlyLocal", \.onlyLocal),
            ("noCompress", \.noCompress),
            ("zipFolder", \.zipFolder),
            ("useGitIgnore", \.useGitIgnore),
            ("autoAccept", \.autoAccept),
            ("bothSidesConfirm", \.bothSidesConfirm),
        ]
        for (name, path) in bools {
            defaults.removePersistentDomain(forName: suiteName)
            AppSettings(defaults: defaults)[keyPath: path] = true
            let r = AppSettings(defaults: defaults)
            for (other, otherPath) in bools {
                #expect(r[keyPath: otherPath] == (other == name), "set \(name), read \(other)")
            }
        }
    }

    @Test func persistOffWritesNothing() {
        defer { cleanUp() }
        let s = AppSettings(defaults: defaults)
        s.persist = false
        s.relayAddress = "relay.example:9009"
        s.autoAccept = true
        s.resetToDefaults()
        s.zipFolder = true

        let r = AppSettings(defaults: defaults)
        #expect(r.relayAddress == "")
        #expect(!r.autoAccept)
        #expect(!r.zipFolder)
        #expect(defaults.persistentDomain(forName: suiteName)?.isEmpty ?? true)
    }
}
