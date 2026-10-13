import Foundation
import Testing

@testable import CrocApp

/// In-memory `SecretStore`; `failWrites` makes every `set` fail like a Keychain error would.
final class FakeSecretStore: SecretStore {
    var items: [String: String] = [:]
    var failWrites = false

    func get(account: String) -> String? { items[account] }

    func set(_ value: String, account: String) -> Bool {
        guard !failWrites else { return false }
        items[account] = value
        return true
    }

    func delete(account: String) -> Bool {
        items[account] = nil
        return true
    }
}

/// Builds before the Keychain move kept the relay password in UserDefaults
/// under `settings.relayPassword`; `AppSettings.init` migrates it.
@Suite struct RelayPasswordMigrationTests {
    private static let legacyKey = "settings.relayPassword"
    private static let account = "relayPassword"

    private let suiteName = "CrocAppTests.\(UUID().uuidString)"
    private let defaults: UserDefaults

    init() throws {
        defaults = try #require(UserDefaults(suiteName: suiteName))
    }

    private func cleanUp() {
        defaults.removePersistentDomain(forName: suiteName)
    }

    @Test func migratesAndRemovesTheLegacyValue() {
        defer { cleanUp() }
        let store = FakeSecretStore()
        defaults.set("hunter2", forKey: Self.legacyKey)

        let s = AppSettings(defaults: defaults, secrets: store)

        #expect(s.relayPassword == "hunter2")
        #expect(store.items[Self.account] == "hunter2")
        #expect(defaults.string(forKey: Self.legacyKey) == nil)
    }

    @Test func failedWriteKeepsTheLegacyValue() {
        defer { cleanUp() }
        let store = FakeSecretStore()
        store.failWrites = true
        defaults.set("hunter2", forKey: Self.legacyKey)

        let s = AppSettings(defaults: defaults, secrets: store)

        #expect(defaults.string(forKey: Self.legacyKey) == "hunter2")
        #expect(store.items[Self.account] == nil)
        #expect(s.relayPassword == "hunter2", "this launch still uses the password")
    }

    @Test func failedWriteIsRetriedOnTheNextLaunch() {
        defer { cleanUp() }
        let store = FakeSecretStore()
        store.failWrites = true
        defaults.set("hunter2", forKey: Self.legacyKey)
        _ = AppSettings(defaults: defaults, secrets: store)

        store.failWrites = false
        let r = AppSettings(defaults: defaults, secrets: store)

        #expect(r.relayPassword == "hunter2")
        #expect(store.items[Self.account] == "hunter2")
        #expect(defaults.string(forKey: Self.legacyKey) == nil)
    }

    /// A legacy value left behind by a failed migration must not overwrite a
    /// password the user saved later.
    @Test func laterEditRetiresTheLegacyValue() {
        defer { cleanUp() }
        let store = FakeSecretStore()
        store.failWrites = true
        defaults.set("old", forKey: Self.legacyKey)
        let s = AppSettings(defaults: defaults, secrets: store)

        store.failWrites = false
        s.relayPassword = "new"

        #expect(defaults.string(forKey: Self.legacyKey) == nil)
        let r = AppSettings(defaults: defaults, secrets: store)
        #expect(r.relayPassword == "new")
    }

    @Test func noLegacyValueReadsTheStore() {
        defer { cleanUp() }
        let store = FakeSecretStore()
        store.items[Self.account] = "stored"

        let s = AppSettings(defaults: defaults, secrets: store)

        #expect(s.relayPassword == "stored")
    }

    @Test func clearingThePasswordDeletesTheItem() {
        defer { cleanUp() }
        let store = FakeSecretStore()
        store.items[Self.account] = "stored"
        let s = AppSettings(defaults: defaults, secrets: store)

        s.relayPassword = ""

        #expect(store.items.isEmpty)
    }

    @Test func persistOffWritesNoSecret() {
        defer { cleanUp() }
        let store = FakeSecretStore()
        store.items[Self.account] = "stored"
        let s = AppSettings(defaults: defaults, secrets: store)
        s.persist = false

        s.relayPassword = "harness"
        s.resetToDefaults()

        #expect(store.items == [Self.account: "stored"])
    }
}
