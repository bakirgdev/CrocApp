import Foundation

/// What the CrocShare extension and the app agree on: where a shared batch
/// lands in the App Group container and what its manifest says. The
/// extension writes (`ShareStager`), the app reads (`ShareInbox`).
///
/// Each share is one `batch-<UUID>` directory in the inbox: the staged files,
/// then `manifest.json` beside them. The manifest is written last, so a batch
/// with one is complete, and a second share never replaces a first.
///
/// This one file is compiled into the app, CrocApp Direct and CrocShare, so a
/// name cannot drift between the writer and the reader. The group ID also sits
/// in the `.entitlements` files, which cannot import Swift: a change here needs
/// the same change there.
enum ShareHandoff {
    // macOS uses the team-prefixed form, which needs no provisioning profile
    // (a `group.` ID on a Developer ID build would need one for CrocShare too).
    // The Direct build has its own group, so a Direct and an App Store copy
    // on one Mac never read each other's inbox.
    #if os(macOS) && DIRECT
    static let groupID = "HBSU359M33.com.bakirgdev.CrocApp.direct"
    #elseif os(macOS)
    static let groupID = "HBSU359M33.com.bakirgdev.CrocApp"
    #else
    static let groupID = "group.com.bakirgdev.CrocApp"
    #endif
    static let inboxDirName = "ShareInbox"
    nonisolated static let manifestName = "manifest.json"
    private static let batchPrefix = "batch-"
    /// Characters in the canonical `UUID.uuidString` form (8-4-4-4-12).
    private static let uuidLength = 36

    /// The most shared text a batch carries, in UTF-8 bytes. The Send screen's
    /// editor is not built for more, and the extension must stay small.
    static let maxTextBytes = 1_048_576

    /// Lists one staged batch, inside its directory. `text` is shared text or
    /// links, set only when `files` is empty. It lives in the manifest so that
    /// deleting the batch deletes it.
    struct Manifest: Codable {
        var files: [String]
        var text: String?
    }

    /// Non-blank parts joined one per line, or nil when nothing is left.
    nonisolated static func joinText(_ parts: [String]) -> String? {
        let kept = parts.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        return kept.isEmpty ? nil : kept.joined(separator: "\n")
    }

    /// The inbox directory, or nil where the App Group container is
    /// unavailable.
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
    /// on every directory name it lists before using it, because the inbox is
    /// in the App Group container, which the app does not own alone.
    static func isValidBatchName(_ name: String) -> Bool {
        let utf8 = name.utf8
        guard utf8.starts(with: batchPrefix.utf8) else { return false }
        let tail = utf8.dropFirst(batchPrefix.utf8.count)
        // The exact length matters: `UUID(uuidString:)` also accepts a UUID
        // followed by a NUL, which would pass for a name that is not one.
        guard tail.count == uuidLength else { return false }
        return UUID(uuidString: String(decoding: tail, as: UTF8.self)) != nil
    }

    static func manifestURL(inBatch batchDir: URL) -> URL {
        batchDir.appendingPathComponent(manifestName)
    }

    // MARK: - Staging rules

    // The extension's decisions, kept here because tests cannot import an
    // extension target.

    /// The name a shared file stages under. A name `ReceivedName` rejects, or
    /// a hidden one, becomes `shared-file`, because the app drops such names
    /// when it reads the manifest. A taken name, or the manifest's own in any
    /// case (a Mac volume is case-insensitive), gets a `2-`, `3-` prefix.
    nonisolated static func stagedName(for name: String, isTaken: (String) -> Bool) -> String {
        let base = name.hasPrefix(".") || ReceivedName.isUnsafe(name) ? "shared-file" : name
        var candidate = base
        var counter = 2
        while candidate.lowercased() == manifestName || isTaken(candidate) {
            candidate = "\(counter)-\(base)"
            counter += 1
        }
        return candidate
    }

    /// The text a batch carries: none when it has files, because a batch is
    /// either files or text and the files are the heavier thing to lose.
    nonisolated static func batchText(fileCount: Int, texts: [String]) -> String? {
        fileCount == 0 ? joinText(texts) : nil
    }

    /// Whether a copy of `needed` bytes fits. A source on the batch's own
    /// volume is assumed to clone, so it always fits and `needed` (a folder
    /// walk) never runs. An unknown free space does not block the copy.
    nonisolated static func copyFits(sameVolume: Bool, free: Int64?, needed: () -> Int64) -> Bool {
        // shortcut: a same-volume source is assumed to clone, which only APFS does.
        // Check the space there too if a non-APFS volume ever matters.
        if sameVolume { return true }
        guard let free else { return true }
        return needed() <= free
    }
}
