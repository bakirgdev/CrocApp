import CrocKit
import Foundation
import Testing

@testable import CrocApp

@MainActor @Suite struct TransferSnapshotTests {
    private let settings = AppSettings(
        storage: MemorySettingsStorage(), secrets: FakeSecretStore())
    private let controller: TransferController
    private let directory: URL
    private let store: TransferSnapshotStore
    private var reloads = Counter()
    private let date = Date(timeIntervalSince1970: 1_000)

    private final class Counter { var count = 0 }

    init() throws {
        controller = TransferController(
            settings: settings, vault: StoredTransferVault(secrets: FakeSecretStore()),
            engine: FakeTransferEngine())
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("snapshot-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        store = TransferSnapshotStore(directory: directory)
    }

    private func writer() -> TransferSnapshotWriter {
        let reloads = reloads
        return TransferSnapshotWriter(
            controller: controller, settings: settings, store: store,
            reload: { reloads.count += 1 }, now: { date })
    }

    @Test func fileNamesAreOffByDefault() {
        #expect(!settings.systemSurfacesShowFileNames)
    }

    @Test func aNameAppearsOnlyForOneItemWithTheSwitchOn() {
        #expect(TransferSnapshot.name(from: ["a.pdf"], showNames: true) == "a.pdf")
        #expect(TransferSnapshot.name(from: ["a.pdf"], showNames: false) == nil)
        #expect(TransferSnapshot.name(from: ["a", "b"], showNames: true) == nil)
        #expect(TransferSnapshot.name(from: [], showNames: true) == nil)
    }

    @Test func onlyFinishedPhasesMakeASnapshot() {
        func outcome(_ phase: TransferController.Phase) -> TransferSnapshot.Outcome? {
            TransferSnapshotWriter.snapshot(
                for: phase, direction: .send, names: [], showNames: false, date: date)?.outcome
        }
        #expect(outcome(.done(testSummary(success: true), receivedText: nil)) == .done)
        #expect(outcome(.done(testSummary(success: false), receivedText: nil)) == .failed)
        #expect(outcome(.waiting(code: "1234-secret-code")) == nil)
        #expect(outcome(.transferring) == nil)
        #expect(outcome(.idle) == nil)
    }

    @Test func theStoreRoundTripsAndClears() throws {
        let snapshot = TransferSnapshot(
            direction: .receive, outcome: .done, itemCount: 1, name: "a.pdf", date: date)
        try store.write(snapshot)
        #expect(store.read() == snapshot)
        try store.clear()
        #expect(store.read() == nil)
        try store.clear()
    }

    @Test func aFinishedTransferIsWrittenWithoutAName() {
        let writer = writer()
        writer.handle(
            phase: .done(testSummary(success: true), receivedText: nil), saveHistory: true,
            showNames: false)
        #expect(store.read()?.outcome == .done)
        #expect(store.read()?.name == nil)
        #expect(reloads.count == 1)
    }

    @Test func aRunningTransferNeverReachesTheFile() {
        let writer = writer()
        writer.handle(phase: .waiting(code: "1234-secret-code"), saveHistory: true, showNames: true)
        writer.handle(phase: .transferring, saveHistory: true, showNames: true)
        #expect(store.read() == nil)
        #expect(reloads.count == 0)
    }

    @Test func historyOffDeletesTheFile() {
        let writer = writer()
        writer.handle(
            phase: .done(testSummary(success: true), receivedText: nil), saveHistory: true,
            showNames: false)
        writer.handle(
            phase: .done(testSummary(success: true), receivedText: nil), saveHistory: false,
            showNames: false)
        #expect(store.read() == nil)
        writer.handle(
            phase: .done(testSummary(success: true), receivedText: nil), saveHistory: false,
            showNames: false)
        #expect(store.read() == nil)
    }
}
