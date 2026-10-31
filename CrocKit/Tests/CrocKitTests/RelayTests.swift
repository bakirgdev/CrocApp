import Darwin
import Foundation
import Testing

@testable import CrocKit

@Suite struct RelayTests {
    /// A base port whose next three ports are free right now.
    private static func freeBasePort() throws -> Int {
        for _ in 0..<50 {
            let base = Int.random(in: 20_000...60_000)
            let socks = (0..<RelayHost.portCount).map { _ in socket(AF_INET, SOCK_STREAM, 0) }
            defer {
                for fd in socks { close(fd) }
            }
            let allFree = socks.enumerated().allSatisfy { index, fd in
                var addr = sockaddr_in()
                addr.sin_family = sa_family_t(AF_INET)
                addr.sin_addr.s_addr = inet_addr("0.0.0.0")
                addr.sin_port = UInt16(base + index).bigEndian
                return withUnsafePointer(to: &addr) {
                    $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                        bind(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size)) == 0
                    }
                }
            }
            if allFree { return base }
        }
        throw POSIXError(.EADDRINUSE)
    }

    @Test func hostsARelayThatChecksPasswords() async throws {
        let base = try Self.freeBasePort()
        let host = try RelayHost.start(port: base, password: "hosted-secret") { _ in }
        defer { host.stop() }
        #expect(host.ports == Array(base..<(base + RelayHost.portCount)))

        let address = "127.0.0.1:\(base)"
        let good = await RelayCheck.run(address: address, password: "hosted-secret", family: .ipv4)
        #expect(good.verdict == .ok)
        #expect(good.ip == "127.0.0.1")
        #expect((good.latencyMs ?? 0) > 0)
        let bad = await RelayCheck.run(address: address, password: "nope", family: .ipv4)
        #expect(bad.verdict == .badPassword)
        let v6 = await RelayCheck.run(address: address, password: "hosted-secret", family: .ipv6)
        #expect(v6.verdict == .noAddress)

        host.stop()
        let gone = await RelayCheck.run(address: address, password: "hosted-secret", family: .ipv4)
        #expect(gone.verdict == .unreachable)
    }

    @Test func aTakenPortIsPortInUse() throws {
        let base = try Self.freeBasePort()
        let first = try RelayHost.start(port: base, password: "") { _ in }
        defer { first.stop() }
        #expect(throws: EngineFailure.self) {
            try RelayHost.start(port: base + 2, password: "") { _ in }
        }
        do {
            _ = try RelayHost.start(port: base, password: "") { _ in }
            Issue.record("a second relay on the same ports started")
        } catch let failure as EngineFailure {
            #expect(failure.code == .portInUse)
        }
    }

    @Test func aBasePortOutOfRangeIsInvalidSetting() {
        for port in [0, RelayHost.basePortRange.upperBound + 1] {
            do {
                _ = try RelayHost.start(port: port, password: "") { _ in }
                Issue.record("port \(port) started")
            } catch let failure as EngineFailure {
                #expect(failure.code == .invalidSetting)
            } catch {
                Issue.record("unexpected error \(error)")
            }
        }
    }

    @Test func decodesEveryVerdict() {
        func verdict(_ json: String) -> RelayCheckResult.Verdict {
            RelayCheck.decode(json, family: .ipv4).verdict
        }
        #expect(verdict(#"{"family":"4","reachable":true,"passwordOk":true}"#) == .ok)
        #expect(verdict(#"{"family":"4","reachable":false,"code":"noAddress"}"#) == .noAddress)
        #expect(
            verdict(#"{"family":"4","reachable":false,"code":"relayUnreachable"}"#) == .unreachable)
        #expect(verdict(#"{"family":"4","reachable":true,"code":"badPassword"}"#) == .badPassword)
        #expect(verdict(#"{"family":"4","reachable":true,"code":"busy"}"#) == .busy)
        #expect(verdict(#"{"family":"4","reachable":true,"code":"other"}"#) == .notARelay)
        #expect(
            verdict(#"{"family":"4","reachable":false,"code":"invalidSetting"}"#) == .invalidAddress
        )
        #expect(verdict("not json") == .notARelay)
    }

    @Test func publicPoolIsTheEnginesFourRelays() {
        #expect(RelayDefaults.publicPool.count == 4)
        #expect(RelayDefaults.publicPool.allSatisfy { $0.hasSuffix(":9009") })
    }
}
