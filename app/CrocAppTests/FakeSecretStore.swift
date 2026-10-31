import Foundation
import Security

@testable import CrocApp

/// In-memory `SecretStore`; `failWrites` makes every `set` and `delete` fail
/// like a Keychain error would, leaving `items` as it was.
final class FakeSecretStore: SecretStore {
    var items: [String: String] = [:]
    var failWrites = false
    /// Makes `load` throw, like a Keychain that is locked before first unlock.
    var failReads = false

    func get(account: String) -> String? { items[account] }

    func load(account: String) throws -> String? {
        if failReads { throw KeychainReadError(status: errSecInteractionNotAllowed) }
        return items[account]
    }

    func set(_ value: String, account: String) -> Bool {
        guard !failWrites else { return false }
        items[account] = value
        return true
    }

    func delete(account: String) -> Bool {
        guard !failWrites else { return false }
        items[account] = nil
        return true
    }
}
