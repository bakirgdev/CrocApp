import Foundation
import Observation

// Reads files staged by the CrocShare extension out of the App Group
// container. macOS has no share extension and no app group entitlement —
// containerURL returns nil there and everything degrades to a no-op.
@MainActor
@Observable
final class ShareInbox {
    static let groupID = "group.com.bakirgdev.CrocApp"

    private(set) var staged: [URL] = []

    private struct Manifest: Codable {
        var batch: String
        var files: [String]
    }

    private var inboxDir: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: Self.groupID)?
            .appendingPathComponent("ShareInbox", isDirectory: true)
    }

    func refresh() {
        guard let inbox = inboxDir else { return }
        purgeStaleBatches()
        let manifestURL = inbox.appendingPathComponent("manifest.json")
        guard let data = try? Data(contentsOf: manifestURL),
            let manifest = try? JSONDecoder().decode(Manifest.self, from: data)
        else {
            staged = []
            return
        }
        let batchDir = inbox.appendingPathComponent(manifest.batch, isDirectory: true)
        staged = manifest.files
            .map { batchDir.appendingPathComponent($0) }
            .filter { FileManager.default.fileExists(atPath: $0.path) }
    }

    // Called when the user decides (send or discard): the prompt must not
    // re-appear, but batch files stay on disk — croc reads them mid-transfer.
    func consumeManifest() {
        guard let inbox = inboxDir else { return }
        try? FileManager.default.removeItem(at: inbox.appendingPathComponent("manifest.json"))
    }

    // Sweep batches no manifest points to (previous sends, discards).
    func purgeStaleBatches() {
        guard let inbox = inboxDir else { return }
        let manifestURL = inbox.appendingPathComponent("manifest.json")
        var liveBatch: String?
        if let data = try? Data(contentsOf: manifestURL),
            let manifest = try? JSONDecoder().decode(Manifest.self, from: data)
        {
            liveBatch = manifest.batch
        }
        let contents =
            (try? FileManager.default.contentsOfDirectory(
                at: inbox, includingPropertiesForKeys: nil)) ?? []
        for url in contents where url.hasDirectoryPath && url.lastPathComponent != liveBatch {
            // Never delete the batch backing an active send.
            if !staged.isEmpty, staged[0].deletingLastPathComponent() == url { continue }
            try? FileManager.default.removeItem(at: url)
        }
    }
}
