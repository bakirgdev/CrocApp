import CrocKit
import Foundation
import SwiftUI
import Testing

@testable import CrocApp

/// `TransferSpeed`: an exponential moving average over progress ticks, sampled
/// at most every 0.2 s.
@Suite struct TransferSpeedTests {
    private let start = Date(timeIntervalSinceReferenceDate: 1_000)

    @Test func theFirstTickOnlySetsTheBaseline() {
        var speed = TransferSpeed()
        speed.record(5_000, at: start)
        #expect(speed.bytesPerSecond == 0)
    }

    @Test func theFirstSampleIsTheInstantSpeed() {
        var speed = TransferSpeed()
        speed.record(0, at: start)
        speed.record(1_000, at: start.addingTimeInterval(1))
        #expect(speed.bytesPerSecond == 1_000)
    }

    @Test func laterSamplesBlendQuarterNewThreeQuartersOld() {
        var speed = TransferSpeed()
        speed.record(0, at: start)
        speed.record(1_000, at: start.addingTimeInterval(1))
        speed.record(3_000, at: start.addingTimeInterval(2))
        // Instant 2000 B/s: 0.25 * 2000 + 0.75 * 1000.
        #expect(speed.bytesPerSecond == 1_250)
    }

    /// A tick closer than 0.2 s to the last sample is dropped, not averaged, and
    /// does not move the baseline.
    @Test(arguments: [0.05, 0.19])
    func aTickWithinTheGuardIsIgnored(gap: Double) {
        var speed = TransferSpeed()
        speed.record(0, at: start)
        speed.record(1_000, at: start.addingTimeInterval(gap))
        #expect(speed.bytesPerSecond == 0)

        speed.record(1_000, at: start.addingTimeInterval(1))
        #expect(speed.bytesPerSecond == 1_000, "measured from the first tick, not the dropped one")
    }

    @Test(arguments: [0.21, 1.0])
    func aTickPastTheGuardIsSampled(gap: Double) {
        var speed = TransferSpeed()
        speed.record(0, at: start)
        speed.record(1_000, at: start.addingTimeInterval(gap))
        #expect(speed.bytesPerSecond > 0)
    }
}

/// `TransferHaptic`: which phase changes buzz, and which stay silent.
@Suite struct TransferHapticTests {
    private let failure = TransferFailure(title: "T", detail: nil, remedy: nil)

    @Test func aFinishedTransferIsSuccessOrFailure() {
        #expect(TransferHaptic(.done(testSummary(success: true), receivedText: nil)) == .completed)
        #expect(TransferHaptic(.done(testSummary(success: false), receivedText: nil)) == .failed)
    }

    @Test func aFailureIsAnErrorUnlessTheUserEndedIt() {
        #expect(TransferHaptic(.failed(failure)) == .failed)
        #expect(TransferHaptic(.failed(TransferFailure.cancelledByUser)) == nil)
        #expect(TransferHaptic(.failed(TransferFailure.declinedByUser)) == nil)
    }

    @Test func aRequestForAnAnswerIsAWarning() throws {
        let list = try JSONDecoder().decode(
            FileList.self,
            from: Data(
                #"{"files":[{"name":"a.txt","size":10}],"emptyFolders":0,"totalSize":10}"#.utf8))
        #expect(TransferHaptic(.incoming(list, conflicts: [], blocked: [])) == .incoming)
    }

    @Test func everyOtherPhaseIsSilent() {
        let silent: [TransferController.Phase] = [
            .idle, .starting, .waiting(code: "wiry-alpha-bravo"), .connecting, .confirmSend,
            .transferring,
        ]
        for phase in silent { #expect(TransferHaptic(phase) == nil, "\(phase)") }
    }

    @Test func eachEventHasItsOwnFeedback() {
        #expect(TransferHaptic.completed.feedback == .success)
        #expect(TransferHaptic.failed.feedback == .error)
        #expect(TransferHaptic.incoming.feedback == .warning)
    }
}

/// The Shortcuts side of `TransferController` (`TransferIntentSupport`).
@MainActor @Suite struct TransferIntentSupportTests {
    private let engine = FakeTransferEngine()
    private let controller: TransferController

    /// Never created, like the file in `TransferControllerTests`.
    private let file = URL(filePath: "/CrocAppTests.missing/notes.txt")
    private static let code = "wiry-alpha-bravo"

    init() {
        let settings = AppSettings(storage: MemorySettingsStorage(), secrets: FakeSecretStore())
        controller = TransferController(
            settings: settings, vault: StoredTransferVault(secrets: FakeSecretStore()),
            engine: engine)
    }

    // MARK: - claimForIntent

    @Test func anIdleControllerIsClaimed() throws {
        try controller.claimForIntent()
        #expect(controller.phase == .idle)
    }

    @Test func aTransferInFlightRefusesTheAction() {
        #expect(controller.start(.sendFiles(urls: [file], code: "")))
        #expect(controller.phase == .starting)

        #expect(throws: TransferIntentError.self) { try controller.claimForIntent() }
        #expect(controller.phase == .starting, "the refused action leaves the transfer alone")
    }

    @Test func aFinishedTransferIsClearedForTheAction() async throws {
        #expect(controller.start(.sendFiles(urls: [file], code: "")))
        try await waitUntil("the transfer to start") { await engine.isDrained }
        try await deliver(.failed(EngineFailure(code: .refused, message: "refused files")))
        try #require(controller.phase.isTerminal)

        try controller.claimForIntent()
        #expect(controller.phase == .idle)
    }

    // MARK: - awaitCode

    @Test func awaitCodeReturnsTheCodeOfAHeldSend() async throws {
        await engine.holdNextStart()
        #expect(controller.start(.sendFiles(urls: [file], code: "")))
        let waiting = Task { try await controller.awaitCode() }
        try await waitUntil("the start to be held") { await engine.isHoldingStart }

        await engine.releaseStart()
        try await waitUntil("the transfer to start") { await engine.isDrained }
        try await deliver(.codeReady(Self.code))

        #expect(try await waiting.value == Self.code)
    }

    @Test func awaitCodeThrowsTheFailureOfASendThatFails() async throws {
        #expect(controller.start(.sendFiles(urls: [file], code: "")))
        let waiting = Task { try await controller.awaitCode() }
        try await waitUntil("the transfer to start") { await engine.isDrained }
        try await deliver(.failed(EngineFailure(code: .refused, message: "refused files")))

        await #expect(throws: TransferIntentError.self) { try await waiting.value }
    }

    /// Cancelling the action also stops the transfer it started.
    @Test func cancellingAwaitCodeCancelsTheSend() async throws {
        await engine.holdNextStart()
        #expect(controller.start(.sendFiles(urls: [file], code: "")))
        let waiting = Task { try await controller.awaitCode() }
        try await waitUntil("the start to be held") { await engine.isHoldingStart }

        waiting.cancel()

        do {
            _ = try await waiting.value
            Issue.record("a cancelled awaitCode returned a code")
        } catch TransferIntentError.cancelled {
        } catch {
            Issue.record("threw \(error), not .cancelled")
        }
        await engine.releaseStart()
        try await waitUntil("the cancelled start to be seen") {
            await engine.cancelledStarts == 1
        }
    }

    // MARK: - awaitReceive

    @Test func awaitReceiveReturnsTheReceivedText() async throws {
        #expect(controller.start(.receive(code: Self.code, folder: folder, folderIsScoped: false)))
        let waiting = Task { try await controller.awaitReceive() }
        try await waitUntil("the transfer to start") { await engine.isDrained }

        try await deliver(.text("hello"))
        try await deliver(.done(try summary()))

        #expect(try await waiting.value == "hello")
    }

    @Test func awaitReceiveThrowsTheFailureOfAReceiveThatFails() async throws {
        #expect(controller.start(.receive(code: Self.code, folder: folder, folderIsScoped: false)))
        let waiting = Task { try await controller.awaitReceive() }
        try await waitUntil("the transfer to start") { await engine.isDrained }
        try await deliver(.failed(EngineFailure(code: .refused, message: "refused files")))

        await #expect(throws: TransferIntentError.self) { try await waiting.value }
    }

    // MARK: - Helpers

    private let folder = FileManager.default.temporaryDirectory.appending(
        path: "CrocAppTests.\(UUID().uuidString)")

    private func summary() throws -> Summary {
        try JSONDecoder().decode(
            Summary.self, from: Data(#"{"success":true,"files":0,"totalSize":0}"#.utf8))
    }

    private func waitUntil(
        _ what: String, sourceLocation: SourceLocation = #_sourceLocation,
        _ condition: () async -> Bool
    ) async throws {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: .seconds(30))
        var met = await condition()
        while !met, clock.now < deadline {
            try await Task.sleep(for: .milliseconds(5))
            met = await condition()
        }
        try #require(met, "timed out waiting for \(what)", sourceLocation: sourceLocation)
    }

    /// Emits `event` and waits until the controller has handled it.
    private func deliver(
        _ event: TransferEvent, sourceLocation: SourceLocation = #_sourceLocation
    ) async throws {
        await engine.emit(event)
        try await waitUntil("the controller to handle \(event)", sourceLocation: sourceLocation) {
            await engine.isDrained
        }
    }
}

extension TransferController.Phase {
    fileprivate var isTerminal: Bool {
        switch self {
        case .done, .failed, .stored: true
        default: false
        }
    }
}
