import Foundation
import Croc

/// Bridges CrocmobileDelegateProtocol callbacks (arbitrary Go threads)
/// into an AsyncStream. Terminates the stream on done/error.
///
/// On a malformed `fileList` payload the bridge cannot cancel the Go
/// transfer itself (only `CrocEngine` holds the `CrocmobileTransfer`
/// handle) — it yields `.failed` and finishes the stream; the consumer
/// must call `engine.cancel()` on seeing `.failed` to actually tear down
/// the abandoned Go-side session.
final class DelegateBridge: NSObject, CrocmobileDelegateProtocol, @unchecked Sendable {
    private let continuation: AsyncStream<TransferEvent>.Continuation

    init(continuation: AsyncStream<TransferEvent>.Continuation) {
        self.continuation = continuation
    }

    private func decode<T: Codable>(_ json: String, as type: T.Type) -> T? {
        guard let data = json.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
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
            // respond(accept:), so the Go side would otherwise wait forever.
            continuation.yield(.failed("malformed fileList payload"))
            continuation.finish()
            return
        }
        continuation.yield(.fileList(list))
    }
    func onProgress(_ progressJSON: String?) {
        // Drop-on-decode-failure is fine here: progress is advisory and the
        // next tick retries, unlike fileList which gates respond(accept:).
        guard let json = progressJSON, let p = decode(json, as: Progress.self) else { return }
        continuation.yield(.progress(p))
    }
    func onText(_ text: String?) {
        continuation.yield(.text(text ?? ""))
    }
    func onDone(_ summaryJSON: String?) {
        if let json = summaryJSON, let s = decode(json, as: Summary.self) {
            continuation.yield(.done(s))
        } else {
            continuation.yield(.failed("malformed done payload"))
        }
        continuation.finish()
    }
    func onError(_ message: String?) {
        continuation.yield(.failed(message ?? "unknown error"))
        continuation.finish()
    }
}
