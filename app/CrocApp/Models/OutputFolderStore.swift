import Foundation
import Observation

/// Receive destination folder (F7). Default: app Documents on iOS,
/// Downloads/CrocApp on macOS. User override persists
/// via bookmark: security-scoped on macOS, plain on iOS (fileImporter URLs
/// are implicitly provider-scoped there; .withSecurityScope is macOS-only).
@MainActor
@Observable
final class OutputFolderStore {
    private static let bookmarkKey = "outputFolderBookmark"

    private(set) var url: URL
    private(set) var isUserSelected: Bool
    /// True when a stored bookmark existed but failed to resolve (stale --
    /// external drive remounted elsewhere, network share, iCloud) and the
    /// store silently fell back to `defaultFolder`. Not surfaced in UI yet;
    /// a future settings screen could use this to tell the user their
    /// chosen folder reverted.
    private(set) var bookmarkWasReset = false

    static var defaultFolder: URL {
        #if os(macOS)
        // Real ~/Downloads via the downloads.read-write entitlement; a
        // CrocApp subfolder keeps received batches from littering Downloads.
        let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)[0]
        let folder = downloads.appendingPathComponent("CrocApp", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
        #else
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        #endif
    }

    var defaultDisplayName: String {
        #if os(macOS)
        "Downloads/CrocApp"
        #else
        "Documents"
        #endif
    }

    init() {
        guard let data = UserDefaults.standard.data(forKey: Self.bookmarkKey) else {
            url = Self.defaultFolder
            isUserSelected = false
            return
        }
        if let resolved = SecurityScopedBookmark.resolve(data) {
            url = resolved
            isUserSelected = true
        } else {
            // Dangling bookmark: clear the key so this fallback doesn't
            // silently repeat on every launch with stored state (isUserSelected)
            // disagreeing with what's actually on UserDefaults.
            UserDefaults.standard.removeObject(forKey: Self.bookmarkKey)
            url = Self.defaultFolder
            isUserSelected = false
            bookmarkWasReset = true
        }
    }

    func select(_ picked: URL) {
        let hadAccess = picked.startAccessingSecurityScopedResource()
        defer { if hadAccess { picked.stopAccessingSecurityScopedResource() } }
        // Silently no-ops on failure (accepted papercut, docs/known-issues.md):
        // rare, and the alternative is an error path the user cannot act on.
        guard let data = SecurityScopedBookmark.create(for: picked) else { return }
        UserDefaults.standard.set(data, forKey: Self.bookmarkKey)
        url = picked
        isUserSelected = true
        bookmarkWasReset = false
    }

    func resetToDefault() {
        UserDefaults.standard.removeObject(forKey: Self.bookmarkKey)
        url = Self.defaultFolder
        isUserSelected = false
        bookmarkWasReset = false
    }
}
