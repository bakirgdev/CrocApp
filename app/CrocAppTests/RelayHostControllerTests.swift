#if os(macOS)
import CrocKit
import Foundation
import Testing

@testable import CrocApp

private final class FakeRelay: RelayHandle, @unchecked Sendable {
    let ports: [Int]
    private(set) var stops = 0
    init(ports: [Int]) { self.ports = ports }
    func stop() { stops += 1 }
}

@MainActor @Suite struct RelayHostControllerTests {
    private let settings = AppSettings(
        storage: MemorySettingsStorage(), secrets: FakeSecretStore())

    /// A controller whose starter records its arguments and returns `relay`, or throws `failure`.
    private func controller(
        relay: FakeRelay = FakeRelay(ports: [9009, 9010, 9011, 9012]),
        failure: EngineFailure? = nil,
        calls: Calls = Calls()
    ) -> (RelayHostController, Calls) {
        let controller = RelayHostController(
            settings: settings,
            starter: { port, password, onStopped in
                calls.record(port: port, password: password, onStopped: onStopped)
                if let failure { throw failure }
                return relay
            },
            stopsAtQuit: false)
        return (controller, calls)
    }

    final class Calls: @unchecked Sendable {
        private(set) var starts: [(port: Int, password: String)] = []
        private(set) var onStopped: (@Sendable (EngineFailure) -> Void)?
        func record(
            port: Int, password: String, onStopped: @escaping @Sendable (EngineFailure) -> Void
        ) {
            starts.append((port, password))
            self.onStopped = onStopped
        }
    }

    @Test func neverStartsOnItsOwn() {
        let (controller, calls) = controller()
        controller.startAtLaunchIfWanted()
        #expect(calls.starts.isEmpty)
        #expect(controller.state == .stopped)
    }

    @Test func startsAtLaunchOnlyWhenTheSettingIsOn() {
        settings.relayHostAtLaunch = true
        let (controller, calls) = controller()
        controller.startAtLaunchIfWanted()
        #expect(calls.starts.count == 1)
        #expect(controller.isRunning)
    }

    @Test func startPassesThePortAndTheTrimmedPasswordThenStopStopsIt() {
        settings.relayHostPort = 9100
        settings.relayHostPassword = "  hosted-secret \n"
        let relay = FakeRelay(ports: [9100, 9101, 9102, 9103])
        let (controller, calls) = controller(relay: relay)
        controller.start()
        #expect(calls.starts.first?.port == 9100)
        #expect(calls.starts.first?.password == "hosted-secret")
        #expect(controller.state == .running(ports: [9100, 9101, 9102, 9103]))
        controller.start()
        #expect(calls.starts.count == 1, "a second start while running does nothing")
        controller.stop()
        #expect(relay.stops == 1)
        #expect(controller.state == .stopped)
    }

    @Test func aTakenPortShowsTheFailureAndRunsNothing() {
        let (controller, _) = controller(
            failure: EngineFailure(code: .portInUse, message: "address already in use"))
        controller.start()
        guard case .failed(let failure) = controller.state else {
            Issue.record("state \(controller.state)")
            return
        }
        #expect(failure.title == String(localized: "That port is already in use"))
        #expect(!controller.isRunning)
    }

    @Test func anOutOfRangePortNeverReachesTheEngine() {
        settings.relayHostPort = 70_000
        let (controller, calls) = controller()
        controller.start()
        #expect(calls.starts.isEmpty)
        guard case .failed = controller.state else {
            Issue.record("state \(controller.state)")
            return
        }
    }

    @Test func aRelayThatStopsByItselfIsShownAsFailed() async {
        let relay = FakeRelay(ports: [9009, 9010, 9011, 9012])
        let (controller, calls) = controller(relay: relay)
        controller.start()
        calls.onStopped?(EngineFailure(code: .other, message: "accept failed"))
        for _ in 0..<100 where controller.isRunning { await Task.yield() }
        guard case .failed = controller.state else {
            Issue.record("state \(controller.state)")
            return
        }
        #expect(relay.stops == 1)
    }
}

@Suite struct LocalAddressesTests {
    @Test func relayAddressBracketsIPv6() {
        let v4 = LocalAddresses.Address(interface: "en0", ip: "192.168.1.20", isIPv6: false)
        let v6 = LocalAddresses.Address(interface: "en0", ip: "2001:db8::1", isIPv6: true)
        #expect(LocalAddresses.relayAddress(v4, port: 9009) == "192.168.1.20:9009")
        #expect(LocalAddresses.relayAddress(v6, port: 9009) == "[2001:db8::1]:9009")
    }

    @Test func currentLeavesOutLoopbackAndLinkLocal() {
        let all = LocalAddresses.current()
        #expect(all.allSatisfy { $0.ip != "127.0.0.1" && $0.ip != "::1" })
        #expect(all.allSatisfy { !$0.ip.lowercased().hasPrefix("fe80") })
        // IPv4 first.
        if let firstV6 = all.firstIndex(where: { $0.isIPv6 }) {
            let rest = all[firstV6...]
            #expect(rest.allSatisfy { $0.isIPv6 })
        }
    }
}
#endif
