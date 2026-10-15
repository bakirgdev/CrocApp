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
            try await engine.startStoreReceive(
                link: "not a link", outDir: NSTemporaryDirectory(), proxy: ProxySettings())
        }
        #expect(failure?.code == .other)
    }

    @Test func revokeFailureThrowsEngineFailure() async {
        let receipt = StoredReceipt(
            id: "AAAAAAAAAAAAAAAAAAAAAA", origin: "http://127.0.0.1:1", uploadToken: "t",
            link: "", expiresAt: .now, downloads: 1)
        await #expect(throws: EngineFailure.self) {
            try await CrocEngine().revokeStored(receipt, proxy: ProxySettings())
        }
    }

    /// A bad proxy is refused before any network use, with the engine's code
    /// and without the credentials in the error text.
    @Test func badProxyIsInvalidSetting() async {
        let file = FileManager.default.temporaryDirectory.appending(path: "store-\(UUID()).txt")
        try? Data("x".utf8).write(to: file)
        defer { try? FileManager.default.removeItem(at: file) }
        var options = StoredSendOptions()
        options.proxy = ProxySettings(socks5: "http://user:secret@proxy.example:1080")
        let engine = CrocEngine()
        let failure = await startFailure {
            try await engine.startStoreSend(paths: [file.path], options: options)
        }
        #expect(failure?.code == .invalidSetting)
        #expect(failure?.message.contains("secret") == false)
    }

    @Test func badProxyFailsReceiveAndRevoke() async {
        let bad = ProxySettings(http: "socks5://user:secret@proxy.example:3128")
        let engine = CrocEngine()
        let failure = await startFailure {
            try await engine.startStoreReceive(
                link:
                    "https://getcroc.com/s/AAAAAAAAAAAAAAAAAAAAAA#v1.AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA",
                outDir: NSTemporaryDirectory(), proxy: bad)
        }
        #expect(failure?.code == .invalidSetting)
        let receipt = StoredReceipt(
            id: "AAAAAAAAAAAAAAAAAAAAAA", origin: "http://127.0.0.1:1", uploadToken: "t",
            link: "", expiresAt: .now, downloads: 1)
        do {
            try await engine.revokeStored(receipt, proxy: bad)
            Issue.record("revoke with a bad proxy succeeded")
        } catch let failure as EngineFailure {
            #expect(failure.code == .invalidSetting)
            #expect(!failure.message.contains("secret"))
        } catch {
            Issue.record("unexpected error \(error)")
        }
    }
}
