import Croc
import Foundation
import Synchronization

/// Bridges CrocmobileDelegateProtocol callbacks (arbitrary Go threads)
/// into an AsyncStream. Terminates the stream on done/error.
///
/// On a malformed `fileList` payload the bridge cannot cancel the Go
/// transfer itself (only `CrocEngine` holds the `CrocmobileTransfer`
/// handle) — it yields `.failed` and finishes the stream; finishing runs
/// `CrocEngine`'s onTermination, which cancels that transfer by its ID.
final class DelegateBridge: NSObject, CrocmobileDelegateProtocol, @unchecked Sendable {
    private let continuation: AsyncStream<TransferEvent>.Continuation
    // Progress ticks at ~10 Hz, so a one-hour transfer decodes ~36,000 times;
    // one shared decoder avoids allocating fresh each time. Safe to reuse
    // across the concurrent Go-thread callbacks below: decode(_:from:) reads
    // only the decoder's fixed configuration (never mutated after this
    // init) and keeps its per-call state local, so concurrent decodes don't
    // share mutable state.
    private let decoder = JSONDecoder()
    private let receiptDecoder = StoredReceipt.decoder()
    private let ended = Mutex(false)

    /// The Go session sent its terminal `OnDone` or `OnError`. Go frees its
    /// transfer lock before either, so once this is true a new start can go
    /// ahead. An early finish of the stream (a malformed payload) does not set
    /// it: the Go session is still running then.
    var hasEnded: Bool { ended.withLock { $0 } }

    init(continuation: AsyncStream<TransferEvent>.Continuation) {
        self.continuation = continuation
    }

    private func decode<T: Codable>(_ json: String, as type: T.Type) -> T? {
        guard let data = json.data(using: .utf8) else { return nil }
        return try? decoder.decode(type, from: data)
    }

    func onCodeReady(_ code: String?) {
        continuation.yield(.codeReady(code ?? ""))
    }
    func onConnected() {
        continuation.yield(.connected)
    }
    func onFileList(_ listJSON: String?) {
        guard let json = listJSON, let list = decode(json, as: FileList.self) else {
            // Unrecoverable: without a decoded list the consumer can never call
            // respond(accept:policy:), so the Go side would otherwise wait forever.
            continuation.yield(
                .failed(EngineFailure(code: .other, message: "malformed fileList payload")))
            continuation.finish()
            return
        }
        continuation.yield(.fileList(list))
    }
    func onProgress(_ progressJSON: String?) {
        // Drop-on-decode-failure is fine here: progress is advisory and the
        // next tick retries, unlike fileList which gates respond(accept:policy:).
        guard let json = progressJSON, let p = decode(json, as: TransferProgress.self) else {
            return
        }
        continuation.yield(.progress(p))
    }
    func onText(_ text: String?) {
        continuation.yield(.text(text ?? ""))
    }
    func onStored(_ receiptJSON: String?) {
        guard let data = receiptJSON?.data(using: .utf8),
            let receipt = try? receiptDecoder.decode(StoredReceipt.self, from: data)
        else {
            // The upload is on the server but its revoke token is lost; fail
            // loudly instead of showing a transfer nobody can take back.
            continuation.yield(
                .failed(EngineFailure(code: .other, message: "malformed storedReceipt payload")))
            continuation.finish()
            return
        }
        continuation.yield(.stored(receipt))
    }
    func onDone(_ summaryJSON: String?) {
        ended.withLock { $0 = true }
        if let json = summaryJSON, let s = decode(json, as: Summary.self) {
            continuation.yield(.done(s))
        } else {
            continuation.yield(
                .failed(EngineFailure(code: .other, message: "malformed done payload")))
        }
        continuation.finish()
    }
    func onError(_ payload: String?) {
        ended.withLock { $0 = true }
        continuation.yield(.failed(EngineFailure(payload: payload)))
        continuation.finish()
    }
}
