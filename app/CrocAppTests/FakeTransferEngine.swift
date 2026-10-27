import CrocKit
import Testing

/// A `TransferEngine` the test drives by hand. It records every call, hands
/// out a transfer whose events the test emits, and can throw from or hold a
/// start. Like `DelegateBridge`, a `.done` or `.failed` ends the stream.
///
/// The event stream is pull-based (`AsyncStream(unfolding:)`): the controller
/// asks for one event at a time, so once it is back asking, it has handled
/// every event emitted before. `isDrained` exposes that, and tests wait on it
/// instead of sleeping.
actor FakeTransferEngine: TransferEngine {
    nonisolated enum Start: Sendable {
        case send(paths: [String], text: String?, options: EngineOptions)
        case receive(code: String, options: EngineOptions)
        case storeSend(paths: [String], options: StoredSendOptions)
        case storeReceive(link: String, outDir: String, proxy: ProxySettings)
    }

    nonisolated struct Response: Equatable, Sendable {
        let accept: Bool
        let policy: FilePolicy
    }

    /// Every start call, including the ones that threw.
    private(set) var starts: [Start] = []
    /// The ID of every transfer a start returned, oldest first.
    private(set) var transferIDs: [TransferID] = []
    private(set) var responses: [Response] = []
    private(set) var cancels: [TransferID] = []
    private(set) var revokes: [StoredReceipt] = []
    /// How many held starts found their calling task cancelled on release.
    /// `CrocEngine` would cancel such a start; the fake still returns it.
    private(set) var cancelledStarts = 0

    private var startErrors: [CrocEngineError] = []
    private var revokeFailure: EngineFailure?
    private var holdsNextStart = false
    private var heldStart: CheckedContinuation<Void, Never>?
    private var holdsNextRevoke = false
    private var heldRevoke: CheckedContinuation<Void, Never>?

    /// Counts started transfers; a stream whose number is not this one is stale.
    private var stream = 0
    private var queue: [TransferEvent] = []
    private var finished = false
    /// The controller got `nil`: its event loop is over.
    private var ended = false
    private var consumer: CheckedContinuation<TransferEvent?, Never>?

    // MARK: - TransferEngine

    func startSend(
        paths: [String], text: String?, options: EngineOptions
    ) async throws -> EngineTransfer {
        try await start(.send(paths: paths, text: text, options: options))
    }

    func startReceive(code: String, options: EngineOptions) async throws -> EngineTransfer {
        try await start(.receive(code: code, options: options))
    }

    func startStoreSend(
        paths: [String], options: StoredSendOptions
    ) async throws -> EngineTransfer {
        try await start(.storeSend(paths: paths, options: options))
    }

    func startStoreReceive(
        link: String, outDir: String, proxy: ProxySettings
    ) async throws -> EngineTransfer {
        try await start(.storeReceive(link: link, outDir: outDir, proxy: proxy))
    }

    func respond(accept: Bool, policy: FilePolicy) {
        responses.append(Response(accept: accept, policy: policy))
    }

    func cancel(_ id: TransferID) {
        cancels.append(id)
    }

    func revokeStored(_ receipt: StoredReceipt, proxy: ProxySettings) async throws {
        revokes.append(receipt)
        if holdsNextRevoke {
            holdsNextRevoke = false
            await withCheckedContinuation { heldRevoke = $0 }
        }
        if let revokeFailure { throw revokeFailure }
    }

    // MARK: - Test controls

    /// The next start throws `error`. Queued errors are thrown one per start.
    func failNextStart(with error: CrocEngineError) {
        startErrors.append(error)
    }

    /// Every revoke is recorded, then throws `failure`.
    func failRevokes(with failure: EngineFailure) {
        revokeFailure = failure
    }

    /// The next start is recorded, then suspends until `releaseStart()`.
    func holdNextStart() {
        holdsNextStart = true
    }

    var isHoldingStart: Bool { heldStart != nil }

    /// The next revoke is recorded, then suspends until `releaseRevoke()`.
    func holdNextRevoke() {
        holdsNextRevoke = true
    }

    var isHoldingRevoke: Bool { heldRevoke != nil }

    func releaseRevoke() {
        heldRevoke?.resume()
        heldRevoke = nil
    }

    func releaseStart() {
        heldStart?.resume()
        heldStart = nil
    }

    /// True once the controller has handled every emitted event: it is waiting
    /// for the next one, or its event loop is over. False before any start.
    var isDrained: Bool { queue.isEmpty && (consumer != nil || ended) }

    func emit(_ event: TransferEvent) {
        guard stream > 0, !finished else {
            Issue.record("emit(\(event)) without a live transfer")
            return
        }
        if let consumer {
            self.consumer = nil
            consumer.resume(returning: event)
        } else {
            queue.append(event)
        }
        switch event {
        case .done, .failed: finish()
        default: break
        }
    }

    /// Ends the live stream after the events already emitted.
    func finish() {
        guard stream > 0, !finished else { return }
        finished = true
        if queue.isEmpty, let consumer {
            self.consumer = nil
            ended = true
            consumer.resume(returning: nil)
        }
    }

    // MARK: - Plumbing

    private func start(_ call: Start) async throws -> EngineTransfer {
        starts.append(call)
        if holdsNextStart {
            holdsNextStart = false
            await withCheckedContinuation { heldStart = $0 }
            if Task.isCancelled { cancelledStarts += 1 }
        }
        if !startErrors.isEmpty { throw startErrors.removeFirst() }
        // CrocEngine's contract: one transfer at a time.
        if stream > 0, !finished { throw CrocEngineError.transferActive }

        endStream()
        stream += 1
        queue = []
        finished = false
        ended = false
        let number = stream
        let id = TransferID()
        transferIDs.append(id)
        let events = AsyncStream<TransferEvent>(
            unfolding: { await self.next(stream: number) },
            onCancel: { Task { await self.consumerCancelled(stream: number) } })
        return EngineTransfer(id: id, events: events)
    }

    private func next(stream number: Int) async -> TransferEvent? {
        guard number == stream else { return nil }
        if !queue.isEmpty { return queue.removeFirst() }
        if finished {
            ended = true
            return nil
        }
        return await withCheckedContinuation { consumer = $0 }
    }

    /// The controller cancelled its event loop (`reset()`): end the stream so
    /// the loop does not stay suspended in `next`.
    private func consumerCancelled(stream number: Int) {
        guard number == stream else { return }
        endStream()
    }

    private func endStream() {
        finished = true
        ended = true
        consumer?.resume(returning: nil)
        consumer = nil
    }
}
