import Foundation
import Testing

@testable import CrocKit

/// The store entry points through the real Go engine: what Go refuses before it
/// touches the network arrives as `CrocEngineError.startFailed` with its code.
@Suite struct StoreEngineTests {
    private func startFailure(_ start: () async throws -> EngineTransfer) async -> EngineFailure? {
        do {
            _ = try await start()
            return nil
        } catch CrocEngineError.startFailed(let failure) {
            return failure
        } catch {
            Issue.record("unexpected error \(error)")
            return nil
        }
    }

    @Test func plainHTTPServerIsRefused() async {
        var options = StoredSendOptions()
        options.server = "http://example.com"
        let engine = CrocEngine()
        let failure = await startFailure {
            try await engine.startStoreSend(paths: [NSTemporaryDirectory()], options: options)
        }
        #expect(failure?.code == .other)
    }

    @Test(arguments: [101, -1])
    func downloadsOutsideTheRangeAreStoreLimit(downloads: Int) async throws {
        let file = FileManager.default.temporaryDirectory.appending(path: "store-\(UUID()).txt")
        try Data("x".utf8).write(to: file)
        defer { try? FileManager.default.removeItem(at: file) }
        var options = StoredSendOptions()
        options.downloads = downloads
        let engine = CrocEngine()
        let failure = await startFailure {
            try await engine.startStoreSend(paths: [file.path], options: options)
        }
        #expect(failure?.code == .storeLimit)
    }

    @Test func badLinkIsRefused() async {
        let engine = CrocEngine()
        let failure = await startFailure {
            try await engine.startStoreReceive(link: "not a link", outDir: NSTemporaryDirectory())
        }
        #expect(failure?.code == .other)
    }

    @Test func revokeFailureThrowsEngineFailure() async {
        let receipt = StoredReceipt(
            id: "AAAAAAAAAAAAAAAAAAAAAA", origin: "http://127.0.0.1:1", uploadToken: "t",
            link: "", expiresAt: .now, downloads: 1)
        await #expect(throws: EngineFailure.self) {
            try await CrocEngine().revokeStored(receipt)
        }
    }
}
