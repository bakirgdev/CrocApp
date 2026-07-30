import Foundation

/// Security-scoped bookmark create/resolve, shared by TransferController's
/// send bookmarks and OutputFolderStore's output-folder bookmark. macOS needs
/// `.withSecurityScope` to survive re-launch across the sandbox boundary;
/// other platforms use plain bookmarks (fileImporter URLs are implicitly
/// provider-scoped there).
enum SecurityScopedBookmark {
    /// Create a bookmark for `url`. Callers are expected to already hold the
    /// security scope (via `startAccessingSecurityScopedResource()`) before
    /// calling this, same as reading any other attribute under sandbox.
    ///
    /// `nonisolated` so TransferController can batch up to 200 of these off the
    /// main actor. `URL.bookmarkData` touches no shared mutable state.
    nonisolated static func create(for url: URL) -> Data? {
        #if os(macOS)
        try? url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil, relativeTo: nil)
        #else
        try? url.bookmarkData()
        #endif
    }

    /// Resolve a stored bookmark. Returns nil on failure or staleness --
    /// callers should treat a stale bookmark as "gone", not keep using a
    /// dangling reference.
    static func resolve(_ data: Data) -> URL? {
        var isStale = false
        #if os(macOS)
        let resolved = try? URL(
            resolvingBookmarkData: data,
            options: .withSecurityScope,
            relativeTo: nil,
            bookmarkDataIsStale: &isStale)
        #else
        let resolved = try? URL(
            resolvingBookmarkData: data,
            relativeTo: nil,
            bookmarkDataIsStale: &isStale)
        #endif
        return isStale ? nil : resolved
    }

    /// Resolve, then confirm the target still exists on disk. The sandbox
    /// denies `stat` on an unopened scope, so the scope must be started
    /// before `fileExists`/attribute reads -- each platform's omission of
    /// this ordering was a separately caught defect.
    static func resolveIfReachable(_ data: Data) -> URL? {
        guard let url = resolve(data) else { return nil }
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }
}
