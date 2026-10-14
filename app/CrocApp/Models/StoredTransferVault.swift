import CrocKit
import Foundation
import OSLog

/// Receipts of this device's stored uploads (R19). Each carries the upload
/// token (the right to revoke) and the link (whose fragment is the decryption
/// key), so they live only in the Keychain. All receipts share one item as a
/// JSON array, because `SecretStore` cannot list accounts. A receipt leaves
/// on revoke, or at the first launch after it expires.
@MainActor
final class StoredTransferVault {
    private static let account = "storedReceipts"
    private static let log = Logger(subsystem: "com.bakirgdev.CrocApp", category: "vault")

    private let secrets: any SecretStore
    private var receipts: [StoredReceipt]

    init(secrets: any SecretStore = KeychainStore(), now: Date = .now) {
        self.secrets = secrets
        receipts = Self.load(from: secrets)
        purgeExpired(now: now)
    }

    func receipt(id: String) -> StoredReceipt? {
        receipts.first { $0.id == id }
    }

    /// Returns false when the Keychain write fails. The receipt is then kept
    /// for this launch only: revoke works until the app quits.
    @discardableResult
    func add(_ receipt: StoredReceipt) -> Bool {
        receipts.removeAll { $0.id == receipt.id }
        receipts.append(receipt)
        return persist("add")
    }

    @discardableResult
    func remove(id: String) -> Bool {
        guard receipts.contains(where: { $0.id == id }) else { return true }
        receipts.removeAll { $0.id == id }
        return persist("remove")
    }

    func purgeExpired(now: Date = .now) {
        let count = receipts.count
        receipts.removeAll { $0.expiresAt <= now }
        if receipts.count != count { persist("purge") }
    }

    @discardableResult
    private func persist(_ operation: String) -> Bool {
        let stored: Bool
        if receipts.isEmpty {
            stored = secrets.delete(account: Self.account)
        } else {
            do {
                let data = try JSONEncoder().encode(receipts)
                stored = secrets.set(String(decoding: data, as: UTF8.self), account: Self.account)
            } catch {
                Self.log.error(
                    "receipts \(operation, privacy: .public) encode failed: \(String(describing: error), privacy: .public)"
                )
                return false
            }
        }
        if !stored {
            Self.log.error("receipts \(operation, privacy: .public) not saved to the Keychain")
        }
        return stored
    }

    /// An unreadable item is logged and treated as empty; the next write
    /// replaces it.
    private static func load(from secrets: any SecretStore) -> [StoredReceipt] {
        guard let json = secrets.get(account: account) else { return [] }
        do {
            return try JSONDecoder().decode([StoredReceipt].self, from: Data(json.utf8))
        } catch {
            log.error(
                "receipts unreadable, starting empty: \(String(describing: error), privacy: .private)"
            )
            return []
        }
    }
}
