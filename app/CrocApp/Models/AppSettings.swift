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
/// stored password. The Advanced proxies (R25) are the same: they can carry
/// credentials, so they live in the Keychain and never in UserDefaults.
@MainActor
@Observable
final class AppSettings {
    private static let relayPasswordAccount = "relayPassword"
    private static let legacyRelayPasswordKey = "settings.relayPassword"

    private static let socks5ProxyAccount = "advanced.socks5Proxy"
    private static let httpProxyAccount = "advanced.httpProxy"

    enum RelayKind: Equatable {
        case publicDefault
        case custom(String)
        case localOnly
        /// A receive that connects straight to the sender's IP (R25); no relay.
        case directToSender
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
    /// Where "Send as link" uploads (R21). The engine refuses `http` except
    /// on loopback.
    var storedServer: String { didSet { save(storedServer, "settings.storedServer") } }
    static let defaultStoredServer = StoredSendOptions().server
    /// macOS menu-bar quick send (R26). On by default; the menu-bar scene is
    /// inserted only while this is true.
    var showInMenuBar: Bool { didSet { save(showInMenuBar, "settings.showInMenuBar") } }

    // Advanced (R25). Defaults are croc's, read from `EngineOptions`.
    static let advancedDefaults = EngineOptions()

    var curve: Curve { didSet { save(curve.rawValue, "settings.advanced.curve") } }
    var hashAlgorithm: HashAlgorithm {
        didSet { save(hashAlgorithm.rawValue, "settings.advanced.hashAlgorithm") }
    }
    /// croc's format ("500k"); blank means no limit. Send only.
    var throttleUpload: String {
        didSet { save(throttleUpload, "settings.advanced.throttleUpload") }
    }
    /// Stored negated so the unset default is croc's: several connections.
    var noMultiplexing: Bool { didSet { save(noMultiplexing, "settings.advanced.noMultiplexing") } }
    var basePort: Int { didSet { save(basePort, "settings.advanced.basePort") } }
    /// Parallel connections: the data ports after `basePort`.
    var transfers: Int { didSet { save(transfers, "settings.advanced.transfers") } }
    /// Blank means croc's default group. macOS only: iOS has no multicast entitlement.
    var multicastAddress: String {
        didSet { save(multicastAddress, "settings.advanced.multicastAddress") }
    }
    /// Receive only: the sender's ip:port.
    var peerIP: String { didSet { save(peerIP, "settings.advanced.peerIP") } }
    var internalDNS: Bool { didSet { save(internalDNS, "settings.advanced.internalDNS") } }
    /// Proxies may carry credentials: Keychain only, see `persistProxy`.
    var socks5Proxy: String {
        didSet { persistProxy(socks5Proxy, account: Self.socks5ProxyAccount) }
    }
    var httpProxy: String {
        didSet { persistProxy(httpProxy, account: Self.httpProxyAccount) }
    }

    /// Why `text` cannot be a stored-transfer server, or nil when it can (R12e).
    /// Mirrors the engine: `https`, or `http` on loopback only, and nothing
    /// after the host.
    static func storedServerError(_ text: String) -> String? {
        let address = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let parts = URLComponents(string: address),
            let scheme = parts.scheme?.lowercased(), scheme == "https" || scheme == "http",
            let host = parts.host?.lowercased().trimmingCharacters(in: ["[", "]"]), !host.isEmpty
        else { return "Enter a server address such as \(defaultStoredServer)." }
        guard parts.user == nil, parts.password == nil, parts.query == nil, parts.fragment == nil,
            parts.path.isEmpty || parts.path == "/"
        else { return "Enter the server's address only, with nothing after the host name." }
        if scheme == "http", !TransferLink.loopbackHosts.contains(host) {
            return "The server must use https. Plain http works only for localhost."
        }
        return nil
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
        storedServer = d.string(forKey: "settings.storedServer") ?? Self.defaultStoredServer
        showInMenuBar = d.object(forKey: "settings.showInMenuBar") as? Bool ?? true
        let croc = Self.advancedDefaults
        curve =
            d.string(forKey: "settings.advanced.curve").flatMap(Curve.init(rawValue:)) ?? croc.curve
        hashAlgorithm =
            d.string(forKey: "settings.advanced.hashAlgorithm").flatMap(
                HashAlgorithm.init(rawValue:))
            ?? croc.hashAlgorithm
        throttleUpload = d.string(forKey: "settings.advanced.throttleUpload") ?? croc.throttleUpload
        noMultiplexing = d.bool(forKey: "settings.advanced.noMultiplexing")
        basePort = d.object(forKey: "settings.advanced.basePort") as? Int ?? croc.basePort
        transfers = d.object(forKey: "settings.advanced.transfers") as? Int ?? croc.transfers
        multicastAddress =
            d.string(forKey: "settings.advanced.multicastAddress") ?? croc.multicastAddress
        peerIP = d.string(forKey: "settings.advanced.peerIP") ?? croc.peerIP
        internalDNS = d.bool(forKey: "settings.advanced.internalDNS")
        socks5Proxy = secrets.get(account: Self.socks5ProxyAccount) ?? ""
        httpProxy = secrets.get(account: Self.httpProxyAccount) ?? ""
    }

    var relayKind: RelayKind {
        if onlyLocal { return .localOnly }
        let addr = relayAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        if !addr.isEmpty, addr != RelayDefaults.address { return .custom(addr) }
        let addr6 = relayAddress6.trimmingCharacters(in: .whitespacesAndNewlines)
        if !addr6.isEmpty, addr6 != RelayDefaults.address6 { return .custom(addr6) }
        return .publicDefault
    }

    /// What a receive shows as its path: straight to the sender when a sender
    /// IP is set (the engine turns the public relay pool off for it).
    var receiveRelayKind: RelayKind {
        peerIP.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? relayKind : .directToSender
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
        storedServer = Self.defaultStoredServer
        showInMenuBar = true
        resetAdvancedToDefaults()
    }

    /// The Reset to Defaults button in Settings > Advanced: every Advanced
    /// control back to croc's default. Persists like any edit, and clearing the
    /// proxies deletes their Keychain items.
    func resetAdvancedToDefaults() {
        let croc = Self.advancedDefaults
        curve = croc.curve
        hashAlgorithm = croc.hashAlgorithm
        throttleUpload = croc.throttleUpload
        noMultiplexing = croc.noMultiplexing
        basePort = croc.basePort
        transfers = croc.transfers
        multicastAddress = croc.multicastAddress
        peerIP = croc.peerIP
        internalDNS = croc.internalDNS
        socks5Proxy = ""
        httpProxy = ""
    }

    /// True when every Advanced control already holds its default.
    var advancedIsDefault: Bool {
        let croc = Self.advancedDefaults
        return curve == croc.curve && hashAlgorithm == croc.hashAlgorithm
            && throttleUpload.isEmpty && noMultiplexing == croc.noMultiplexing
            && basePort == croc.basePort && transfers == croc.transfers
            && multicastAddress == croc.multicastAddress && peerIP.isEmpty
            && internalDNS == croc.internalDNS && socks5Proxy.isEmpty && httpProxy.isEmpty
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

    /// Same `persist` gate as the other writes, but Keychain-only: a proxy URL
    /// can hold a user name and password. Deletes rather than stores a blank.
    private func persistProxy(_ value: String, account: String) {
        guard persist else { return }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            secrets.delete(account: account)
        } else {
            secrets.set(trimmed, account: account)
        }
    }
}
