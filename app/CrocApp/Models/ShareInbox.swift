import Foundation
import OSLog
import Observation

// Reads files staged by the CrocShare extension out of the App Group
// container (the contract is in Shared/ShareHandoff.swift). Where the
// container is unavailable (an unsigned build) containerURL returns nil and
// everything degrades to a no-op.
@MainActor
@Observable
final class ShareInbox {
    private static let log = Logger(subsystem: "com.bakirgdev.CrocApp", category: "share")

    private(set) var staged: [URL] = []

    func refresh() {
        guard let inbox = ShareHandoff.inboxURL else { return }
        refresh(in: inbox)
    }

    // Split out so tests can point it at a temp directory instead of the
    // App Group container.
    func refresh(in inbox: URL) {
        let manifest = readManifest(in: inbox)
        purgeStaleBatches(in: inbox, keeping: manifest?.batch)
        guard let manifest else {
            staged = []
            return
        }
        let batchDir = inbox.appendingPathComponent(manifest.batch, isDirectory: true)
        // The App Group container is a trust boundary: the manifest is data
        // read out of it, not something this process wrote, so validate
        // names the same way an incoming transfer's file list is validated.
        staged = manifest.files
            .filter { !ReceivedName.isUnsafe($0) }
            .map { batchDir.appendingPathComponent($0) }
            .filter { FileManager.default.fileExists(atPath: $0.path) }
    }

    // Called when the user decides (send or discard): the prompt must not
    // re-appear, but batch files stay on disk — croc reads them mid-transfer.
    func consumeManifest() {
        guard let inbox = ShareHandoff.inboxURL else { return }
        remove(ShareHandoff.manifestURL(in: inbox), what: "manifest")
    }

    // Sweep batches no manifest points to (previous sends, discards).
    private func purgeStaleBatches(in inbox: URL, keeping liveBatch: String?) {
        let contents: [URL]
        do {
            contents = try FileManager.default.contentsOfDirectory(
                at: inbox, includingPropertiesForKeys: nil)
        } catch {
            // No inbox yet (nothing was ever shared) is not a failure.
            if (error as? CocoaError)?.code != .fileReadNoSuchFile {
                Self.log.error(
                    "share inbox listing failed: \(String(describing: error), privacy: .public)")
            }
            return
        }
        for url in contents where url.hasDirectoryPath && url.lastPathComponent != liveBatch {
            // Never delete the batch backing an active send.
            if !staged.isEmpty, staged[0].deletingLastPathComponent() == url { continue }
            remove(url, what: "stale batch")
        }
    }

    /// nil when there is no manifest. A manifest that exists but cannot be
    /// read or decoded, or whose batch name is not one `ShareStager` writes,
    /// is logged, then treated as absent: its batch is never joined to a path.
    private func readManifest(in inbox: URL) -> ShareHandoff.Manifest? {
        let url = ShareHandoff.manifestURL(in: inbox)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let manifest: ShareHandoff.Manifest
        do {
            manifest = try JSONDecoder().decode(
                ShareHandoff.Manifest.self, from: Data(contentsOf: url))
        } catch {
            Self.log.error(
                "share manifest unreadable: \(String(describing: error), privacy: .public)")
            return nil
        }
        guard ShareHandoff.isValidBatchName(manifest.batch) else {
            Self.log.error(
                "share manifest names an invalid batch: \(manifest.batch, privacy: .private)")
            return nil
        }
        return manifest
    }

    /// Best effort: a leftover file costs disk space or re-offers a share
    /// prompt, so a failure is logged and the app carries on.
    private func remove(_ url: URL, what: String) {
        do {
            try FileManager.default.removeItem(at: url)
        } catch {
            if (error as? CocoaError)?.code == .fileNoSuchFile { return }
            Self.log.error(
                "share inbox \(what, privacy: .public) removal failed: \(String(describing: error), privacy: .public)"
            )
        }
    }
}
