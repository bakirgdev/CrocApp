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

    /// How long a batch without a manifest is left alone: the extension may
    /// still be copying into it.
    static let stagingGrace: TimeInterval = 60 * 60
    /// The clock the purge reads. Tests move it past `stagingGrace`.
    @ObservationIgnored var now: () -> Date = Date.init

    /// The batch `staged` or `text` comes from: the oldest one with a manifest.
    private(set) var batch: String?
    private(set) var staged: [URL] = []
    /// Shared text or links from the manifest, kept out of logs. Only set when
    /// no file is staged.
    private(set) var text: String?
    /// A consumed batch whose send has not succeeded yet. Kept on disk for a
    /// retry, which reuses its file URLs.
    @ObservationIgnored private var sendingBatch: String?
    /// The directory the last refresh read; `batch` names a directory in it.
    @ObservationIgnored private var inbox: URL?

    func refresh() {
        guard let inbox = ShareHandoff.inboxURL else { return }
        refresh(in: inbox)
    }

    // Split out so tests can point it at a temp directory instead of the
    // App Group container.
    func refresh(in inbox: URL) {
        self.inbox = inbox
        let pending = purgeAndListPending(in: inbox)
        batch = nil
        staged = []
        text = nil
        for (name, manifest) in pending {
            let batchDir = inbox.appendingPathComponent(name, isDirectory: true)
            // The App Group container is a trust boundary: the manifest is data
            // read out of it, not something this process wrote, so validate
            // names the same way an incoming transfer's file list is validated.
            let files = manifest.files
                .filter { !ReceivedName.isUnsafe($0) }
                .map { batchDir.appendingPathComponent($0) }
                .filter { FileManager.default.fileExists(atPath: $0.path) }
            // Same boundary, same rule as the names: the cap is re-checked here.
            let text =
                files.isEmpty
                ? manifest.text.flatMap {
                    $0.utf8.count <= ShareHandoff.maxTextBytes ? ShareHandoff.joinText([$0]) : nil
                } : nil
            guard !files.isEmpty || text != nil else { continue }
            batch = name
            staged = files
            self.text = text
            return
        }
    }

    /// Called when the user sends the batch: the prompt must not re-appear,
    /// but the files stay on disk, because croc reads them mid-transfer and a
    /// retry reads them again.
    func consume(_ batch: String) {
        guard let inbox else { return }
        let batchDir = inbox.appendingPathComponent(batch, isDirectory: true)
        remove(ShareHandoff.manifestURL(inBatch: batchDir), what: "manifest")
        sendingBatch = batch
    }

    /// Called when the user discards the batch, or once its text is copied out.
    func discard(_ batch: String) {
        guard let inbox else { return }
        remove(inbox.appendingPathComponent(batch, isDirectory: true), what: "batch")
    }

    /// Called when a transfer ends with its result (`.done` or `.stored`).
    /// The sent batch is not needed again, so its copies go now instead of
    /// waiting for the purge.
    func sendFinished() {
        guard let sendingBatch else { return }
        self.sendingBatch = nil
        discard(sendingBatch)
    }

    /// Sweeps what no share needs (an old send, a batch that never got its
    /// manifest, a name the extension never writes) and returns the batches
    /// that have a manifest, oldest first.
    private func purgeAndListPending(in inbox: URL) -> [(String, ShareHandoff.Manifest)] {
        let contents: [URL]
        do {
            contents = try FileManager.default.contentsOfDirectory(
                at: inbox, includingPropertiesForKeys: [.creationDateKey])
        } catch {
            // No inbox yet (nothing was ever shared) is not a failure.
            if (error as? CocoaError)?.code != .fileReadNoSuchFile {
                Self.log.error(
                    "share inbox listing failed: \(String(describing: error), privacy: .public)")
            }
            return []
        }
        var pending: [(name: String, created: Date, manifest: ShareHandoff.Manifest)] = []
        for url in contents where url.hasDirectoryPath {
            let name = url.lastPathComponent
            let created =
                (try? url.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
            if ShareHandoff.isValidBatchName(name) {
                // Never delete the batch behind a send that may still run or be retried.
                if name == sendingBatch { continue }
                if let manifest = readManifest(in: url) {
                    pending.append((name, created, manifest))
                    continue
                }
            }
            // The extension writes the manifest only after copying, so a young
            // batch with no manifest may still be filling (a large Mac folder).
            if created > now().addingTimeInterval(-Self.stagingGrace) { continue }
            remove(url, what: "stale batch")
        }
        return pending.sorted { $0.created < $1.created }.map { ($0.name, $0.manifest) }
    }

    /// nil when the batch has no manifest. A manifest that exists but cannot be
    /// read or decoded is logged, then treated as absent.
    private func readManifest(in batchDir: URL) -> ShareHandoff.Manifest? {
        let url = ShareHandoff.manifestURL(inBatch: batchDir)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        do {
            return try JSONDecoder().decode(ShareHandoff.Manifest.self, from: Data(contentsOf: url))
        } catch {
            Self.log.error(
                "share manifest unreadable: \(String(describing: error), privacy: .public)")
            return nil
        }
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
