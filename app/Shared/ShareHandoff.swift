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
        name.hasPrefix(batchPrefix)
            && UUID(uuidString: String(name.dropFirst(batchPrefix.count))) != nil
    }

    static func manifestURL(in inbox: URL) -> URL {
        inbox.appendingPathComponent(manifestName)
    }
}
