import CrocKit
import Foundation
import Testing

@testable import CrocApp

/// What the history record of a receive keeps from the sender's offer.
@MainActor @Suite struct HistoryDraftTests {
    private static let folder = URL(filePath: "/CrocAppTests.missing")

    private func receiveDraft() -> HistoryDraft {
        HistoryDraft(
            .receive(code: "wiry-alpha-bravo", folder: Self.folder, folderIsScoped: false),
            storedServer: "")
    }

    private func fileList(_ names: [String]) throws -> FileList {
        let object: [String: Any] = [
            "files": names.map { ["name": $0, "size": 10] as [String: Any] },
            "emptyFolders": 0, "totalSize": 10 * names.count,
        ]
        return try JSONDecoder().decode(
            FileList.self, from: JSONSerialization.data(withJSONObject: object))
    }

    @Test func anOfferStoresNamesInTheirShownForm() throws {
        var draft = receiveDraft()
        draft.offer(try fileList(["invoice\u{202E}fdp.exe", "a\nb.txt", "plain.txt"]))

        #expect(draft.names == ["invoice\\u{202E}fdp.exe", "a\\u{000A}b.txt", "plain.txt"])
        #expect(draft.fileCount == 3)
        #expect(draft.totalBytes == 30)
    }

    @Test func aShownNameReachesTheRecord() throws {
        var draft = receiveDraft()
        draft.offer(try fileList(["x\u{2028}y"]))

        let record = draft.record(status: .failed, summary: nil, receivedText: nil)

        #expect(record.names == ["x\\u{2028}y"])
        #expect(!record.isSend)
    }

    @Test func anOfferKeepsOnlyTheFirstNames() throws {
        var draft = receiveDraft()
        let names = (0..<(TransferRecord.maxNames + 5)).map { "f\($0).txt" }
        draft.offer(try fileList(names))

        #expect(draft.names.count == TransferRecord.maxNames)
        #expect(draft.fileCount == names.count)
    }
}
