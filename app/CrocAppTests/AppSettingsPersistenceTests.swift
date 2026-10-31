import CrocKit
import Foundation
import Testing

@testable import CrocApp

/// Each test gets its own in-memory storage and secret store, so the host
/// app's real settings, preferences files and Keychain are never touched.
@Suite struct AppSettingsPersistenceTests {
    private let storage = MemorySettingsStorage()
    private let secrets = FakeSecretStore()

    private func makeSettings() -> AppSettings {
        AppSettings(storage: storage, secrets: secrets)
    }

    @Test func freshStorageGivesDefaultSettings() {
        let s = makeSettings()
        #expect(s.relayAddress == "")
        #expect(s.relayAddress6 == "")
        #expect(s.relayPassword == "")
        #expect(!s.onlyLocal)
        #expect(!s.noCompress)
        #expect(!s.zipFolder)
        #expect(s.excludePatterns == "")
        #expect(!s.useGitIgnore)
        #expect(!s.autoAccept)
        #expect(!s.bothSidesConfirm)
        #expect(s.whenFileExists == .keepBoth)
        #expect(s.storedServer == "https://getcroc.com")
        #expect(s.showInMenuBar)
        #expect(s.showDockBadge)
        #expect(s.saveTransferHistory)
        #expect(s.haptics)
        #expect(s.relayKind == .publicDefault)
    }

    @Test func changesSurviveARelaunch() {
        let s = makeSettings()
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
        s.storedServer = "https://store.example"
        s.showInMenuBar = false
        s.showDockBadge = false
        s.saveTransferHistory = false
        s.haptics = false

        let r = makeSettings()
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
        #expect(r.storedServer == "https://store.example")
        #expect(!r.showInMenuBar)
        #expect(!r.showDockBadge)
        #expect(!r.saveTransferHistory)
        #expect(!r.haptics)
    }

    /// A value this build does not know (a later build's policy, a corrupt
    /// plist) must not turn into Replace.
    @Test func unknownFilePolicyReadsAsKeepBoth() {
        storage.set("overwrite", forKey: "settings.whenFileExists")
        #expect(makeSettings().whenFileExists == .keepBoth)
    }

    /// A key that holds another type (a corrupt plist, a later build's
    /// format) reads as the setting's default, not as its opposite.
    @Test func aValueOfTheWrongTypeReadsAsTheDefault() {
        storage.set("no", forKey: "settings.haptics")
        storage.set(true, forKey: "settings.relayAddress")
        let s = makeSettings()
        #expect(s.haptics)
        #expect(s.relayAddress == "")
    }

    /// Every bool on at once cannot catch two settings saved under each other's key.
    @Test func eachBoolPersistsAlone() {
        let bools: [(String, ReferenceWritableKeyPath<AppSettings, Bool>)] = [
            ("onlyLocal", \.onlyLocal),
            ("noCompress", \.noCompress),
            ("zipFolder", \.zipFolder),
            ("useGitIgnore", \.useGitIgnore),
            ("autoAccept", \.autoAccept),
            ("bothSidesConfirm", \.bothSidesConfirm),
        ]
        for (name, path) in bools {
            let storage = MemorySettingsStorage()
            AppSettings(storage: storage, secrets: secrets)[keyPath: path] = true
            let r = AppSettings(storage: storage, secrets: secrets)
            for (other, otherPath) in bools {
                #expect(r[keyPath: otherPath] == (other == name), "set \(name), read \(other)")
            }
        }
    }

    /// The same for the settings that default to on: turning one off must not
    /// turn off another.
    @Test func eachDefaultOnBoolPersistsAlone() {
        let bools: [(String, ReferenceWritableKeyPath<AppSettings, Bool>)] = [
            ("showInMenuBar", \.showInMenuBar),
            ("showDockBadge", \.showDockBadge),
            ("saveTransferHistory", \.saveTransferHistory),
            ("haptics", \.haptics),
        ]
        for (name, path) in bools {
            let storage = MemorySettingsStorage()
            AppSettings(storage: storage, secrets: secrets)[keyPath: path] = false
            let r = AppSettings(storage: storage, secrets: secrets)
            for (other, otherPath) in bools {
                #expect(r[keyPath: otherPath] == (other != name), "set \(name), read \(other)")
            }
        }
    }

    /// Per-key storage is what keeps a new setting from resetting the old
    /// ones, so the key names are part of the contract with saved preferences.
    @Test func eachSettingIsStoredUnderItsOwnKey() {
        let s = makeSettings()
        s.saveTransferHistory = false
        s.haptics = false
        s.onlyLocal = true

        #expect(storage.values["settings.saveTransferHistory"] as? Bool == false)
        #expect(storage.values["settings.haptics"] as? Bool == false)
        #expect(storage.values["settings.onlyLocal"] as? Bool == true)
        #expect(storage.values.count == 3, "a write touches only its own key")
    }

    @Test func settingsSavedBeforeANewSettingExistedStillLoad() {
        storage.set("relay.example:9009", forKey: "settings.relayAddress")
        storage.set(true, forKey: "settings.autoAccept")

        let s = makeSettings()
        #expect(s.relayAddress == "relay.example:9009")
        #expect(s.autoAccept)
        #expect(s.saveTransferHistory, "a key that was never written reads its default")
        #expect(s.haptics)
    }

    @Test func theRelayPasswordLivesOnlyInTheSecretStore() {
        let s = makeSettings()
        s.relayPassword = "hunter2"

        #expect(secrets.items["relayPassword"] == "hunter2")
        #expect(!String(describing: storage.values).contains("hunter2"))
        #expect(makeSettings().relayPassword == "hunter2")
    }

    @Test func clearingThePasswordDeletesTheItem() {
        secrets.items["relayPassword"] = "stored"
        let s = makeSettings()
        #expect(s.relayPassword == "stored")

        s.relayPassword = ""

        #expect(secrets.items.isEmpty)
    }

    @Test func aFailedPasswordWriteIsShownUntilAWriteSucceeds() {
        let s = makeSettings()
        secrets.failWrites = true

        s.relayPassword = "hunter2"

        #expect(s.unsavedSecrets == [.relayPassword])
        #expect(secrets.items["relayPassword"] == nil)
        #expect(s.relayPassword == "hunter2", "the edit still applies for this launch")

        secrets.failWrites = false
        s.relayPassword = "hunter3"

        #expect(s.unsavedSecrets.isEmpty)
        #expect(secrets.items["relayPassword"] == "hunter3")
    }

    @Test func aFailedDeleteIsShownToo() {
        secrets.items["relayPassword"] = "stored"
        let s = makeSettings()
        secrets.failWrites = true

        s.relayPassword = ""

        #expect(s.unsavedSecrets == [.relayPassword])
        #expect(makeSettings().relayPassword == "stored", "the next launch reads the old value")

        secrets.failWrites = false
        s.relayPassword = ""

        #expect(s.unsavedSecrets.isEmpty)
        #expect(secrets.items.isEmpty)
    }
}

@Suite struct MemorySettingsStorageTests {
    @Test func startsEmptyAndReturnsWhatWasSet() {
        let storage = MemorySettingsStorage()
        #expect(storage.object(forKey: "settings.haptics") == nil)
        storage.set(false, forKey: "settings.haptics")
        #expect(storage.object(forKey: "settings.haptics") as? Bool == false)
    }

    @Test func settingNilRemovesTheKey() {
        let storage = MemorySettingsStorage()
        storage.set("a", forKey: "key")
        storage.set(nil, forKey: "key")
        #expect(storage.object(forKey: "key") == nil)
        #expect(storage.values.isEmpty)
    }

    @Test func twoStoragesShareNothing() {
        let first = MemorySettingsStorage()
        let second = MemorySettingsStorage()
        first.set(true, forKey: "key")
        #expect(second.object(forKey: "key") == nil)
    }
}
