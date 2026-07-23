import Foundation
import Observation
import CrocKit

/// The app-side state machine over CrocEngine. Views render `phase` and call
/// the intent methods; nothing else in the app touches CrocKit directly.
@MainActor
@Observable
final class TransferController {
    enum Direction { case send, receive }

    enum Phase {
        case idle
        case starting
        case waiting(code: String)
        case connecting
        case incoming(FileList, conflicts: [String], blocked: [String])
        case transferring(TransferProgress)
        case done(Summary, receivedText: String?)
        case failed(String)
    }

    private(set) var phase: Phase = .idle
    private(set) var direction: Direction = .send
    private(set) var speedBytesPerSec: Double = 0

    var isActive: Bool {
        if case .idle = phase { return false }
        return true
    }

    private let engine = CrocEngine()
    private var streamTask: Task<Void, Never>?
    private var scopedURLs: [URL] = []
    private var cancelRequested = false
    private var declineRequested = false
    private var receivedText: String?
    private var outDir: URL?
    private var lastProgressBytes: Int64 = 0
    private var lastProgressDate: Date?

    // MARK: - Intents

    func startSend(urls: [URL], customCode: String) {
        guard !isActive else { return }
        direction = .send
        // startAccessing returns false for non-scoped URLs (e.g. some drops);
        // keep every path regardless, only track the ones needing release.
        scopedURLs = urls.filter { $0.startAccessingSecurityScopedResource() }
        let paths = urls.map(\.path)
        var options = EngineOptions()
        options.customCode = customCode
        options.workDir = FileManager.default.temporaryDirectory.path
        run { try await self.engine.startSend(paths: paths, text: nil, options: options) }
    }

    func startSendText(_ text: String, customCode: String) {
        guard !isActive else { return }
        direction = .send
        var options = EngineOptions()
        options.customCode = customCode
        options.workDir = FileManager.default.temporaryDirectory.path
        run { try await self.engine.startSend(paths: [], text: text, options: options) }
    }

    func startReceive(code: String, into folder: URL, folderIsScoped: Bool) {
        guard !isActive else { return }
        direction = .receive
        outDir = folder
        if folderIsScoped, folder.startAccessingSecurityScopedResource() {
            scopedURLs.append(folder)
        }
        var options = EngineOptions()
        options.outDir = folder.path
        // Conflicts are surfaced in the incoming sheet before accept; from
        // there "Accept" means replace (croc resumes partial files itself).
        options.overwrite = true
        run { try await self.engine.startReceive(code: code, options: options) }
    }

    /// Answer the accept/decline prompt raised by `.incoming`.
    func respond(accept: Bool) {
        Task { await engine.respond(accept: accept) }
        if accept {
            phase = .connecting
        } else {
            declineRequested = true
        }
        // Decline: croc notifies the sender (SendError path) and the session
        // ends with a failed/done event; phase advances from the stream.
    }

    func cancel() {
        cancelRequested = true
        Task { await engine.cancel() }
    }

    /// Back to idle. Only meaningful from terminal phases; the stream has
    /// already finished there, so cancelling streamTask is a no-op safety.
    func reset() {
        streamTask?.cancel()
        streamTask = nil
        releaseScopedURLs()
        receivedText = nil
        outDir = nil
        speedBytesPerSec = 0
        phase = .idle
    }

    // MARK: - Engine plumbing

    private func run(_ start: @escaping () async throws -> AsyncStream<TransferEvent>) {
        phase = .starting
        cancelRequested = false
        declineRequested = false
        receivedText = nil
        speedBytesPerSec = 0
        lastProgressDate = nil
        lastProgressBytes = 0
        streamTask = Task {
            do {
                var stream: AsyncStream<TransferEvent>
                do {
                    stream = try await start()
                } catch CrocEngineError.transferActive {
                    // Brief window after `done` where the engine still holds
                    // the previous transfer (bridge doc) -- retry once.
                    try await Task.sleep(for: .milliseconds(300))
                    stream = try await start()
                }
                for await event in stream { handle(event) }
            } catch {
                phase = .failed(Self.friendlyMessage(for: "\(error)", cancelRequested: cancelRequested, declineRequested: declineRequested))
            }
            releaseScopedURLs()
        }
    }

    private func handle(_ event: TransferEvent) {
        switch event {
        case .codeReady(let code):
            phase = .waiting(code: code)
        case .connected:
            phase = .connecting
        case .fileList(let list):
            let names = list.files.map(\.name)
            let blocked = names.filter { ReceivedName.isUnsafe($0) }
            let conflicts: [String]
            if let outDir {
                conflicts = names.filter {
                    FileManager.default.fileExists(atPath: outDir.appendingPathComponent($0).path)
                }
            } else {
                conflicts = []
            }
            phase = .incoming(list, conflicts: conflicts, blocked: blocked)
        case .progress(let p):
            // step "waiting" ticks arrive while the code screen should stay up.
            guard p.step != "waiting" else { return }
            // Progress ticks keep flowing while the accept prompt is
            // unanswered -- never clobber .incoming; respond() moves the
            // phase forward.
            if case .incoming = phase { return }
            updateSpeed(p)
            phase = .transferring(p)
        case .text(let t):
            receivedText = t
        case .done(let summary):
            phase = .done(summary, receivedText: receivedText)
        case .failed(let message):
            phase = .failed(Self.friendlyMessage(for: message, cancelRequested: cancelRequested, declineRequested: declineRequested))
            // Phase 1 contract: consumer must cancel the engine on .failed so
            // the Go session releases and the next transfer can start.
            Task { await engine.cancel() }
        }
    }

    private func updateSpeed(_ p: TransferProgress) {
        let doneBytes = p.bytesFinished + p.fileSent
        let now = Date()
        guard let last = lastProgressDate else {
            lastProgressDate = now
            lastProgressBytes = doneBytes
            return
        }
        let dt = now.timeIntervalSince(last)
        guard dt > 0.2 else { return }
        let instant = Double(doneBytes - lastProgressBytes) / dt
        speedBytesPerSec = speedBytesPerSec == 0 ? instant : 0.25 * instant + 0.75 * speedBytesPerSec
        lastProgressDate = now
        lastProgressBytes = doneBytes
    }

    private func releaseScopedURLs() {
        scopedURLs.forEach { $0.stopAccessingSecurityScopedResource() }
        scopedURLs = []
    }

    // MARK: - Error copy

    static func friendlyMessage(for raw: String, cancelRequested: Bool, declineRequested: Bool) -> String {
        if cancelRequested { return "Transfer cancelled." }
        if declineRequested { return "You declined the transfer." }
        let m = raw.lowercased()
        // Local cancel during the accept prompt also surfaces "refused files";
        // that case is caught by cancelRequested above.
        if m.contains("refused files") { return "The other side declined the transfer." }
        if m.contains("room full") { return "That code is already in use. Try a different code." }
        if m.contains("no such host") || m.contains("connection refused")
            || m.contains("i/o timeout") || m.contains("dial tcp") {
            return "Couldn't reach the relay. Check your internet connection."
        }
        if m.contains("bad password") {
            return "Wrong code phrase, or the sender is no longer available."
        }
        if m.contains("broken pipe") || m.contains("connection reset") || m.contains("unexpected eof") {
            return "Lost connection to the other device."
        }
        return "Transfer failed: \(raw)"
    }
}
