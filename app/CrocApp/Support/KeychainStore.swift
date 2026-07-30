import Foundation
import Security

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
/// team ID in its signature, and this app ships ad-hoc signed (ADR 0032) — an
/// ad-hoc build has no team ID and would fail with `errSecMissingEntitlement`.
/// Revisit once a Developer ID certificate exists. iOS is unaffected: it only
/// has the data-protection keychain.
enum KeychainStore {
    private static let service = "com.bakirgdev.CrocApp"

    /// Write `value` under `account`, replacing any existing item.
    /// Add-then-update-on-`errSecDuplicateItem` rather than delete-then-add,
    /// so a failed update can't leave the account with nothing stored.
    @discardableResult
    static func set(_ value: String, account: String) -> Bool {
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        var addAttributes = query
        addAttributes[kSecValueData as String] = data
        addAttributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock

        let addStatus = SecItemAdd(addAttributes as CFDictionary, nil)
        if addStatus == errSecSuccess { return true }
        guard addStatus == errSecDuplicateItem else { return false }

        let updateStatus = SecItemUpdate(
            query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        return updateStatus == errSecSuccess
    }

    /// Read the value stored under `account`, or nil if absent.
    static func get(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// Remove the item under `account`, if any. `errSecItemNotFound` counts
    /// as success -- the end state (nothing stored) is what the caller wants.
    @discardableResult
    static func delete(account: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
}
