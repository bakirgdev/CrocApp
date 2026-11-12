import Foundation
import os

/// Security-scoped bookmark create/resolve, shared by TransferController's
/// send bookmarks and OutputFolderStore's output-folder bookmark. macOS needs
/// `.withSecurityScope` to survive re-launch across the sandbox boundary;
/// other platforms use plain bookmarks (fileImporter URLs are implicitly
/// provider-scoped there).
enum SecurityScopedBookmark {
    nonisolated private static let log = Logger(
        subsystem: "com.bakirgdev.CrocApp", category: "bookmark")

    /// Create a bookmark for `url`. Callers are expected to already hold the
    /// security scope (via `startAccessingSecurityScopedResource()`) before
    /// calling this, same as reading any other attribute under sandbox.
    ///
    /// `nonisolated` so TransferController can batch up to 200 of these off the
    /// main actor. `URL.bookmarkData` touches no shared mutable state.
    nonisolated static func create(for url: URL) -> Data? {
        do {
            #if os(macOS)
            return try url.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil, relativeTo: nil)
            #else
            return try url.bookmarkData()
            #endif
        } catch {
            logFailure("create", error)
            return nil
        }
    }

    /// Resolve a stored bookmark, or nil when it no longer resolves. A stale
    /// bookmark still resolved (the folder moved or its volume remounted):
    /// the URL is good, and the caller should re-create the bookmark from it
    /// while holding its scope.
    static func resolve(_ data: Data) -> (url: URL, isStale: Bool)? {
        var isStale = false
        do {
            #if os(macOS)
            let url = try URL(
                resolvingBookmarkData: data,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale)
            #else
            let url = try URL(
                resolvingBookmarkData: data,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale)
            #endif
            return (url, isStale)
        } catch {
            logFailure("resolve", error)
            return nil
        }
    }

    // The domain and code only: the error's description can carry the path.
    nonisolated private static func logFailure(_ step: StaticString, _ error: any Error) {
        let error = error as NSError
        log.error(
            "bookmark \(step, privacy: .public) failed: \(error.domain, privacy: .public) \(error.code, privacy: .public)"
        )
    }

    /// Resolve, then confirm the target still exists on disk. The sandbox
    /// denies `stat` on an unopened scope, so the scope must be started
    /// before `fileExists`/attribute reads -- each platform's omission of
    /// this ordering was a separately caught defect.
    /// A stale bookmark counts as gone here: History has no record to refresh it in.
    static func resolveIfReachable(_ data: Data) -> URL? {
        guard let (url, isStale) = resolve(data), !isStale else { return nil }
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }
}
