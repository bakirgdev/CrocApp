import Foundation
import SwiftData
import SwiftUI

/// What this launch is for, decided once. Only `.app` reads the user's
/// preferences and Keychain, opens the on-disk history, and starts notifications,
/// widget data, Spotlight and the relay. A harness run (`AutoVerify`) and a
/// hosted unit-test run get memory-only stores and none of those services, so
/// neither can touch or depend on the developer's real state.
enum LaunchMode {
    case app, harness, test

    static let current: LaunchMode =
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
            .test
        } else if AutoVerify.isHarnessRun {
            .harness
        } else {
            .app
        }

    var isLive: Bool { self == .app }

    func makeSettings() -> AppSettings {
        isLive
            ? AppSettings()
            : AppSettings(storage: MemorySettingsStorage(), secrets: MemorySecretStore())
    }

    func makeSecrets() -> any SecretStore {
        isLive ? KeychainStore() : MemorySecretStore()
    }

    func makeOutputFolder() -> OutputFolderStore {
        isLive ? OutputFolderStore() : OutputFolderStore(defaults: MemorySettingsStorage())
    }

    func makeHistoryContainer() -> ModelContainer {
        HistoryStore.makeContainer(inMemory: !isLive)
    }
}

extension EnvironmentValues {
    @Entry var launchMode: LaunchMode = .app
}
