import Foundation

/// Where `AppSettings` keeps its values, one property-list value per key. The
/// app uses `UserDefaults`; a harness run and the tests inject
/// `MemorySettingsStorage`, so they never read or write the real preferences.
/// Passing nil removes the key, as `UserDefaults.set(_:forKey:)` does.
protocol SettingsStorage {
    func object(forKey key: String) -> Any?
    func set(_ value: Any?, forKey key: String)
}

extension UserDefaults: SettingsStorage {}

/// Settings that never leave the process.
final class MemorySettingsStorage: SettingsStorage {
    private(set) var values: [String: Any] = [:]

    func object(forKey key: String) -> Any? { values[key] }

    func set(_ value: Any?, forKey key: String) {
        values[key] = value
    }
}
