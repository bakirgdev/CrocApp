import Foundation
import UniformTypeIdentifiers

enum ShareStagerError: LocalizedError {
    case noAppGroup
    case nothingUsable

    var errorDescription: String? {
        switch self {
        case .noAppGroup: String(localized: "App Group container unavailable.")
        case .nothingUsable: String(localized: "Nothing shareable was provided.")
        }
    }
}

enum ShareStager {
    // File-copy only; never read payload bytes into memory (share extensions
    // die around ~120 MB resident). The inbox layout and manifest are the
    // contract in Shared/ShareHandoff.swift.
    static func stage(items: [NSExtensionItem]) async throws -> ShareHandoff.Manifest {
        guard let inbox = ShareHandoff.inboxURL else {
            throw ShareStagerError.noAppGroup
        }
        // Never wipe the inbox here: a prior batch may be mid-send, with croc
        // actively reading its files. The main app's purgeStaleBatches()
        // sweeps orphaned batches once it's idle.
        let batchName = ShareHandoff.makeBatchName()
        let batchDir = inbox.appendingPathComponent(batchName, isDirectory: true)
        try FileManager.default.createDirectory(at: batchDir, withIntermediateDirectories: true)

        var names: [String] = []
        for item in items {
            for provider in item.attachments ?? [] {
                guard provider.hasItemConformingToTypeIdentifier(Self.sourceType.identifier) else {
                    continue
                }
                let name = try await stage(provider, into: batchDir, taken: names)
                names.append(name)
            }
        }
        guard !names.isEmpty else { throw ShareStagerError.nothingUsable }

        let manifest = ShareHandoff.Manifest(batch: batchName, files: names)
        let data = try JSONEncoder().encode(manifest)
        try data.write(to: ShareHandoff.manifestURL(in: inbox), options: .atomic)
        return manifest
    }

    #if os(macOS)
    // Finder hands over file URLs, and a folder conforms to `public.item` but
    // not `public.data`. Loading the URL, not a file representation, skips the
    // system's own temp copy; `copyItem` then clones on APFS, so a large
    // folder costs no extra disk or time. Bookmarks cannot replace the copy: a
    // bookmark made here does not resolve in the app, which is another process.
    private static let sourceType = UTType.fileURL

    private static func stage(
        _ provider: NSItemProvider, into dir: URL, taken: [String]
    ) async throws -> String {
        let url: URL = try await withCheckedThrowingContinuation { cont in
            provider.loadItem(forTypeIdentifier: sourceType.identifier) { item, error in
                switch item {
                case let url as URL: cont.resume(returning: url)
                case let data as Data:
                    if let url = URL(dataRepresentation: data, relativeTo: nil) {
                        cont.resume(returning: url)
                    } else {
                        cont.resume(throwing: ShareStagerError.nothingUsable)
                    }
                default: cont.resume(throwing: error ?? ShareStagerError.nothingUsable)
                }
            }
        }
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        return try copy(url, into: dir, taken: taken)
    }
    #else
    private static let sourceType = UTType.data

    private static func stage(
        _ provider: NSItemProvider, into dir: URL, taken: [String]
    ) async throws -> String {
        try await withCheckedThrowingContinuation { cont in
            provider.loadFileRepresentation(forTypeIdentifier: sourceType.identifier) {
                url, error in
                // The temp file at `url` is deleted when this handler returns:
                // the copy MUST happen synchronously here.
                guard let url else {
                    cont.resume(throwing: error ?? ShareStagerError.nothingUsable)
                    return
                }
                cont.resume(with: Result { try copy(url, into: dir, taken: taken) })
            }
        }
    }
    #endif

    nonisolated private static func copy(_ url: URL, into dir: URL, taken: [String]) throws
        -> String
    {
        // The app drops a name `ReceivedName` rejects when it reads
        // the manifest, so stage such a file under a safe name instead.
        var name = url.lastPathComponent
        if name.hasPrefix(".") || ReceivedName.isUnsafe(name) { name = "shared-file" }
        var candidate = name
        var counter = 2
        while taken.contains(candidate)
            || FileManager.default.fileExists(atPath: dir.appendingPathComponent(candidate).path)
        {
            candidate = "\(counter)-\(name)"
            counter += 1
        }
        try FileManager.default.copyItem(at: url, to: dir.appendingPathComponent(candidate))
        return candidate
    }
}
