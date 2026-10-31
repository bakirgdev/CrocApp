import Foundation

/// The last finished transfer, as the widget may show it. The app writes it
/// into the App Group container and the widget reads it, so it holds only what
/// is safe on a locked screen: never a code phrase, a link or a stored-link
/// key, and a file name only when the user turned that on.
///
/// Compiled into the app, CrocApp Direct and the widget extensions.
struct TransferSnapshot: Codable, Equatable {
    enum Direction: String, Codable { case send, receive }
    enum Outcome: String, Codable { case done, failed, stopped }

    var direction: Direction
    var outcome: Outcome
    /// How many items the transfer offered; 0 when unknown.
    var itemCount: Int
    /// Set only for a single item and only with the file-names switch on.
    var name: String?
    var date: Date

    /// Drops the name, for when the user turns the switch off.
    var withoutName: TransferSnapshot {
        var copy = self
        copy.name = nil
        return copy
    }

    /// Keeps `names` only for exactly one item and `showNames`.
    static func name(from names: [String], showNames: Bool) -> String? {
        // A name the app refuses to write (ReceivedName) is not shown either.
        showNames && names.count == 1 && !ReceivedName.isUnsafe(names[0]) ? names[0] : nil
    }
}

/// Reads and writes the snapshot file in a directory (the App Group container
/// in the app; a temporary directory in tests).
struct TransferSnapshotStore {
    static let fileName = "last-transfer.json"
    let directory: URL

    /// The store in the App Group container, or nil where it is unavailable.
    static var shared: TransferSnapshotStore? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: ShareHandoff.groupID)
            .map(TransferSnapshotStore.init)
    }

    private var url: URL { directory.appendingPathComponent(Self.fileName) }

    func read() -> TransferSnapshot? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(TransferSnapshot.self, from: data)
    }

    func write(_ snapshot: TransferSnapshot) throws {
        try JSONEncoder().encode(snapshot).write(to: url, options: .atomic)
    }

    func clear() throws {
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        try FileManager.default.removeItem(at: url)
    }
}
