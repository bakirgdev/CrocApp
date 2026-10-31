import CrocKit
import Testing

@testable import CrocApp

/// The relay this Mac runs: its settings are off by default, and its password
/// lives only in the Keychain.
@MainActor @Suite struct RelayHostSettingsTests {
    private let storage = MemorySettingsStorage()
    private let secrets = FakeSecretStore()

    private func makeSettings() -> AppSettings {
        AppSettings(storage: storage, secrets: secrets)
    }

    @Test func defaultsAreCrocsPortWithNoPasswordAndNoAutoStart() {
        let s = makeSettings()
        #expect(s.relayHostPort == 9009)
        #expect(s.relayHostPassword == "")
        #expect(!s.relayHostAtLaunch)
    }

    @Test func changesSurviveARelaunch() {
        let s = makeSettings()
        s.relayHostPort = 9100
        s.relayHostAtLaunch = true
        s.relayHostPassword = "hosted-secret"
        let r = makeSettings()
        #expect(r.relayHostPort == 9100)
        #expect(r.relayHostAtLaunch)
        #expect(r.relayHostPassword == "hosted-secret")
    }

    /// The password goes to the Keychain alone, apart from the one used to join a relay.
    @Test func thePasswordNeverReachesPlainStorage() {
        let s = makeSettings()
        s.relayHostPassword = "hosted-secret"
        #expect(secrets.items["relayHostPassword"] == "hosted-secret")
        #expect(secrets.items["relayPassword"] == nil)
        #expect(storage.object(forKey: "settings.relayHostPassword") == nil)
        s.relayHostPassword = ""
        #expect(secrets.items["relayHostPassword"] == nil)
    }

    @Test func aFailedKeychainWriteIsReported() {
        let s = makeSettings()
        secrets.failWrites = true
        s.relayHostPassword = "hosted-secret"
        #expect(s.unsavedSecrets.contains(.relayHostPassword))
    }

    @Test func portErrorFollowsTheEnginesRange() {
        let range = RelayHost.basePortRange
        #expect(AppSettings.relayHostPortError(9009) == nil)
        #expect(AppSettings.relayHostPortError(range.lowerBound) == nil)
        #expect(AppSettings.relayHostPortError(range.upperBound) == nil)
        #expect(AppSettings.relayHostPortError(0) != nil)
        #expect(AppSettings.relayHostPortError(range.upperBound + 1) != nil)
    }
}
