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

    /// A new ID, unequal to every other.
    public init() {}
}

/// A started transfer: its ID and its event stream.
public struct EngineTransfer: Sendable {
    public let id: TransferID
    public let events: AsyncStream<TransferEvent>

    public init(id: TransferID, events: AsyncStream<TransferEvent>) {
        self.id = id
        self.events = events
    }
}

/// What the app needs from a transfer engine: `CrocEngine` in the app, a fake
/// in the app's tests. The contract is `CrocEngine`'s: one transfer at a time,
/// a start throws `CrocEngineError`, the stream ends after `.done` or
/// `.failed`, and `cancel` ignores an ID that is no longer active.
public protocol TransferEngine: Sendable {
    func startSend(
        paths: [String], text: String?, options: EngineOptions
    ) async throws -> EngineTransfer

    func startReceive(code: String, options: EngineOptions) async throws -> EngineTransfer

    func startStoreSend(
        paths: [String], options: StoredSendOptions
    ) async throws -> EngineTransfer

    func startStoreReceive(
        link: String, outDir: String, proxy: ProxySettings
    ) async throws -> EngineTransfer

    func respond(accept: Bool, policy: FilePolicy) async

    func cancel(_ id: TransferID) async

    func revokeStored(_ receipt: StoredReceipt, proxy: ProxySettings) async throws
}

extension CrocEngine: TransferEngine {}

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
        let opts = try Self.crocOptions(from: options)
        let joined = try Self.joinedPaths(paths)
        return try start { bridge, error in
            CrocmobileStartSend(joined, text ?? "", opts, bridge, error)
        }
    }

    public func startReceive(
        code: String, options: EngineOptions
    ) throws -> EngineTransfer {
        let opts = try Self.crocOptions(from: options)
        return try start { bridge, error in CrocmobileStartReceive(code, opts, bridge, error) }
    }

    /// Uploads `paths` (regular files) encrypted to `options.server`. Events:
    /// `.progress`, then `.stored(receipt)` and `.done`.
    public func startStoreSend(
        paths: [String], options: StoredSendOptions
    ) throws -> EngineTransfer {
        let opts = CrocmobileStoreOptions()
        opts.server = options.server
        opts.downloads = options.downloads
        opts.lifetimeSeconds = options.lifetimeSeconds
        opts.socks5Proxy = options.proxy.socks5
        opts.httpProxy = options.proxy.http
        let joined = try Self.joinedPaths(paths)
        return try start { bridge, error in
            CrocmobileStartStoreSend(joined, opts, bridge, error)
        }
    }

    /// Opens a stored-transfer link: `.fileList` first, then wait for
    /// `respond(accept:policy:)`; on accept the files land in `outDir`.
    public func startStoreReceive(
        link: String, outDir: String, proxy: ProxySettings
    ) throws -> EngineTransfer {
        let opts = Self.storeOptions(proxy: proxy)
        return try start { bridge, error in
            CrocmobileStartStoreReceive(link, outDir, opts, bridge, error)
        }
    }

    /// Deletes a stored upload from its server; a transfer the server no longer
    /// has counts as revoked. Throws `EngineFailure`. Blocks up to 30 seconds on
    /// the network, off the caller's actor, and needs no running transfer, so it
    /// works while another one is active.
    public nonisolated func revokeStored(
        _ receipt: StoredReceipt, proxy: ProxySettings
    ) async throws {
        var error: NSError?
        let opts = Self.storeOptions(proxy: proxy)
        guard
            CrocmobileRevokeStored(receipt.origin, receipt.id, receipt.uploadToken, opts, &error)
        else {
            throw EngineFailure(payload: error?.localizedDescription)
        }
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
        launch: (DelegateBridge, NSErrorPointer) -> CrocmobileTransfer?
    ) throws -> EngineTransfer {
        guard activeTransfer == nil else { throw CrocEngineError.transferActive }

        let (stream, continuation) = AsyncStream.makeStream(of: TransferEvent.self)
        let bridge = DelegateBridge(continuation: continuation)
        self.bridge = bridge

        var error: NSError?
        guard let transfer = launch(bridge, &error) else {
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

    /// The Go side splits the list on "\n", so a path holding a line break would
    /// turn into several send paths (`a.jpg\n..` sends the parent folder).
    private static func joinedPaths(_ paths: [String]) throws -> String {
        if paths.contains(where: { $0.contains(where: \.isNewline) }) {
            throw CrocEngineError.startFailed(
                EngineFailure(code: .invalidSetting, message: "a file name contains a line break"))
        }
        return paths.joined(separator: "\n")
    }

    private static func storeOptions(proxy: ProxySettings) -> CrocmobileStoreOptions {
        let opts = CrocmobileStoreOptions()
        opts.socks5Proxy = proxy.socks5
        opts.httpProxy = proxy.http
        return opts
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
        opts.transport = o.transport.rawValue
        opts.noCompress = o.noCompress
        opts.zipFolder = o.zipFolder
        opts.gitIgnore = o.gitIgnore
        opts.exclude = o.exclude.joined(separator: "\n")
        opts.ask = o.ask
        opts.throttleUpload = o.throttleUpload
        opts.multicastAddress = o.multicastAddress
        opts.peerIP = o.peerIP
        opts.socks5Proxy = o.socks5Proxy
        opts.httpProxy = o.httpProxy
        return opts
    }
}
