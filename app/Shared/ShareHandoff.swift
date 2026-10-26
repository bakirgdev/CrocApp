import Foundation

/// What the CrocShare extension and the app agree on: where a shared batch
/// lands in the App Group container and how the manifest names it. The
/// extension writes (`ShareStager`), the app reads (`ShareInbox`).
///
/// This one file is compiled into the app, CrocApp Direct and CrocShare, so a
/// name cannot drift between the writer and the reader. The group ID also sits
/// in the three `.entitlements` files, which cannot import Swift: a change
/// here needs the same change there.
enum ShareHandoff {
    static let groupID = "group.com.bakirgdev.CrocApp"
    static let inboxDirName = "ShareInbox"
    static let manifestName = "manifest.json"
    private static let batchPrefix = "batch-"
    /// Characters in the canonical `UUID.uuidString` form (8-4-4-4-12).
    private static let uuidLength = 36

    /// Names one staged batch. The extension writes it after the batch's files
    /// are in place, so a manifest on disk always points at a complete batch.
    struct Manifest: Codable {
        var batch: String
        var files: [String]
    }

    /// The inbox directory, or nil where the App Group container is
    /// unavailable (macOS has no share extension and no group entitlement).
    static var inboxURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: groupID)?
            .appendingPathComponent(inboxDirName, isDirectory: true)
    }

    /// A fresh batch directory name: `batch-` and a UUID.
    static func makeBatchName() -> String {
        batchPrefix + UUID().uuidString
    }

    /// True only for the shape `makeBatchName` produces. The reader checks it
    /// before joining `Manifest.batch` to a path, because a manifest is data
    /// read out of the App Group container, not something the app wrote.
    static func isValidBatchName(_ name: String) -> Bool {
        let utf8 = name.utf8
        guard utf8.starts(with: batchPrefix.utf8) else { return false }
        let tail = utf8.dropFirst(batchPrefix.utf8.count)
        // The exact length matters: `UUID(uuidString:)` also accepts a UUID
        // followed by a NUL, which would pass for a name that is not one.
        guard tail.count == uuidLength else { return false }
        return UUID(uuidString: String(decoding: tail, as: UTF8.self)) != nil
    }

    static func manifestURL(in inbox: URL) -> URL {
        inbox.appendingPathComponent(manifestName)
    }
}
