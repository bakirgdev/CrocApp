import Foundation
import Testing

@testable import CrocKit

/// The Go side splits the joined path list on "\n", so a path carrying a line
/// break would become several send paths ("a.jpg\n.." sends the parent folder).
@Suite struct SendPathValidationTests {
    private func isRefused(_ start: () async throws -> EngineTransfer) async -> Bool {
        do {
            _ = try await start()
            return false
        } catch CrocEngineError.startFailed(let failure) {
            return failure.code == .invalidSetting
        } catch {
            return false
        }
    }

    @Test(arguments: ["photo.jpg\n..", "a\rb", "/tmp/a\r\nb", "\n"])
    func sendRefusesLineBreakInPath(path: String) async {
        let engine = CrocEngine()
        let refused = await isRefused {
            try await engine.startSend(paths: ["/tmp/ok.txt", path], text: nil, options: .init())
        }
        #expect(refused)
    }

    @Test(arguments: ["photo.jpg\n..", "a\rb", "/tmp/a\r\nb", "\n"])
    func storeSendRefusesLineBreakInPath(path: String) async {
        let engine = CrocEngine()
        let refused = await isRefused {
            try await engine.startStoreSend(paths: [path], options: StoredSendOptions())
        }
        #expect(refused)
    }
}
