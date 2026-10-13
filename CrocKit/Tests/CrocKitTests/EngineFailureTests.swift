import Foundation
import Testing

@testable import CrocKit

@Suite struct EngineFailureTests {
    @Test(arguments: EngineFailure.Code.allCases)
    func decodesEveryCode(code: EngineFailure.Code) {
        let f = EngineFailure(payload: #"{"code":"\#(code.rawValue)","message":"croc text"}"#)
        #expect(f == EngineFailure(code: code, message: "croc text"))
    }

    @Test func unknownCodeIsOtherWithMessage() {
        let f = EngineFailure(payload: #"{"code":"storeExpired","message":"gone"}"#)
        #expect(f == EngineFailure(code: .other, message: "gone"))
    }

    @Test(arguments: ["", "relay down", "{}", #"{"code":"declined"}"#, #"["declined"]"#])
    func malformedPayloadIsOtherWithRawText(payload: String) {
        #expect(EngineFailure(payload: payload) == EngineFailure(code: .other, message: payload))
    }

    @Test func missingPayloadIsOther() {
        #expect(
            EngineFailure(payload: nil) == EngineFailure(code: .other, message: "unknown error"))
    }
}

/// Drains a transfer's events and returns the terminal failure, if any.
private func failure(of events: AsyncStream<TransferEvent>) async -> EngineFailure? {
    for await event in events {
        if case .failed(let f) = event { return f }
        if case .done = event { return nil }
    }
    return nil
}

/// Retries past the brief window in which the engine still holds the previous
/// transfer (it is cleared from the stream's onTermination).
private func startReceive(
    _ engine: CrocEngine, code: String, options: EngineOptions
) async throws -> EngineTransfer {
    for _ in 0..<40 {
        do {
            return try await engine.startReceive(code: code, options: options)
        } catch CrocEngineError.transferActive {
            try await Task.sleep(for: .milliseconds(50))
        }
    }
    return try await engine.startReceive(code: code, options: options)
}

/// A localhost socket that listens but never accepts: the kernel completes the
/// TCP handshake, so croc connects and then waits for a relay reply that never
/// comes. Stands in for a transfer in progress without touching the network.
private struct SilentListener {
    let fd: Int32
    let port: UInt16

    init() throws {
        let sock = socket(AF_INET, SOCK_STREAM, 0)
        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_addr.s_addr = inet_addr("127.0.0.1")
        var len = socklen_t(MemoryLayout<sockaddr_in>.size)
        let bound = withUnsafeMutablePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(sock, $0, len) == 0 && listen(sock, 8) == 0
                    && getsockname(sock, $0, &len) == 0
            }
        }
        guard sock >= 0, bound else { throw POSIXError(.EADDRNOTAVAIL) }
        fd = sock
        port = UInt16(bigEndian: addr.sin_port)
    }

    func close() { Darwin.close(fd) }
}

/// Runs real engine transfers; the Go engine allows one at a time per process.
@Suite(.serialized) struct CrocEngineCancelTests {
    private func options() -> EngineOptions {
        var o = EngineOptions()
        o.outDir =
            FileManager.default.temporaryDirectory
            .appendingPathComponent("crockit-tests-\(UUID().uuidString)").path
        return o
    }

    @Test func unreachableRelayFailsWithItsCode() async throws {
        var o = options()
        o.relayAddress = "127.0.0.1:1"
        let transfer = try await startReceive(
            CrocEngine(), code: "unreach-alpha-bravo", options: o)
        let f = try #require(await failure(of: transfer.events))
        #expect(f.code == .relayUnreachable, "\(f.message)")
    }

    @Test func staleCancelLeavesTheNextTransferRunning() async throws {
        let engine = CrocEngine()
        var dead = options()
        dead.relayAddress = "127.0.0.1:1"
        let first = try await startReceive(engine, code: "stale-alpha-bravo", options: dead)
        _ = await failure(of: first.events)

        let relay = try SilentListener()
        defer { relay.close() }
        var waiting = options()
        waiting.relayAddress = "127.0.0.1:\(relay.port)"
        waiting.disableLocal = true
        let second = try await startReceive(engine, code: "stale-charlie-delta", options: waiting)
        #expect(second.id != first.id)
        let outcome = Task { await failure(of: second.events) }

        await engine.cancel(first.id)
        try await Task.sleep(for: .milliseconds(700))
        #expect(await engine.isActive(second.id))

        await engine.cancel(second.id)
        let f = try #require(await outcome.value)
        #expect(f.code == .cancelled, "\(f.message)")
    }
}
