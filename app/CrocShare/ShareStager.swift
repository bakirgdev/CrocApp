import Foundation
import UniformTypeIdentifiers

enum ShareStagerError: LocalizedError {
    case noAppGroup
    case nothingUsable
    case notEnoughSpace
    case textTooLong

    var errorDescription: String? {
        switch self {
        case .noAppGroup: String(localized: "App Group container unavailable.")
        case .nothingUsable: String(localized: "Nothing shareable was provided.")
        case .notEnoughSpace: String(localized: "Not enough free space to prepare these files.")
        case .textTooLong: String(localized: "That text is too long to send this way.")
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
        var texts: [String] = []
        for item in items {
            for provider in item.attachments ?? [] {
                if let text = try await loadText(provider) {
                    texts.append(text)
                } else if provider.hasItemConformingToTypeIdentifier(Self.sourceType.identifier) {
                    names.append(try await stage(provider, into: batchDir, taken: names))
                }
            }
        }
        let text = ShareHandoff.batchText(fileCount: names.count, texts: texts)
        guard !names.isEmpty || text != nil else { throw ShareStagerError.nothingUsable }
        if let text, text.utf8.count > ShareHandoff.maxTextBytes {
            throw ShareStagerError.textTooLong
        }

        let manifest = ShareHandoff.Manifest(files: names, text: text)
        let data = try JSONEncoder().encode(manifest)
        try data.write(to: ShareHandoff.manifestURL(inBatch: batchDir), options: .atomic)
        return manifest
    }

    /// A web URL as its absolute string, or plain text as is. Nil for a file,
    /// including a text file: those stage as files.
    private static func loadText(_ provider: NSItemProvider) async throws -> String? {
        guard !provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier),
            let type = [UTType.url, .plainText].first(where: {
                provider.hasItemConformingToTypeIdentifier($0.identifier)
            })
        else { return nil }
        return try await withCheckedThrowingContinuation { cont in
            provider.loadItem(forTypeIdentifier: type.identifier) { item, error in
                switch item {
                case let url as URL:
                    cont.resume(returning: url.isFileURL ? nil : url.absoluteString)
                case let text as String: cont.resume(returning: text)
                // File-backed text arrives as Data or a file URL; it stages as a file.
                default:
                    if let error {
                        cont.resume(throwing: error)
                    } else {
                        cont.resume(returning: nil)
                    }
                }
            }
        }
    }

    #if os(macOS)
    // Finder hands over file URLs, and a folder conforms to `public.item` but
    // not `public.data`. Loading the URL, not a file representation, skips the
    // system's own temp copy. On the same APFS volume (the usual case)
    // `copyItem` then clones, so a large folder costs no extra disk; a source
    // on another volume is a full copy, so the free space is checked first.
    // Bookmarks cannot replace the copy: a bookmark made here does not resolve
    // in the app, which is another process.
    nonisolated private static let sourceType = UTType.fileURL

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
        return try await stageFile(url, into: dir, taken: taken)
    }

    // @concurrent: a folder copy must not run on the main actor.
    @concurrent private static func stageFile(
        _ url: URL, into dir: URL, taken: [String]
    ) async throws -> String {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        try Task.checkCancellation()
        try checkSpace(for: url, in: dir)
        return try copy(url, into: dir, taken: taken)
    }

    nonisolated private static func checkSpace(for url: URL, in dir: URL) throws {
        let source = try url.resourceValues(forKeys: [.volumeIdentifierKey])
        let target = try dir.resourceValues(forKeys: [
            .volumeIdentifierKey, .volumeAvailableCapacityForImportantUsageKey,
        ])
        var sameVolume = false
        if let a = source.volumeIdentifier, let b = target.volumeIdentifier {
            sameVolume = a.isEqual(b)
        }
        guard
            ShareHandoff.copyFits(
                sameVolume: sameVolume, free: target.volumeAvailableCapacityForImportantUsage,
                needed: { FileSize.bytes(of: url) })
        else { throw ShareStagerError.notEnoughSpace }
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
        let candidate = ShareHandoff.stagedName(for: url.lastPathComponent) {
            taken.contains($0)
                || FileManager.default.fileExists(atPath: dir.appendingPathComponent($0).path)
        }
        try FileManager.default.copyItem(at: url, to: dir.appendingPathComponent(candidate))
        return candidate
    }
}
