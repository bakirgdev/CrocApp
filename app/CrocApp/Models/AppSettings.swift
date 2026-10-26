import CrocKit
import Foundation
import Observation

/// Persisted app options. String relay fields store "" for
/// "use croc default" and go to the engine as stored; the engine resolves
/// defaults and the public relay pool. Each property writes its own key to
/// `storage` in `didSet` (which does not fire for the assignments in init), so
/// adding a setting never resets the others. A harness run and the tests pass
/// in-memory storage and secrets instead of the real ones. `relayPassword` is
/// the one exception to "storage": it lives in `secrets` (the Keychain, see
/// `KeychainStore`). The Advanced proxies are the same: they can carry
/// credentials, so they live in `secrets` and never in `storage`.
@MainActor
@Observable
final class AppSettings {
    private static let relayPasswordAccount = "relayPassword"

    private static let socks5ProxyAccount = "advanced.socks5Proxy"
    private static let httpProxyAccount = "advanced.httpProxy"

    enum RelayKind: Equatable {
        case publicDefault
        case custom(String)
        case localOnly
        /// A receive that connects straight to the sender's IP; no relay.
        case directToSender
    }

    @ObservationIgnored private let storage: any SettingsStorage
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
    /// Where "Send as link" uploads. The engine refuses `http` except
    /// on loopback.
    var storedServer: String { didSet { save(storedServer, "settings.storedServer") } }
    static let defaultStoredServer = StoredSendOptions().server
    /// macOS menu-bar quick send. On by default; the menu-bar scene is
    /// inserted only while this is true.
    var showInMenuBar: Bool { didSet { save(showInMenuBar, "settings.showInMenuBar") } }
    /// Off: a finished transfer leaves no History record. Records already
    /// there stay until the user deletes them.
    var saveTransferHistory: Bool {
        didSet { save(saveTransferHistory, "settings.saveTransferHistory") }
    }
    /// iPhone only. Off silences every haptic; the screen still shows each event.
    var haptics: Bool { didSet { save(haptics, "settings.haptics") } }

    // Advanced. Defaults are croc's, read from `EngineOptions`.
    static let advancedDefaults = EngineOptions()

    /// croc's format ("500k"); blank means no limit. Send only.
    var throttleUpload: String {
        didSet { save(throttleUpload, "settings.advanced.throttleUpload") }
    }
    /// Blank means croc's default group. macOS only: iOS has no multicast entitlement.
    var multicastAddress: String {
        didSet { save(multicastAddress, "settings.advanced.multicastAddress") }
    }
    /// Receive only: the sender's ip:port.
    var peerIP: String { didSet { save(peerIP, "settings.advanced.peerIP") } }
    /// Proxies may carry credentials: Keychain only, see `persistProxy`.
    var socks5Proxy: String {
        didSet { persistProxy(socks5Proxy, account: Self.socks5ProxyAccount) }
    }
    var httpProxy: String {
        didSet { persistProxy(httpProxy, account: Self.httpProxyAccount) }
    }

    /// Why `text` cannot be a stored-transfer server, or nil when it can. The
    /// engine decides: `https`, or `http` on loopback only, and nothing after
    /// the host. Blank is refused, unlike the Advanced fields.
    static func storedServerError(_ text: String) -> String? {
        engineError(
            .storeServer, text,
            "Enter the server's address only, such as \(defaultStoredServer). It must use https, or http for localhost."
        )
    }

    init(
        storage: any SettingsStorage = UserDefaults.standard,
        secrets: any SecretStore = KeychainStore()
    ) {
        self.storage = storage
        self.secrets = secrets
        relayAddress = Self.read(storage, "settings.relayAddress", default: "")
        relayAddress6 = Self.read(storage, "settings.relayAddress6", default: "")
        relayPassword = secrets.get(account: Self.relayPasswordAccount) ?? ""
        onlyLocal = Self.read(storage, "settings.onlyLocal", default: false)
        noCompress = Self.read(storage, "settings.noCompress", default: false)
        zipFolder = Self.read(storage, "settings.zipFolder", default: false)
        excludePatterns = Self.read(storage, "settings.excludePatterns", default: "")
        useGitIgnore = Self.read(storage, "settings.useGitIgnore", default: false)
        autoAccept = Self.read(storage, "settings.autoAccept", default: false)
        bothSidesConfirm = Self.read(storage, "settings.bothSidesConfirm", default: false)
        whenFileExists =
            (storage.object(forKey: "settings.whenFileExists") as? String)
            .flatMap(FilePolicy.init(rawValue:)) ?? .keepBoth
        storedServer = Self.read(
            storage, "settings.storedServer", default: Self.defaultStoredServer)
        showInMenuBar = Self.read(storage, "settings.showInMenuBar", default: true)
        saveTransferHistory = Self.read(storage, "settings.saveTransferHistory", default: true)
        haptics = Self.read(storage, "settings.haptics", default: true)
        let croc = Self.advancedDefaults
        throttleUpload = Self.read(
            storage, "settings.advanced.throttleUpload", default: croc.throttleUpload)
        multicastAddress = Self.read(
            storage, "settings.advanced.multicastAddress", default: croc.multicastAddress)
        peerIP = Self.read(storage, "settings.advanced.peerIP", default: croc.peerIP)
        socks5Proxy = secrets.get(account: Self.socks5ProxyAccount) ?? ""
        httpProxy = secrets.get(account: Self.httpProxyAccount) ?? ""
    }

    /// The stored value, or `fallback` when the key is absent or holds another type.
    private static func read<Value>(
        _ storage: any SettingsStorage, _ key: String, default fallback: Value
    ) -> Value {
        storage.object(forKey: key) as? Value ?? fallback
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

    /// The Reset to Defaults button in Settings > Advanced: every Advanced
    /// control back to croc's default. Persists like any edit, and clearing the
    /// proxies deletes their Keychain items.
    func resetAdvancedToDefaults() {
        let croc = Self.advancedDefaults
        throttleUpload = croc.throttleUpload
        multicastAddress = croc.multicastAddress
        peerIP = croc.peerIP
        socks5Proxy = ""
        httpProxy = ""
    }

    /// True when every Advanced control already holds its default.
    var advancedIsDefault: Bool {
        let croc = Self.advancedDefaults
        return throttleUpload.isEmpty && multicastAddress == croc.multicastAddress
            && peerIP.isEmpty && socks5Proxy.isEmpty && httpProxy.isEmpty
    }

    private func save(_ value: Any, _ key: String) {
        storage.set(value, forKey: key)
    }

    /// Deletes rather than stores "" so clearing the field doesn't leave a
    /// Keychain item with an empty password behind.
    private func persistRelayPassword() {
        if relayPassword.isEmpty {
            secrets.delete(account: Self.relayPasswordAccount)
        } else {
            secrets.set(relayPassword, account: Self.relayPasswordAccount)
        }
    }

    /// Keychain-only: a proxy URL can hold a user name and password. Deletes
    /// rather than stores a blank.
    private func persistProxy(_ value: String, account: String) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            secrets.delete(account: account)
        } else {
            secrets.set(trimmed, account: account)
        }
    }
}
