import CrocKit
import Foundation
import Testing

@testable import CrocApp

@MainActor @Suite struct RelayHealthTests {
    private let settings = AppSettings(
        storage: MemorySettingsStorage(), secrets: FakeSecretStore())

    private func result(
        _ verdict: RelayCheckResult.Verdict, _ family: RelayFamily = .ipv4
    ) -> RelayCheckResult {
        RelayCheckResult(family: family, ip: "203.0.113.1", latencyMs: 12, verdict: verdict)
    }

    /// Answers each probe from `verdicts[family]` and records what it was asked.
    /// `RelayHealth` runs the probes in a task group, so the record is locked.
    private nonisolated final class Probe: @unchecked Sendable {
        private let lock = NSLock()
        private var calls: [(String, String, RelayFamily)] = []
        var verdicts: [RelayFamily: RelayCheckResult.Verdict] = [:]

        var asked: [(String, String, RelayFamily)] { lock.withLock { calls } }
        func record(_ call: (String, String, RelayFamily)) { lock.withLock { calls.append(call) } }
    }

    private func health(_ probe: Probe) -> RelayHealth {
        RelayHealth(
            settings: settings,
            checker: { address, password, family in
                probe.record((address, password, family))
                return RelayCheckResult(
                    family: family, ip: nil, latencyMs: 5,
                    verdict: probe.verdicts[family] ?? .ok)
            })
    }

    @Test func noCustomRelayChecksThePublicPool() {
        #expect(health(Probe()).targets == RelayDefaults.publicPool)
    }

    @Test func aCustomRelayIsTheOnlyTargetAndDefaultsAreNotCustom() {
        settings.relayAddress = " relay.example:9009 "
        settings.relayAddress6 = RelayDefaults.address6
        #expect(health(Probe()).targets == ["relay.example:9009"])
    }

    @Test func localNetworkOnlyChecksNoRelay() async {
        settings.onlyLocal = true
        let probe = Probe()
        let health = health(probe)
        await health.run()
        #expect(health.usesNoRelay)
        #expect(health.targets.isEmpty)
        #expect(probe.asked.isEmpty)
    }

    @Test func probesEachAddressOverBothFamiliesWithTheTrimmedPassword() async {
        settings.relayAddress = "relay.example:9009"
        settings.relayPassword = " hunter2\n"
        let probe = Probe()
        let health = health(probe)
        await health.run()
        #expect(Set(probe.asked.map(\.2)) == [.ipv4, .ipv6])
        #expect(probe.asked.allSatisfy { $0.0 == "relay.example:9009" && $0.1 == "hunter2" })
        #expect(health.isHealthy)
        #expect(health.advice.isEmpty)
    }

    @Test func aRejectedPasswordUsesTheTransferFailureWords() async {
        settings.relayAddress = "relay.example:9009"
        let probe = Probe()
        probe.verdicts = [.ipv4: .badPassword, .ipv6: .noAddress]
        let health = health(probe)
        await health.run()
        let expected = TransferFailure(
            EngineFailure(code: .badPassword, message: ""), situation: .init())
        #expect(health.advice == [expected])
        #expect(!health.isHealthy)
    }

    @Test func anAddressNothingReachesUsesTheRelayUnreachableWords() async {
        settings.relayAddress = "relay.example:9009"
        let probe = Probe()
        probe.verdicts = [.ipv4: .unreachable, .ipv6: .noAddress]
        let health = health(probe)
        await health.run()
        let expected = TransferFailure(
            EngineFailure(code: .relayUnreachable, message: ""), situation: .init())
        #expect(health.advice == [expected])
    }

    /// One IP version working is enough: the other failing is not advice.
    @Test func oneWorkingFamilyIsHealthy() async {
        settings.relayAddress = "relay.example:9009"
        let probe = Probe()
        probe.verdicts = [.ipv4: .ok, .ipv6: .unreachable]
        let health = health(probe)
        await health.run()
        #expect(health.advice.isEmpty)
        #expect(health.isHealthy)
    }

    @Test func aNonCrocListenerIsFlagged() async {
        settings.relayAddress = "relay.example:9009"
        let probe = Probe()
        probe.verdicts = [.ipv4: .notARelay, .ipv6: .noAddress]
        let health = health(probe)
        await health.run()
        #expect(health.advice == [RelayHealth.notARelay])
    }

    @Test func aBusyRelayIsNotARelayProblemButIsSaid() async {
        settings.relayAddress = "relay.example:9009"
        let probe = Probe()
        probe.verdicts = [.ipv4: .busy, .ipv6: .noAddress]
        let health = health(probe)
        await health.run()
        #expect(health.advice == [RelayHealth.busy])
        #expect(health.advice != [RelayHealth.notARelay])
    }

    @Test func aProxyIsDetectedFromEitherField() {
        #expect(!health(Probe()).usesProxy)
        settings.httpProxy = "http://proxy.example:3128"
        #expect(health(Probe()).usesProxy)
        settings.httpProxy = ""
        settings.socks5Proxy = " \n"
        #expect(!health(Probe()).usesProxy)
        settings.socks5Proxy = "proxy.example:1080"
        #expect(health(Probe()).usesProxy)
    }

    @Test func noAdviceUntilEveryProbeAnswered() {
        #expect(health(Probe()).advice.isEmpty)
        #expect(!health(Probe()).isHealthy)
    }
}
