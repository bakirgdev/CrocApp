import Foundation

@testable import CrocApp

/// In-memory `SecretStore`; `failWrites` makes every `set` and `delete` fail
/// like a Keychain error would, leaving `items` as it was.
final class FakeSecretStore: SecretStore {
    var items: [String: String] = [:]
    var failWrites = false

    func get(account: String) -> String? { items[account] }

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
