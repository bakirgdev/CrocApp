import Foundation
import OSLog
import Observation

/// A custom code phrase the user chose to keep for one peer.
struct SavedCode: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var code: String

    /// Whether the trimmed name and code could be saved.
    static func isValid(name: String, code: String) -> Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && code.trimmingCharacters(in: .whitespacesAndNewlines).count
                >= EngineConstraints.minCodeLength
    }
}

/// Code phrases the user saved by hand, kept only in the Keychain (this
/// device, never synced): a code is a secret, so it never reaches
/// `UserDefaults`, History, logs or notifications. All codes share one item as
/// a JSON array, because `SecretStore` cannot list accounts. Nothing is added
/// except by `save`, which only the Settings editor calls.
@MainActor
@Observable
final class SavedCodes {
    private static let account = "savedCodes"
    private static let log = Logger(subsystem: "com.bakirgdev.CrocApp", category: "savedCodes")

    @ObservationIgnored private let secrets: any SecretStore
    /// Sorted by name.
    private(set) var codes: [SavedCode]
    /// The last write to the Keychain failed. The change stays for this launch
    /// only, and the next launch reads what the Keychain still holds.
    private(set) var saveFailed = false

    /// The Keychain could not be read, so `codes` is not what is stored.
    /// Writes are blocked until `reload()` succeeds: a save now would replace
    /// the stored codes with an incomplete list.
    private(set) var loadFailed = false

    init(secrets: any SecretStore = KeychainStore()) {
        self.secrets = secrets
        codes = []
        reload()
    }

    /// Reads the stored codes again. Called by init and by Try Again.
    func reload() {
        do {
            codes = try Self.load(from: secrets)
            loadFailed = false
        } catch {
            Self.log.error("saved codes could not be read from the Keychain")
            loadFailed = true
        }
    }

    func contains(code: String) -> Bool {
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
        return codes.contains { $0.code == trimmed }
    }

    /// Adds `code`, or replaces the saved code with the same `id`. A name or
    /// code that `SavedCode.isValid` refuses is ignored.
    func save(_ code: SavedCode) {
        if loadFailed { reload() }
        guard !loadFailed else { return }
        var code = code
        code.name = code.name.trimmingCharacters(in: .whitespacesAndNewlines)
        code.code = code.code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard SavedCode.isValid(name: code.name, code: code.code) else { return }
        codes.removeAll { $0.id == code.id }
        codes.append(code)
        codes.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        persist("save")
    }

    func remove(id: SavedCode.ID) {
        if loadFailed { reload() }
        guard !loadFailed else { return }
        guard codes.contains(where: { $0.id == id }) else { return }
        codes.removeAll { $0.id == id }
        persist("remove")
    }

    private func persist(_ operation: String) {
        if codes.isEmpty {
            saveFailed = !secrets.delete(account: Self.account)
        } else {
            do {
                let data = try JSONEncoder().encode(codes)
                saveFailed = !secrets.set(
                    String(decoding: data, as: UTF8.self), account: Self.account)
            } catch {
                // The error text could quote nothing secret, but stay generic anyway.
                Self.log.error("saved codes \(operation, privacy: .public) encode failed")
                saveFailed = true
            }
        }
        if saveFailed {
            Self.log.error("saved codes \(operation, privacy: .public) not saved to the Keychain")
        }
    }

    /// A Keychain read failure throws. An item that is there but not valid
    /// JSON is logged and treated as empty; the next write replaces it.
    private static func load(from secrets: any SecretStore) throws -> [SavedCode] {
        guard let json = try secrets.load(account: account) else { return [] }
        do {
            return try JSONDecoder().decode([SavedCode].self, from: Data(json.utf8))
        } catch {
            log.error("saved codes unreadable, starting empty")
            return []
        }
    }
}
