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
        let f = EngineFailure(payload: #"{"code":"fromANewerEngine","message":"gone"}"#)
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
        let transfer = try await CrocEngine().startReceive(
            code: "unreach-alpha-bravo", options: o)
        let f = try #require(await failure(of: transfer.events))
        #expect(f.code == .relayUnreachable, "\(f.message)")
    }

    @Test func staleCancelLeavesTheNextTransferRunning() async throws {
        let engine = CrocEngine()
        var dead = options()
        dead.relayAddress = "127.0.0.1:1"
        let first = try await engine.startReceive(code: "stale-alpha-bravo", options: dead)
        _ = await failure(of: first.events)

        let relay = try SilentListener()
        defer { relay.close() }
        var waiting = options()
        waiting.relayAddress = "127.0.0.1:\(relay.port)"
        waiting.disableLocal = true
        // Right after the first one's terminal event, with no retry.
        let second = try await engine.startReceive(code: "stale-charlie-delta", options: waiting)
        #expect(second.id != first.id)
        let outcome = Task { await failure(of: second.events) }

        await engine.cancel(first.id)
        try await Task.sleep(for: .milliseconds(700))
        #expect(await engine.isActive(second.id))

        await engine.cancel(second.id)
        let f = try #require(await outcome.value)
        #expect(f.code == .cancelled, "\(f.message)")
    }

    /// Go refuses a start while it runs another transfer. A second engine has
    /// no Swift-side slot taken, so the refusal is Go's typed code.
    @Test func goRefusalIsTransferActive() async throws {
        let relay = try SilentListener()
        defer { relay.close() }
        var waiting = options()
        waiting.relayAddress = "127.0.0.1:\(relay.port)"
        waiting.disableLocal = true
        let engine = CrocEngine()
        let running = try await engine.startReceive(code: "busy-alpha-bravo", options: waiting)
        let outcome = Task { await failure(of: running.events) }

        do {
            _ = try await CrocEngine().startReceive(code: "busy-charlie-delta", options: options())
            Issue.record("a second start while one runs succeeded")
        } catch CrocEngineError.transferActive {
        } catch {
            Issue.record("a second start while one runs threw \(error), not transferActive")
        }

        await engine.cancel(running.id)
        let f = try #require(await outcome.value)
        #expect(f.code == .cancelled, "\(f.message)")
    }
}
