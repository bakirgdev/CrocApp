import Croc
import Foundation

public enum CrocEngineError: Error, Sendable {
    case transferActive
    case startFailed(EngineFailure)
}

/// Identifies one started transfer, so a late `cancel` aimed at a finished
/// transfer cannot reach the next one.
public struct TransferID: Hashable, Sendable {
    private let value = UUID()
}

/// A started transfer: its ID and its event stream.
public struct EngineTransfer: Sendable {
    public let id: TransferID
    public let events: AsyncStream<TransferEvent>
}

/// Wraps the gomobile croc bridge. One transfer at a time (crocmobile
/// serializes on process-global cwd/stdin/stdout).
public actor CrocEngine {
    public init() {}

    private var activeTransfer: CrocmobileTransfer?
    private var activeID: TransferID?
    private var bridge: DelegateBridge?

    public func startSend(
        paths: [String], text: String?, options: EngineOptions
    ) throws -> EngineTransfer {
        try start(send: true, code: "", paths: paths, text: text ?? "", options: options)
    }

    public func startReceive(
        code: String, options: EngineOptions
    ) throws -> EngineTransfer {
        try start(send: false, code: code, paths: [], text: "", options: options)
    }

    /// Answer the accept/decline request raised by a `.fileList` event. On
    /// accept, `policy` decides what happens to files that already exist;
    /// senders ignore it.
    public func respond(accept: Bool, policy: FilePolicy) {
        activeTransfer?.respond(accept, policy: policy.rawValue)
    }

    /// Cancels the transfer `id` if it is still the active one; a stale ID is
    /// ignored.
    public func cancel(_ id: TransferID) {
        guard id == activeID else { return }
        activeTransfer?.cancel()
    }

    func isActive(_ id: TransferID) -> Bool { id == activeID }

    private func start(
        send: Bool, code: String, paths: [String], text: String, options: EngineOptions
    ) throws -> EngineTransfer {
        guard activeTransfer == nil else { throw CrocEngineError.transferActive }

        let opts = try Self.crocOptions(from: options)
        let (stream, continuation) = AsyncStream.makeStream(of: TransferEvent.self)
        let bridge = DelegateBridge(continuation: continuation)
        self.bridge = bridge

        var error: NSError?
        let transfer: CrocmobileTransfer?
        if send {
            transfer = CrocmobileStartSend(
                paths.joined(separator: "\n"), text, opts, bridge, &error)
        } else {
            transfer = CrocmobileStartReceive(code, opts, bridge, &error)
        }
        guard let transfer else {
            self.bridge = nil
            // gobind passes only the Go error's text, which carries the same
            // payload as OnError.
            throw CrocEngineError.startFailed(EngineFailure(payload: error?.localizedDescription))
        }
        let id = TransferID()
        activeTransfer = transfer
        activeID = id
        continuation.onTermination = { _ in
            // Stream termination (done, failed, the consumer task cancelled,
            // or the malformed-fileList path in DelegateBridge finishing
            // early) must not merely forget the transfer -- the Go session
            // would keep running forever with activeMu held, bricking the
            // engine for any future transfer. cancel() is a Go context
            // cancel: thread-safe and idempotent even if the transfer already
            // finished on its own. CrocmobileTransfer isn't Sendable, so the
            // closure carries only the ID and the actor looks the transfer up.
            Task { await self.cancelAndClear(id) }
        }
        return EngineTransfer(id: id, events: stream)
    }

    private func cancelAndClear(_ id: TransferID) {
        guard id == activeID else { return }
        activeTransfer?.cancel()
        activeTransfer = nil
        activeID = nil
        bridge = nil
    }

    static func crocOptions(from o: EngineOptions) throws -> CrocmobileOptions {
        guard let opts = CrocmobileNewOptionsDefault() else {
            throw CrocEngineError.startFailed(
                EngineFailure(code: .other, message: "options init failed"))
        }
        opts.relayAddress = o.relayAddress
        opts.relayAddress6 = o.relayAddress6
        opts.relayPassword = o.relayPassword
        opts.code = o.customCode
        opts.outDir = o.outDir
        opts.workDir = o.workDir
        opts.disableLocal = o.disableLocal
        opts.onlyLocal = o.onlyLocal
        opts.autoAccept = o.autoAccept
        opts.overwrite = o.whenFileExists == .replace
        opts.rename = o.whenFileExists == .keepBoth
        opts.noCompress = o.noCompress
        opts.zipFolder = o.zipFolder
        opts.gitIgnore = o.gitIgnore
        opts.exclude = o.exclude.joined(separator: "\n")
        opts.ask = o.ask
        return opts
    }
}
