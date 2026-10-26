import Foundation
import OSLog
import Security

/// Where settings secrets are stored. The app uses `KeychainStore`; tests
/// inject an in-memory store so they never touch the real Keychain.
protocol SecretStore {
    func get(account: String) -> String?
    @discardableResult func set(_ value: String, account: String) -> Bool
    @discardableResult func delete(account: String) -> Bool
}

/// Keychain read/write for settings that shouldn't ride along in
/// UserDefaults' plaintext plist. On macOS that plist sits at
/// `~/Library/Containers/<bundle-id>/Data/Library/Preferences/`, readable by
/// any process running as the same user via `defaults read`; on iOS it's
/// pulled into unencrypted device backups.
///
/// `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` keeps items readable by
/// background transfers without a biometric/passcode prompt, and keeps them
/// on this device: a backup restored to another device does not bring them
/// back. `kSecAttrSynchronizable` stays unset, so they never sync through
/// iCloud Keychain either. An update writes the accessibility too, so an item
/// stored under another class takes this one on its next write.
///
/// Every query sets `kSecUseDataProtectionKeychain`. iOS ignores it (it only
/// has that keychain); on macOS it is what makes the accessibility class
/// apply at all, because the legacy file-based keychain ignores it. That
/// keychain scopes items by the `com.apple.application-identifier`
/// entitlement, which a signed Mac build gets from its provisioning profile.
/// Checked on signed development builds of both Mac targets and on the
/// Developer ID export of `CrocApp Direct`; the Mac App Store profile lists
/// it too, but that build was not checked. A Mac build without one
/// (`CODE_SIGNING_ALLOWED=NO`, as CI builds) cannot use the Keychain: a read
/// finds nothing (`errSecItemNotFound`), and a write or delete fails with
/// `errSecMissingEntitlement`, which is logged, so its secrets never persist.
/// Tests and harness runs inject an in-memory `SecretStore`, so in CI only the
/// test host's launch, which only reads, reaches it. Items in the file-based
/// keychain are never read.
///
/// Failures are logged with their `OSStatus`, never the value.
struct KeychainStore: SecretStore {
    private static let service = "com.bakirgdev.CrocApp"
    private static let log = Logger(subsystem: "com.bakirgdev.CrocApp", category: "keychain")

    /// The item for `account`, in the data-protection keychain.
    private static func query(account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecUseDataProtectionKeychain as String: true,
        ]
    }

    /// Write `value` under `account`, replacing any existing item.
    /// Add-then-update-on-`errSecDuplicateItem` rather than delete-then-add,
    /// so a failed update can't leave the account with nothing stored.
    @discardableResult
    func set(_ value: String, account: String) -> Bool {
        let data = Data(value.utf8)
        let query = Self.query(account: account)
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]
        let addAttributes = query.merging(attributes) { $1 }

        let addStatus = SecItemAdd(addAttributes as CFDictionary, nil)
        if addStatus == errSecSuccess { return true }
        guard addStatus == errSecDuplicateItem else {
            Self.log.error("add \(account, privacy: .public) failed: OSStatus \(addStatus)")
            return false
        }

        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        guard updateStatus == errSecSuccess else {
            Self.log.error("update \(account, privacy: .public) failed: OSStatus \(updateStatus)")
            return false
        }
        return true
    }

    /// Read the value stored under `account`, or nil if absent.
    func get(account: String) -> String? {
        var query = Self.query(account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status != errSecSuccess, status != errSecItemNotFound {
            Self.log.error("read \(account, privacy: .public) failed: OSStatus \(status)")
        }
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// Remove the item under `account`, if any. `errSecItemNotFound` counts
    /// as success -- the end state (nothing stored) is what the caller wants.
    @discardableResult
    func delete(account: String) -> Bool {
        let status = SecItemDelete(Self.query(account: account) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            Self.log.error("delete \(account, privacy: .public) failed: OSStatus \(status)")
            return false
        }
        return true
    }
}

/// Secrets that never leave the process, for harness runs, which must not
/// touch the real Keychain.
final class MemorySecretStore: SecretStore {
    private var items: [String: String] = [:]

    func get(account: String) -> String? { items[account] }

    func set(_ value: String, account: String) -> Bool {
        items[account] = value
        return true
    }

    func delete(account: String) -> Bool {
        items[account] = nil
        return true
    }
}
