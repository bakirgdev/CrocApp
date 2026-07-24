import Croc
import Foundation

public enum CrocEngineError: Error, Sendable {
    case transferActive
    case startFailed(String)
}

/// Wraps the gomobile croc bridge. One transfer at a time (crocmobile
/// serializes on process-global cwd/stdin/stdout).
public actor CrocEngine {
    public init() {}

    private var activeTransfer: CrocmobileTransfer?
    private var bridge: DelegateBridge?

    public func startSend(
        paths: [String], text: String?, options: EngineOptions
    ) throws -> AsyncStream<TransferEvent> {
        try start(send: true, code: "", paths: paths, text: text ?? "", options: options)
    }

    public func startReceive(
        code: String, options: EngineOptions
    ) throws -> AsyncStream<TransferEvent> {
        try start(send: false, code: code, paths: [], text: "", options: options)
    }

    /// Answer the accept/decline request raised by a `.fileList` event.
    public func respond(accept: Bool) {
        activeTransfer?.respond(accept)
    }

    public func cancel() {
        activeTransfer?.cancel()
    }

    private func start(
        send: Bool, code: String, paths: [String], text: String, options: EngineOptions
    ) throws -> AsyncStream<TransferEvent> {
        guard activeTransfer == nil else { throw CrocEngineError.transferActive }

        let opts = crocOptions(from: options)
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
            throw CrocEngineError.startFailed(error?.localizedDescription ?? "unknown")
        }
        activeTransfer = transfer
        continuation.onTermination = { _ in
            // Stream termination (consumer task cancelled, or the
            // malformed-fileList path in DelegateBridge finishing early)
            // must not merely forget the transfer -- the Go session would
            // keep running forever with activeMu held, bricking the engine
            // for any future transfer. cancel() is a Go context cancel:
            // thread-safe and idempotent even if the transfer already
            // finished on its own. CrocmobileTransfer isn't Sendable, so
            // rather than capture `transfer` across this @Sendable closure,
            // cancel via the actor's own isolated state -- `start()` never
            // lets a second transfer start while this one is still set, so
            // `self.activeTransfer` here is still this same transfer.
            Task { await self.cancelAndClear() }
        }
        return stream
    }

    private func cancelAndClear() {
        activeTransfer?.cancel()
        activeTransfer = nil
        bridge = nil
    }

    private func crocOptions(from o: EngineOptions) -> CrocmobileOptions {
        let opts = CrocmobileNewOptions()!
        opts.relayAddress = o.relayAddress
        opts.relayAddress6 = o.relayAddress6
        opts.relayPassword = o.relayPassword
        opts.code = o.customCode
        opts.outDir = o.outDir
        opts.workDir = o.workDir
        opts.disableLocal = o.disableLocal
        opts.onlyLocal = o.onlyLocal
        opts.autoAccept = o.autoAccept
        opts.overwrite = o.overwrite
        opts.noCompress = o.noCompress
        opts.zipFolder = o.zipFolder
        opts.gitIgnore = o.gitIgnore
        opts.exclude = o.exclude.joined(separator: "\n")
        opts.ask = o.ask
        return opts
    }
}
