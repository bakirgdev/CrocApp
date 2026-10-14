import CrocKit
import Foundation
import Observation

/// Persisted power options (F13-F19). String relay fields store "" for
/// "use croc default" and go to the engine as stored; the engine resolves
/// defaults and the public relay pool. `persist` gates UserDefaults writes so AutoVerify can override per-run
/// without contaminating real settings. didSet does not fire for the
/// assignments in init. `relayPassword` is the one exception to "UserDefaults":
/// it lives in the Keychain (see `KeychainStore`) and `persist` gates that
/// write too, so a harness run's `resetToDefaults()` can't blank the real
/// stored password.
@MainActor
@Observable
final class AppSettings {
    private static let relayPasswordAccount = "relayPassword"
    private static let legacyRelayPasswordKey = "settings.relayPassword"

    enum RelayKind: Equatable {
        case publicDefault
        case custom(String)
        case localOnly
    }

    @ObservationIgnored var persist = true
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let secrets: any SecretStore

    var relayAddress: String { didSet { save(relayAddress, "settings.relayAddress") } }
    var relayAddress6: String { didSet { save(relayAddress6, "settings.relayAddress6") } }
    var relayPassword: String { didSet { persistRelayPassword() } }
    var onlyLocal: Bool { didSet { save(onlyLocal, "settings.onlyLocal") } }
    var noCompress: Bool { didSet { save(noCompress, "settings.noCompress") } }
    var zipFolder: Bool { didSet { save(zipFolder, "settings.zipFolder") } }
    var excludePatterns: String { didSet { save(excludePatterns, "settings.excludePatterns") } }
    var useGitIgnore: Bool { didSet { save(useGitIgnore, "settings.useGitIgnore") } }
    var autoAccept: Bool { didSet { save(autoAccept, "settings.autoAccept") } }
    var bothSidesConfirm: Bool { didSet { save(bothSidesConfirm, "settings.bothSidesConfirm") } }
    /// Used under auto-accept; the incoming sheet asks instead.
    var whenFileExists: FilePolicy {
        didSet { save(whenFileExists.rawValue, "settings.whenFileExists") }
    }
    /// Send only; a receive follows the sender.
    var transport: Transport {
        didSet { save(transport.rawValue, "settings.transport") }
    }

    init(defaults d: UserDefaults = .standard, secrets: any SecretStore = KeychainStore()) {
        defaults = d
        self.secrets = secrets
        relayAddress = d.string(forKey: "settings.relayAddress") ?? ""
        relayAddress6 = d.string(forKey: "settings.relayAddress6") ?? ""
        // Runs before AutoVerify can ever flip `persist` false (AppSettings()
        // is constructed first in CrocAppApp.init), so this always sees a
        // real launch's persist=true default.
        relayPassword = Self.migrateRelayPassword(defaults: d, secrets: secrets)
        onlyLocal = d.bool(forKey: "settings.onlyLocal")
        noCompress = d.bool(forKey: "settings.noCompress")
        zipFolder = d.bool(forKey: "settings.zipFolder")
        excludePatterns = d.string(forKey: "settings.excludePatterns") ?? ""
        useGitIgnore = d.bool(forKey: "settings.useGitIgnore")
        autoAccept = d.bool(forKey: "settings.autoAccept")
        bothSidesConfirm = d.bool(forKey: "settings.bothSidesConfirm")
        whenFileExists =
            d.string(forKey: "settings.whenFileExists").flatMap(FilePolicy.init(rawValue:))
            ?? .keepBoth
        transport =
            d.string(forKey: "settings.transport").flatMap(Transport.init(rawValue:)) ?? .auto
    }

    var relayKind: RelayKind {
        if onlyLocal { return .localOnly }
        let addr = relayAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        if !addr.isEmpty, addr != RelayDefaults.address { return .custom(addr) }
        let addr6 = relayAddress6.trimmingCharacters(in: .whitespacesAndNewlines)
        if !addr6.isEmpty, addr6 != RelayDefaults.address6 { return .custom(addr6) }
        return .publicDefault
    }

    var excludeList: [String] {
        excludePatterns.split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    /// Harness-only: force every field back to its blank/default state so a
    /// manual run's UserDefaults can't bleed into a harness run (call only
    /// after `persist = false`, so this itself never writes UserDefaults or,
    /// for `relayPassword`, the Keychain).
    func resetToDefaults() {
        relayAddress = ""
        relayAddress6 = ""
        relayPassword = ""
        onlyLocal = false
        noCompress = false
        zipFolder = false
        excludePatterns = ""
        useGitIgnore = false
        autoAccept = false
        bothSidesConfirm = false
        whenFileExists = .keepBoth
        transport = .auto
    }

    /// One-time move of the relay password off UserDefaults (plaintext
    /// plist) into the Keychain. The legacy value is removed only after the
    /// Keychain write succeeds; on failure this launch uses it and the next
    /// launch retries.
    private static func migrateRelayPassword(
        defaults: UserDefaults, secrets: any SecretStore
    ) -> String {
        guard let legacy = defaults.string(forKey: legacyRelayPasswordKey), !legacy.isEmpty else {
            return secrets.get(account: relayPasswordAccount) ?? ""
        }
        if secrets.set(legacy, account: relayPasswordAccount) {
            defaults.removeObject(forKey: legacyRelayPasswordKey)
        }
        return legacy
    }

    private func save(_ value: Any, _ key: String) {
        guard persist else { return }
        defaults.set(value, forKey: key)
    }

    /// Mirrors `save`'s `persist` gate but targets the Keychain instead of
    /// UserDefaults. Deletes rather than stores "" so clearing the field
    /// doesn't leave a Keychain item with an empty password behind. A
    /// successful write also drops a legacy value a failed migration kept,
    /// which would otherwise overwrite this one on the next launch.
    private func persistRelayPassword() {
        guard persist else { return }
        let stored =
            relayPassword.isEmpty
            ? secrets.delete(account: Self.relayPasswordAccount)
            : secrets.set(relayPassword, account: Self.relayPasswordAccount)
        if stored { defaults.removeObject(forKey: Self.legacyRelayPasswordKey) }
    }
}
