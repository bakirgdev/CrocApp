import Foundation
import UniformTypeIdentifiers

enum ShareStagerError: LocalizedError {
    case noAppGroup
    case nothingUsable

    var errorDescription: String? {
        switch self {
        case .noAppGroup: "App Group container unavailable."
        case .nothingUsable: "Nothing shareable was provided."
        }
    }
}

enum ShareStager {
    static let groupID = "group.com.bakirgdev.CrocApp"

    struct Manifest: Codable {
        var batch: String
        var files: [String]
    }

    // File-copy only; never read payload bytes into memory (share extensions
    // die around ~120 MB resident).
    static func stage(items: [NSExtensionItem]) async throws -> Manifest {
        guard let container = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: groupID) else {
            throw ShareStagerError.noAppGroup
        }
        let inbox = container.appendingPathComponent("ShareInbox", isDirectory: true)
        // Wipe any stale batch — one staged hand-off at a time.
        try? FileManager.default.removeItem(at: inbox)
        let batchName = "batch-" + UUID().uuidString
        let batchDir = inbox.appendingPathComponent(batchName, isDirectory: true)
        try FileManager.default.createDirectory(at: batchDir, withIntermediateDirectories: true)

        var names: [String] = []
        for item in items {
            for provider in item.attachments ?? [] {
                guard provider.hasItemConformingToTypeIdentifier(UTType.data.identifier) else { continue }
                let name = try await copyFileRepresentation(of: provider, into: batchDir, taken: names)
                names.append(name)
            }
        }
        guard !names.isEmpty else { throw ShareStagerError.nothingUsable }

        let manifest = Manifest(batch: batchName, files: names)
        let data = try JSONEncoder().encode(manifest)
        try data.write(to: inbox.appendingPathComponent("manifest.json"), options: .atomic)
        return manifest
    }

    private static func copyFileRepresentation(
        of provider: NSItemProvider, into dir: URL, taken: [String]
    ) async throws -> String {
        try await withCheckedThrowingContinuation { cont in
            provider.loadFileRepresentation(forTypeIdentifier: UTType.data.identifier) { url, error in
                // The temp file at `url` is deleted when this handler returns:
                // the copy MUST happen synchronously here.
                guard let url else {
                    cont.resume(throwing: error ?? ShareStagerError.nothingUsable)
                    return
                }
                var name = url.lastPathComponent
                if name.isEmpty || name.hasPrefix(".") { name = "shared-file" }
                var candidate = name
                var counter = 2
                while taken.contains(candidate) ||
                      FileManager.default.fileExists(atPath: dir.appendingPathComponent(candidate).path) {
                    candidate = "\(counter)-\(name)"
                    counter += 1
                }
                do {
                    try FileManager.default.copyItem(at: url, to: dir.appendingPathComponent(candidate))
                    cont.resume(returning: candidate)
                } catch {
                    cont.resume(throwing: error)
                }
            }
        }
    }
}
