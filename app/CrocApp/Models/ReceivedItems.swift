import Foundation
import OSLog

/// One top-level item a completed receive wrote, as the result screen lists it
/// (docs/knowledge/app-ui-architecture.md → System surfaces).
nonisolated struct ReceivedItem: Hashable, Identifiable, Sendable {
    let url: URL
    let isFolder: Bool
    /// nil for a folder, or when the file system does not say.
    let size: Int64?

    var id: URL { url }
}

/// Finds what a receive wrote, from the names the sender offered. Off the main
/// actor: it lists the receive folder, which can be large or on a slow volume.
nonisolated enum ReceivedItems {
    private static let log = Logger(subsystem: "com.bakirgdev.CrocApp", category: "received")

    /// The top-level items of `names` (paths relative to `folder`), in the
    /// order offered: a folder once for every name inside it, a file at the
    /// name it was saved under. Keep Both saves a taken name as
    /// "name (n).ext" (`ReceivedFileLocator.keepBothOriginal`), so a file
    /// resolves as `ReceivedFileLocator` resolves one: the newest such copy created since `since`, else the name itself.
    /// An item that is not there is left out.
    static func locate(names: [String], in folder: URL, since: Date) -> [ReceivedItem] {
        var tops: [String] = []
        var seen: Set<String> = []
        var folders: Set<String> = []
        for name in names {
            let parts = name.split(separator: "/", maxSplits: 1)
            guard let first = parts.first else { continue }
            let top = String(first)
            if seen.insert(top).inserted { tops.append(top) }
            if parts.count > 1 { folders.insert(top) }
        }

        let entries: [URL]
        do {
            entries = try FileManager.default.contentsOfDirectory(
                at: folder, includingPropertiesForKeys: [.creationDateKey, .fileSizeKey])
        } catch {
            log.error(
                "receive folder unreadable: \(String(describing: error), privacy: .public)")
            return []
        }
        var byName: [String: URL] = [:]
        var copiesByName: [String: [URL]] = [:]
        for entry in entries {
            byName[entry.lastPathComponent] = entry
            if let original = ReceivedFileLocator.keepBothOriginal(of: entry.lastPathComponent) {
                copiesByName[original, default: []].append(entry)
            }
        }

        return tops.compactMap { top in
            if folders.contains(top) {
                return byName[top].map { ReceivedItem(url: $0, isFolder: true, size: nil) }
            }
            // A file the sender offered under its own name is not a copy of
            // another one ("a.txt" and "a (1).txt" can both be offered).
            let copies = (copiesByName[top] ?? []).filter { !seen.contains($0.lastPathComponent) }
            let created = (copies + [byName[top]].compactMap { $0 }).filter {
                creation($0) >= since
            }
            guard let url = created.max(by: { creation($0) < creation($1) }) ?? byName[top]
            else { return nil }
            let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize).map(Int64.init)
            return ReceivedItem(url: url, isFolder: false, size: size)
        }
    }

    private static func creation(_ url: URL) -> Date {
        (try? url.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
    }
}
