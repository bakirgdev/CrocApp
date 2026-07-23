import Foundation
import Observation

/// Persisted power options (F13-F19). String relay fields store "" for
/// "use croc default" so the UI can show defaults as placeholders; the
/// `effective*` accessors always return explicit values for UI/display use.
/// `engineRelayAddresses` is what actually goes to the engine: it deliberately
/// blanks the non-customized side (CLI parity, see its own doc comment) so a
/// custom relay can't lose the public relay's dial race; never both empty.
/// `persist` gates UserDefaults writes so AutoVerify can override per-run
/// without contaminating real settings. didSet does not fire for the
/// assignments in init.
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
        if addr != Self.defaultRelayAddress { return .custom(addr) }
        let addr6 = effectiveRelayAddress6
        if addr6 != Self.defaultRelayAddress6 { return .custom(addr6) }
        return .publicDefault
    }

    var excludeList: [String] {
        excludePatterns.split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    /// Relay pair as the croc CLI would pass it: customizing one address
    /// blanks the other so the custom relay can't lose the dial race to a
    /// public default (croc skips empty addresses).
    var engineRelayAddresses: (v4: String, v6: String) {
        let c4 = relayAddress.trimmingCharacters(in: .whitespaces)
        let c6 = relayAddress6.trimmingCharacters(in: .whitespaces)
        let custom4 = !c4.isEmpty && c4 != Self.defaultRelayAddress
        let custom6 = !c6.isEmpty && c6 != Self.defaultRelayAddress6
        if custom4 && !custom6 { return (c4, "") }
        if custom6 && !custom4 { return ("", c6) }
        return (effectiveRelayAddress, effectiveRelayAddress6)
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
