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

    /// Saved preferences are read back under these exact strings: a rename
    /// silently resets that setting for every existing install.
    @Test func everyStoredKeyStringIsPinned() {
        #expect(
            Set(AppSettings.Key.allCases.map(\.rawValue)) == [
                "settings.advanced.disableLocal",
                "settings.advanced.peerIP",
                "settings.advanced.throttleUpload",
                "settings.autoAccept",
                "settings.bothSidesConfirm",
                "settings.excludePatterns",
                "settings.haptics",
                "settings.lastReviewPromptVersion",
                "settings.noCompress",
                "settings.notificationsEnabled",
                "settings.notificationsShowFileNames",
                "settings.onlyLocal",
                "settings.relayAddress",
                "settings.relayAddress6",
                "settings.saveTransferHistory",
                "settings.showDockBadge",
                "settings.showInMenuBar",
                "settings.storedServer",
                "settings.successfulTransfers",
                "settings.systemSurfacesShowFileNames",
                "settings.useGitIgnore",
                "settings.whenFileExists",
                "settings.zipFolder",
            ])
    }

    @Test func launchRemovesWhatTheRemovedSpotlightSettingLeftBehind() {
        storage.set(true, forKey: "settings.indexHistoryInSpotlight")
        storage.set(true, forKey: "spotlightIndexPurged")

        _ = makeSettings()

        #expect(storage.values["settings.indexHistoryInSpotlight"] == nil)
        #expect(storage.values["spotlightIndexPurged"] == nil)
    }

    @Test func launchRemovesWhatTheRemovedAdvancedOptionsLeftBehind() {
        let removed = ["multicastAddress", "internalDNS", "noMultiplexing", "excludePaths"]
        for key in removed { storage.set("x", forKey: "settings.advanced.\(key)") }
        storage.set("500k", forKey: "settings.advanced.throttleUpload")

        _ = makeSettings()

        for key in removed { #expect(storage.values["settings.advanced.\(key)"] == nil, "\(key)") }
        #expect(storage.values["settings.advanced.throttleUpload"] as? String == "500k")
    }

    @Test func launchMovesTheRemovedExactPathsIntoTheExcludePatternsOnce() {
        storage.set("node_modules\n", forKey: "settings.excludePatterns")
        storage.set(
            " config/credentials.json \n\nnode_modules\nsrc/secret.txt",
            forKey: "settings.advanced.excludePaths")

        let s = makeSettings()

        #expect(s.excludeList == ["node_modules", "config/credentials.json", "src/secret.txt"])
        #expect(storage.values["settings.advanced.excludePaths"] == nil)

        let again = makeSettings()

        #expect(again.excludeList == s.excludeList)
        #expect(again.excludePatterns == s.excludePatterns)
    }

    @Test func launchWithoutTheRemovedExactPathsLeavesTheExcludePatternsAlone() {
        storage.set("node_modules\n\n", forKey: "settings.excludePatterns")

        _ = makeSettings()

        #expect(storage.values["settings.excludePatterns"] as? String == "node_modules\n\n")
    }

    @Test func launchRemovesWhatTheRemovedRelayHostLeftBehind() {
        storage.set(9010, forKey: "settings.relayHostPort")
        storage.set(true, forKey: "settings.relayHostAtLaunch")
        secrets.items["relayHostPassword"] = "old"
        secrets.items["relayPassword"] = "kept"

        _ = makeSettings()

        #expect(storage.values["settings.relayHostPort"] == nil)
        #expect(storage.values["settings.relayHostAtLaunch"] == nil)
        #expect(secrets.items == ["relayPassword": "kept"])
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
        s.flushSecrets()

        #expect(secrets.items["relayPassword"] == "hunter2")
        #expect(!String(describing: storage.values).contains("hunter2"))
        #expect(makeSettings().relayPassword == "hunter2")
    }

    @Test func clearingThePasswordDeletesTheItem() {
        secrets.items["relayPassword"] = "stored"
        let s = makeSettings()
        #expect(s.relayPassword == "stored")

        s.relayPassword = ""
        s.flushSecrets()

        #expect(secrets.items.isEmpty)
    }

    @Test func aFailedPasswordWriteIsShownUntilAWriteSucceeds() {
        let s = makeSettings()
        secrets.failWrites = true

        s.relayPassword = "hunter2"
        s.flushSecrets()

        #expect(s.unsavedSecrets == [.relayPassword])
        #expect(secrets.items["relayPassword"] == nil)
        #expect(s.relayPassword == "hunter2", "the edit still applies for this launch")

        secrets.failWrites = false
        s.relayPassword = "hunter3"
        s.flushSecrets()

        #expect(s.unsavedSecrets.isEmpty)
        #expect(secrets.items["relayPassword"] == "hunter3")
    }

    @Test func aFailedDeleteIsShownToo() {
        secrets.items["relayPassword"] = "stored"
        let s = makeSettings()
        secrets.failWrites = true

        s.relayPassword = ""
        s.flushSecrets()

        #expect(s.unsavedSecrets == [.relayPassword])
        #expect(makeSettings().relayPassword == "stored", "the next launch reads the old value")

        secrets.failWrites = false
        s.relayPassword = ""
        s.flushSecrets()

        #expect(s.unsavedSecrets.isEmpty)
        #expect(secrets.items.isEmpty)
    }

    @Test func typingASecretAppliesAtOnceButWritesTheKeychainOnlyOnFlush() {
        let s = makeSettings()

        for typed in ["h", "hu", "hun"] { s.relayPassword = typed }

        #expect(s.relayPassword == "hun", "the edit applies for this launch right away")
        #expect(secrets.writes == 0, "no Keychain write per keystroke")

        s.flushSecrets()
        #expect(secrets.items["relayPassword"] == "hun")
        #expect(secrets.writes == 1)

        s.flushSecrets()
        #expect(secrets.writes == 1, "a flush with nothing edited writes nothing")
    }

    @Test func aPauseInTypingWritesTheLastValueOnce() async throws {
        let s = AppSettings(
            storage: storage, secrets: secrets, secretWriteDelay: .milliseconds(30))

        for typed in ["h", "hu", "hun"] { s.relayPassword = typed }
        #expect(secrets.writes == 0)

        for _ in 0..<200 where secrets.writes == 0 { try await Task.sleep(for: .milliseconds(10)) }
        #expect(secrets.items["relayPassword"] == "hun")
        #expect(secrets.writes == 1)
    }
}

@Suite struct MemorySettingsStorageTests {
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
