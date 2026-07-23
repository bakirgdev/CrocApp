import Foundation
import Observation

/// Persisted power options (F13-F19). String relay fields store "" for
/// "use croc default" so the UI can show defaults as placeholders; the
/// `effective*` accessors always return explicit values (the engine must
/// never receive an empty relay, bridge doc). `persist` gates UserDefaults
/// writes so AutoVerify can override per-run without contaminating real
/// settings. didSet does not fire for the assignments in init.
@MainActor
@Observable
final class AppSettings {
    static let defaultRelayAddress = "croc.schollz.com:9009"
    static let defaultRelayAddress6 = "croc6.schollz.com:9009"
    static let defaultRelayPassword = "pass123"

    enum RelayKind: Equatable {
        case publicDefault
        case custom(String)
        case localOnly
    }

    @ObservationIgnored var persist = true

    var relayAddress: String { didSet { save(relayAddress, "settings.relayAddress") } }
    var relayAddress6: String { didSet { save(relayAddress6, "settings.relayAddress6") } }
    var relayPassword: String { didSet { save(relayPassword, "settings.relayPassword") } }
    var onlyLocal: Bool { didSet { save(onlyLocal, "settings.onlyLocal") } }
    var noCompress: Bool { didSet { save(noCompress, "settings.noCompress") } }
    var zipFolder: Bool { didSet { save(zipFolder, "settings.zipFolder") } }
    var excludePatterns: String { didSet { save(excludePatterns, "settings.excludePatterns") } }
    var useGitIgnore: Bool { didSet { save(useGitIgnore, "settings.useGitIgnore") } }
    var autoAccept: Bool { didSet { save(autoAccept, "settings.autoAccept") } }
    var bothSidesConfirm: Bool { didSet { save(bothSidesConfirm, "settings.bothSidesConfirm") } }

    init() {
        let d = UserDefaults.standard
        relayAddress = d.string(forKey: "settings.relayAddress") ?? ""
        relayAddress6 = d.string(forKey: "settings.relayAddress6") ?? ""
        relayPassword = d.string(forKey: "settings.relayPassword") ?? ""
        onlyLocal = d.bool(forKey: "settings.onlyLocal")
        noCompress = d.bool(forKey: "settings.noCompress")
        zipFolder = d.bool(forKey: "settings.zipFolder")
        excludePatterns = d.string(forKey: "settings.excludePatterns") ?? ""
        useGitIgnore = d.bool(forKey: "settings.useGitIgnore")
        autoAccept = d.bool(forKey: "settings.autoAccept")
        bothSidesConfirm = d.bool(forKey: "settings.bothSidesConfirm")
    }

    var effectiveRelayAddress: String {
        let t = relayAddress.trimmingCharacters(in: .whitespaces)
        return t.isEmpty ? Self.defaultRelayAddress : t
    }

    var effectiveRelayAddress6: String {
        let t = relayAddress6.trimmingCharacters(in: .whitespaces)
        return t.isEmpty ? Self.defaultRelayAddress6 : t
    }

    var effectiveRelayPassword: String {
        relayPassword.isEmpty ? Self.defaultRelayPassword : relayPassword
    }

    var relayKind: RelayKind {
        if onlyLocal { return .localOnly }
        let addr = effectiveRelayAddress
        return addr == Self.defaultRelayAddress ? .publicDefault : .custom(addr)
    }

    var excludeList: [String] {
        excludePatterns.split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    /// Harness-only: force every field back to its blank/default state so a
    /// manual run's UserDefaults can't bleed into a harness run (call only
    /// after `persist = false`, so this itself never writes UserDefaults).
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
    }

    private func save(_ value: Any, _ key: String) {
        guard persist else { return }
        UserDefaults.standard.set(value, forKey: key)
    }
}
