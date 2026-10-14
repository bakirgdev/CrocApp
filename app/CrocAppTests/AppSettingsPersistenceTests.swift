import CrocKit
import Foundation
import Testing

@testable import CrocApp

/// Each test gets its own defaults suite and an in-memory secret store, so the host app's real
/// settings and Keychain are never touched. The relay password is covered by `RelayPasswordMigrationTests`.
@Suite struct AppSettingsPersistenceTests {
    private let suiteName = "CrocAppTests.\(UUID().uuidString)"
    private let defaults: UserDefaults
    private let secrets = FakeSecretStore()

    init() throws {
        defaults = try #require(UserDefaults(suiteName: suiteName))
    }

    private func cleanUp() {
        defaults.removePersistentDomain(forName: suiteName)
    }

    @Test func freshDefaultsGiveBlankSettings() {
        defer { cleanUp() }
        let s = AppSettings(defaults: defaults, secrets: secrets)
        #expect(s.relayAddress == "")
        #expect(s.relayAddress6 == "")
        #expect(!s.onlyLocal)
        #expect(!s.noCompress)
        #expect(!s.zipFolder)
        #expect(s.excludePatterns == "")
        #expect(!s.useGitIgnore)
        #expect(!s.autoAccept)
        #expect(!s.bothSidesConfirm)
        #expect(s.whenFileExists == .keepBoth)
        #expect(s.transport == .auto)
        #expect(s.relayKind == .publicDefault)
    }

    @Test func changesSurviveARelaunch() {
        defer { cleanUp() }
        let s = AppSettings(defaults: defaults, secrets: secrets)
        s.relayAddress = "relay.example:9009"
        s.relayAddress6 = "[::1]:9009"
        s.onlyLocal = true
        s.noCompress = true
        s.zipFolder = true
        s.excludePatterns = "node_modules\n.git"
        s.useGitIgnore = true
        s.autoAccept = true
        s.bothSidesConfirm = true
        s.whenFileExists = .replace
        s.transport = .relay

        let r = AppSettings(defaults: defaults, secrets: secrets)
        #expect(r.relayAddress == "relay.example:9009")
        #expect(r.relayAddress6 == "[::1]:9009")
        #expect(r.onlyLocal)
        #expect(r.noCompress)
        #expect(r.zipFolder)
        #expect(r.excludeList == ["node_modules", ".git"])
        #expect(r.useGitIgnore)
        #expect(r.autoAccept)
        #expect(r.bothSidesConfirm)
        #expect(r.whenFileExists == .replace)
        #expect(r.transport == .relay)
    }

    /// A value this build does not know (a later build's policy, a corrupt
    /// plist) must not turn into Replace.
    @Test func unknownFilePolicyReadsAsKeepBoth() {
        defer { cleanUp() }
        defaults.set("overwrite", forKey: "settings.whenFileExists")
        #expect(AppSettings(defaults: defaults, secrets: secrets).whenFileExists == .keepBoth)
    }

    /// A value this build does not know must not turn into Relay only.
    @Test func unknownTransportReadsAsAuto() {
        defer { cleanUp() }
        defaults.set("tailcat", forKey: "settings.transport")
        #expect(AppSettings(defaults: defaults, secrets: secrets).transport == .auto)
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
            AppSettings(defaults: defaults, secrets: secrets)[keyPath: path] = true
            let r = AppSettings(defaults: defaults, secrets: secrets)
            for (other, otherPath) in bools {
                #expect(r[keyPath: otherPath] == (other == name), "set \(name), read \(other)")
            }
        }
    }

    @Test func persistOffWritesNothing() {
        defer { cleanUp() }
        let s = AppSettings(defaults: defaults, secrets: secrets)
        s.persist = false
        s.relayAddress = "relay.example:9009"
        s.autoAccept = true
        s.whenFileExists = .replace
        s.transport = .relay
        s.resetToDefaults()
        s.zipFolder = true

        let r = AppSettings(defaults: defaults, secrets: secrets)
        #expect(r.relayAddress == "")
        #expect(!r.autoAccept)
        #expect(!r.zipFolder)
        #expect(r.whenFileExists == .keepBoth)
        #expect(s.whenFileExists == .keepBoth, "reset restores Keep Both")
        #expect(r.transport == .auto)
        #expect(s.transport == .auto, "reset restores Automatic")
        #expect(defaults.persistentDomain(forName: suiteName)?.isEmpty ?? true)
    }
}
