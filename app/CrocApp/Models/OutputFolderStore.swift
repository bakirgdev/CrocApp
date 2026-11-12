import Foundation
import Observation

/// Receive destination folder. Default: app Documents on iOS,
/// Downloads/CrocApp on macOS. User override persists
/// via bookmark: security-scoped on macOS, plain on iOS (fileImporter URLs
/// are implicitly provider-scoped there; .withSecurityScope is macOS-only).
@MainActor
@Observable
final class OutputFolderStore {
    private static let bookmarkKey = "outputFolderBookmark"

    private let defaults: UserDefaults
    private(set) var url: URL
    private(set) var isUserSelected: Bool
    /// True when a stored bookmark existed but failed to resolve (the folder
    /// was deleted, or its drive or share is gone) and the store fell back to
    /// `defaultFolder`. Settings shows it for this launch only: the key is
    /// cleared, so the next launch starts quietly on the default.
    private(set) var bookmarkWasReset = false

    static var defaultFolder: URL {
        #if os(macOS)
        // Real ~/Downloads via the downloads.read-write entitlement; a
        // CrocApp subfolder keeps received batches from littering Downloads.
        let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)[0]
        let folder = downloads.appendingPathComponent("CrocApp", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        // This is a static computed property (called with no instance in
        // scope), so there's nowhere to hang a bookmarkWasReset-style flag --
        // fall back to a directory that is actually guaranteed to exist
        // instead, rather than handing the engine a path that a receive
        // would then fail against opaquely.
        var isDirectory: ObjCBool = false
        let created = FileManager.default.fileExists(atPath: folder.path, isDirectory: &isDirectory)
        return created && isDirectory.boolValue ? folder : downloads
        #else
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        #endif
    }

    var defaultDisplayName: String {
        #if os(macOS)
        // The system's own name for the folder, so it follows the language.
        let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)[0]
        return "\(FileManager.default.displayName(atPath: downloads.path))/CrocApp"
        #else
        return String(
            localized: "Documents",
            comment: "The folder received files go to by default on iPhone and iPad.")
        #endif
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        guard let data = defaults.data(forKey: Self.bookmarkKey) else {
            url = Self.defaultFolder
            isUserSelected = false
            return
        }
        if let (resolved, isStale) = SecurityScopedBookmark.resolve(data) {
            url = resolved
            isUserSelected = true
            if isStale { refreshBookmark(for: resolved) }
        } else {
            // Dangling bookmark: clear the key so this fallback doesn't
            // silently repeat on every launch with stored state (isUserSelected)
            // disagreeing with what's actually on UserDefaults.
            defaults.removeObject(forKey: Self.bookmarkKey)
            url = Self.defaultFolder
            isUserSelected = false
            bookmarkWasReset = true
        }
    }

    /// A stale bookmark still resolved; a new one from the resolved URL stops it
    /// going stale for good. If that fails the old one is kept, as it still resolves.
    private func refreshBookmark(for resolved: URL) {
        let scoped = resolved.startAccessingSecurityScopedResource()
        defer { if scoped { resolved.stopAccessingSecurityScopedResource() } }
        guard let data = SecurityScopedBookmark.create(for: resolved) else { return }
        defaults.set(data, forKey: Self.bookmarkKey)
    }

    func select(_ picked: URL) {
        let hadAccess = picked.startAccessingSecurityScopedResource()
        defer { if hadAccess { picked.stopAccessingSecurityScopedResource() } }
        // Silently no-ops on failure (accepted papercut, docs/known-issues.md):
        // rare, and the alternative is an error path the user cannot act on.
        guard let data = SecurityScopedBookmark.create(for: picked) else { return }
        defaults.set(data, forKey: Self.bookmarkKey)
        url = picked
        isUserSelected = true
        bookmarkWasReset = false
    }

    func resetToDefault() {
        defaults.removeObject(forKey: Self.bookmarkKey)
        url = Self.defaultFolder
        isUserSelected = false
        bookmarkWasReset = false
    }
}
