import Foundation

/// Sizes for the share handoff: the extension checks free space with it, and
/// the staged-files sheet lists it. Folders are walked, so callers keep it off
/// the main actor.
enum FileSize {
    /// A file's size, or the sum of a folder's files.
    nonisolated static func bytes(of url: URL) -> Int64 {
        let keys: [URLResourceKey] = [.fileSizeKey]
        func fileSize(_ url: URL) -> Int64 {
            (try? url.resourceValues(forKeys: Set(keys)).fileSize).map(Int64.init) ?? 0
        }
        guard url.hasDirectoryPath,
            let walk = FileManager.default.enumerator(at: url, includingPropertiesForKeys: keys)
        else { return fileSize(url) }
        return walk.compactMap { $0 as? URL }.reduce(0) { $0 + fileSize($1) }
    }

    @concurrent static func bytes(ofEach urls: [URL]) async -> [URL: Int64] {
        Dictionary(uniqueKeysWithValues: urls.map { ($0, bytes(of: $0)) })
    }
}
