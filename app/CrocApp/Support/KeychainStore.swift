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
/// pulled into unencrypted device backups. `kSecAttrAccessibleAfterFirstUnlock`
/// keeps items readable by background transfers without a biometric/passcode
/// prompt.
///
/// Deliberately does *not* set `kSecUseDataProtectionKeychain`, so macOS uses
/// the file-based keychain. The data-protection keychain is the modern
/// recommendation, but it resolves an app's keychain access group from the
/// team ID in its signature: unsigned builds (tests and CI run with
/// `CODE_SIGNING_ALLOWED=NO`) have none and fail with
/// `errSecMissingEntitlement`. Switching later also needs a migration, since
/// items already in the file-based keychain are not visible from the other.
/// iOS is unaffected: it only has the data-protection keychain.
///
/// Failures are logged with their `OSStatus`, never the value.
struct KeychainStore: SecretStore {
    private static let service = "com.bakirgdev.CrocApp"
    private static let log = Logger(subsystem: "com.bakirgdev.CrocApp", category: "keychain")

    /// Write `value` under `account`, replacing any existing item.
    /// Add-then-update-on-`errSecDuplicateItem` rather than delete-then-add,
    /// so a failed update can't leave the account with nothing stored.
    @discardableResult
    func set(_ value: String, account: String) -> Bool {
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.service,
            kSecAttrAccount as String: account,
        ]
        var addAttributes = query
        addAttributes[kSecValueData as String] = data
        addAttributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock

        let addStatus = SecItemAdd(addAttributes as CFDictionary, nil)
        if addStatus == errSecSuccess { return true }
        guard addStatus == errSecDuplicateItem else {
            Self.log.error("add \(account, privacy: .public) failed: OSStatus \(addStatus)")
            return false
        }

        let updateStatus = SecItemUpdate(
            query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        guard updateStatus == errSecSuccess else {
            Self.log.error("update \(account, privacy: .public) failed: OSStatus \(updateStatus)")
            return false
        }
        return true
    }

    /// Read the value stored under `account`, or nil if absent.
    func get(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
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
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.service,
            kSecAttrAccount as String: account,
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            Self.log.error("delete \(account, privacy: .public) failed: OSStatus \(status)")
            return false
        }
        return true
    }
}
