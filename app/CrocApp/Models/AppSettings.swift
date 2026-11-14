import CrocKit
import Foundation
import Observation

/// Persisted app options. String relay fields store "" for
/// "use croc default" and go to the engine as stored; the engine resolves
/// defaults and the public relay pool. Each property writes its own key to
/// `storage` in `didSet` (which does not fire for the assignments in init), so
/// adding a setting never resets the others. A harness run and the tests pass
/// in-memory storage and secrets instead of the real ones. The relay passwords
/// are the exception to "storage": they live in `secrets` (the Keychain, see
/// `KeychainStore`). The Advanced proxies are the same: they can carry
/// credentials, so they live in `secrets` and never in `storage`. A secret
/// takes its new value at once but reaches `secrets` only after the edits stop
/// (`flushSecrets`), so typing does not write the Keychain on every keystroke.
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

    /// The `storage` key of every setting kept there, typed once. The strings are what
    /// existing installs saved: change none of them (`AppSettingsPersistenceTests`
    /// pins them).
    enum Key: String, CaseIterable {
        case relayAddress = "settings.relayAddress"
        case relayAddress6 = "settings.relayAddress6"
        case onlyLocal = "settings.onlyLocal"
        case noCompress = "settings.noCompress"
        case zipFolder = "settings.zipFolder"
        case excludePatterns = "settings.excludePatterns"
        case useGitIgnore = "settings.useGitIgnore"
        case autoAccept = "settings.autoAccept"
        case bothSidesConfirm = "settings.bothSidesConfirm"
        case whenFileExists = "settings.whenFileExists"
        case storedServer = "settings.storedServer"
        case showInMenuBar = "settings.showInMenuBar"
        case showDockBadge = "settings.showDockBadge"
        case saveTransferHistory = "settings.saveTransferHistory"
        case haptics = "settings.haptics"
        case successfulTransfers = "settings.successfulTransfers"
        case lastReviewPromptVersion = "settings.lastReviewPromptVersion"
        case notificationsEnabled = "settings.notificationsEnabled"
        case notificationsShowFileNames = "settings.notificationsShowFileNames"
        case systemSurfacesShowFileNames = "settings.systemSurfacesShowFileNames"
        case throttleUpload = "settings.advanced.throttleUpload"
        case peerIP = "settings.advanced.peerIP"
        case disableLocal = "settings.advanced.disableLocal"
    }

    @ObservationIgnored private let storage: any SettingsStorage
    @ObservationIgnored private let secrets: any SecretStore
    @ObservationIgnored private let secretWriteDelay: Duration
    @ObservationIgnored private var dirtySecrets: Set<Secret> = []
    @ObservationIgnored private var secretWriteTask: Task<Void, Never>?

    var relayAddress: String { didSet { save(relayAddress, .relayAddress) } }
    var relayAddress6: String { didSet { save(relayAddress6, .relayAddress6) } }
    var relayPassword: String { didSet { secretEdited(.relayPassword) } }
    var onlyLocal: Bool { didSet { save(onlyLocal, .onlyLocal) } }
    var noCompress: Bool { didSet { save(noCompress, .noCompress) } }
    var zipFolder: Bool { didSet { save(zipFolder, .zipFolder) } }
    var excludePatterns: String { didSet { save(excludePatterns, .excludePatterns) } }
    var useGitIgnore: Bool { didSet { save(useGitIgnore, .useGitIgnore) } }
    var autoAccept: Bool { didSet { save(autoAccept, .autoAccept) } }
    var bothSidesConfirm: Bool { didSet { save(bothSidesConfirm, .bothSidesConfirm) } }
    /// Used under auto-accept; the incoming sheet asks instead.
    var whenFileExists: FilePolicy {
        didSet { save(whenFileExists.rawValue, .whenFileExists) }
    }
    /// Where "Send as link" uploads. The engine refuses `http` except
    /// on loopback.
    var storedServer: String { didSet { save(storedServer, .storedServer) } }
    static let defaultStoredServer = StoredSendOptions().server
    /// macOS menu-bar quick send. The menu-bar scene is
    /// inserted only while this is true.
    var showInMenuBar: Bool { didSet { save(showInMenuBar, .showInMenuBar) } }
    /// macOS Dock tile badge: the percent while bytes move, "1" while a request
    /// waits. No names, so on by default.
    var showDockBadge: Bool { didSet { save(showDockBadge, .showDockBadge) } }
    /// Off: a finished transfer leaves no History record. Records already
    /// there stay until the user deletes them.
    var saveTransferHistory: Bool {
        didSet { save(saveTransferHistory, .saveTransferHistory) }
    }
    /// iPhone only. Off silences every haptic; the screen still shows each event.
    var haptics: Bool { didSet { save(haptics, .haptics) } }
    /// Transfers that finished successfully, for `ReviewPrompt`.
    private(set) var successfulTransfers: Int {
        didSet { save(successfulTransfers, .successfulTransfers) }
    }
    /// The app version the review prompt was last requested in; empty before the first.
    var lastReviewPromptVersion: String {
        didSet { save(lastReviewPromptVersion, .lastReviewPromptVersion) }
    }
    /// On by default because the permission prompt comes with the first
    /// transfer, when a notification is useful (`TransferNotifier`).
    var notificationsEnabled: Bool {
        didSet { save(notificationsEnabled, .notificationsEnabled) }
    }
    /// A notification can be read on a locked screen, so it
    /// says "Transfer complete" unless the user asks for file names.
    var notificationsShowFileNames: Bool {
        didSet { save(notificationsShowFileNames, .notificationsShowFileNames) }
    }

    /// Widgets and the iOS Live Activity show on a locked
    /// screen, so they say "Sending" or "Received" unless the user asks for
    /// file names (`TransferSnapshotWriter`, `BackgroundCoordinator`).
    var systemSurfacesShowFileNames: Bool {
        didSet { save(systemSurfacesShowFileNames, .systemSurfacesShowFileNames) }
    }

    // Advanced. Defaults are croc's, read from `EngineOptions`.
    static let advancedDefaults = EngineOptions()

    /// croc's format ("500k"); blank means no limit. Send only.
    var throttleUpload: String {
        didSet { save(throttleUpload, .throttleUpload) }
    }
    /// Receive only: the sender's ip:port.
    var peerIP: String { didSet { save(peerIP, .peerIP) } }
    /// Skips the local network for transfers: no LAN discovery or local relay.
    /// croc's `--no-local`. Excludes `onlyLocal`.
    var disableLocal: Bool { didSet { save(disableLocal, .disableLocal) } }
    /// Proxies may carry credentials: Keychain only, see `persistProxy`.
    var socks5Proxy: String {
        didSet { secretEdited(.socks5Proxy) }
    }
    var httpProxy: String {
        didSet { secretEdited(.httpProxy) }
    }

    /// The settings kept in `secrets` instead of `storage`.
    enum Secret {
        case relayPassword, socks5Proxy, httpProxy
    }

    /// Secrets whose last write to `secrets` failed. The property keeps the
    /// edit for this launch, but the store still holds the previous value,
    /// which is what the next launch reads. A secret leaves the set on its
    /// next successful write.
    private(set) var unsavedSecrets: Set<Secret> = []

    /// The inline error under a field in `unsavedSecrets`. Never names the value.
    static var secretNotSavedTitle: String {
        String(localized: "Couldn't save to the Keychain")
    }

    static var secretNotSavedDetail: String {
        String(
            localized: "Edit the field to try again before you quit CrocApp.",
            comment:
                "Under a Keychain field whose change was not saved. Until it is, the next launch shows the previous value."
        )
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
        secrets: any SecretStore = KeychainStore(),
        secretWriteDelay: Duration = .milliseconds(500)
    ) {
        self.storage = storage
        self.secrets = secrets
        self.secretWriteDelay = secretWriteDelay
        // 1.3.0 removed the relay this Mac ran; drop what it left behind.
        storage.set(nil, forKey: "settings.relayHostPort")
        storage.set(nil, forKey: "settings.relayHostAtLaunch")
        // 1.3.0 removed Spotlight indexing (`SpotlightPurge` empties the index).
        storage.set(nil, forKey: "settings.indexHistoryInSpotlight")
        // 1.3.0 removed four Advanced options: multicast address, built-in DNS, single connection, exact exclude paths.
        for key in ["multicastAddress", "internalDNS", "noMultiplexing", "excludePaths"] {
            storage.set(nil, forKey: "settings.advanced.\(key)")
        }
        if secrets.get(account: "relayHostPassword") != nil {
            secrets.delete(account: "relayHostPassword")
        }
        relayAddress = Self.read(storage, .relayAddress, default: "")
        relayAddress6 = Self.read(storage, .relayAddress6, default: "")
        relayPassword = secrets.get(account: Self.relayPasswordAccount) ?? ""
        onlyLocal = Self.read(storage, .onlyLocal, default: false)
        noCompress = Self.read(storage, .noCompress, default: false)
        zipFolder = Self.read(storage, .zipFolder, default: false)
        excludePatterns = Self.read(storage, .excludePatterns, default: "")
        useGitIgnore = Self.read(storage, .useGitIgnore, default: false)
        autoAccept = Self.read(storage, .autoAccept, default: false)
        bothSidesConfirm = Self.read(storage, .bothSidesConfirm, default: false)
        whenFileExists =
            (storage.object(forKey: Key.whenFileExists.rawValue) as? String)
            .flatMap(FilePolicy.init(rawValue:)) ?? .keepBoth
        storedServer = Self.read(storage, .storedServer, default: Self.defaultStoredServer)
        showInMenuBar = Self.read(storage, .showInMenuBar, default: true)
        showDockBadge = Self.read(storage, .showDockBadge, default: true)
        saveTransferHistory = Self.read(storage, .saveTransferHistory, default: true)
        haptics = Self.read(storage, .haptics, default: true)
        successfulTransfers = Self.read(storage, .successfulTransfers, default: 0)
        lastReviewPromptVersion = Self.read(storage, .lastReviewPromptVersion, default: "")
        notificationsEnabled = Self.read(storage, .notificationsEnabled, default: true)
        notificationsShowFileNames = Self.read(storage, .notificationsShowFileNames, default: false)
        systemSurfacesShowFileNames = Self.read(
            storage, .systemSurfacesShowFileNames, default: false)
        let croc = Self.advancedDefaults
        throttleUpload = Self.read(storage, .throttleUpload, default: croc.throttleUpload)
        peerIP = Self.read(storage, .peerIP, default: croc.peerIP)
        disableLocal = Self.read(storage, .disableLocal, default: croc.disableLocal)
        socks5Proxy = secrets.get(account: Self.socks5ProxyAccount) ?? ""
        httpProxy = secrets.get(account: Self.httpProxyAccount) ?? ""
    }

    /// The stored value, or `fallback` when the key is absent or holds another type.
    private static func read<Value>(
        _ storage: any SettingsStorage, _ key: Key, default fallback: Value
    ) -> Value {
        storage.object(forKey: key.rawValue) as? Value ?? fallback
    }

    /// Mirrors `usesPublicRelay` and `customRelays` in crocmobile/relay.go, so the trust
    /// UI predicts the relay the engine picks. Change them together.
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
        peerIP = croc.peerIP
        disableLocal = croc.disableLocal
        socks5Proxy = ""
        httpProxy = ""
        flushSecrets()
    }

    var advancedIsDefault: Bool {
        throttleUpload.isEmpty && peerIP.isEmpty && !disableLocal
            && socks5Proxy.isEmpty && httpProxy.isEmpty
    }

    func recordSuccessfulTransfer() { successfulTransfers += 1 }

    private func save(_ value: Any, _ key: Key) {
        storage.set(value, forKey: key.rawValue)
    }

    /// A secret field changed: the new value applies now, and the Keychain write
    /// waits until `secretWriteDelay` passes without another edit. A new edit
    /// cancels the pending wait, so a burst of keystrokes is one write.
    private func secretEdited(_ secret: Secret) {
        dirtySecrets.insert(secret)
        secretWriteTask?.cancel()
        secretWriteTask = Task { [weak self, secretWriteDelay] in
            do { try await Task.sleep(for: secretWriteDelay) } catch { return }
            self?.flushSecrets()
        }
    }

    /// Writes every edited secret to `secrets` now. Call it where the app can
    /// stop before the delay runs out: quitting, or leaving the foreground.
    func flushSecrets() {
        secretWriteTask?.cancel()
        secretWriteTask = nil
        let dirty = dirtySecrets
        dirtySecrets = []
        for secret in dirty {
            switch secret {
            case .relayPassword: persistRelayPassword()
            case .socks5Proxy:
                persistProxy(socks5Proxy, account: Self.socks5ProxyAccount, as: .socks5Proxy)
            case .httpProxy:
                persistProxy(httpProxy, account: Self.httpProxyAccount, as: .httpProxy)
            }
        }
    }

    /// Deletes rather than stores "" so clearing the field doesn't leave a
    /// Keychain item with an empty password behind.
    private func persistRelayPassword() {
        let saved =
            relayPassword.isEmpty
            ? secrets.delete(account: Self.relayPasswordAccount)
            : secrets.set(relayPassword, account: Self.relayPasswordAccount)
        record(saved, for: .relayPassword)
    }

    /// Keychain-only: a proxy URL can hold a user name and password. Deletes
    /// rather than stores a blank.
    private func persistProxy(_ value: String, account: String, as secret: Secret) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let saved =
            trimmed.isEmpty
            ? secrets.delete(account: account)
            : secrets.set(trimmed, account: account)
        record(saved, for: secret)
    }

    /// Touches `unsavedSecrets` only when the outcome changes, because a write
    /// that repeats the last outcome would otherwise redraw whatever reads the
    /// set.
    private func record(_ saved: Bool, for secret: Secret) {
        if saved {
            if unsavedSecrets.contains(secret) { unsavedSecrets.remove(secret) }
        } else if !unsavedSecrets.contains(secret) {
            unsavedSecrets.insert(secret)
        }
    }
}
