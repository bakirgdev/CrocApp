import CrocKit
import Foundation

/// What the history record of the transfer in flight will hold. Filled in as
/// events arrive, and turned into a `TransferRecord` at the terminal event.
struct HistoryDraft {
    var isSend: Bool
    var isText: Bool
    var names: [String] = []
    var fileCount = 0
    var totalBytes: Int64 = 0
    var codeHint: String
    var bookmarks: [Data] = []
    var storedID: String?
    var expiresAt: Date?

    /// `storedServer` is the link server a stored send uploads to.
    init(_ request: TransferRequest, storedServer: String) {
        switch request {
        case .sendFiles(let urls, let code):
            self.init(sending: urls, codeHint: CodeHint.code(code))
        case .storedSend(let urls, _, _):
            self.init(
                sending: urls, codeHint: URL(string: storedServer).map(CodeHint.storedLink) ?? "")
        case .sendText(_, let code):
            self.init(isSend: true, isText: true, codeHint: CodeHint.code(code))
        case .receive(let code, _, _):
            self.init(isSend: false, isText: false, codeHint: CodeHint.code(code))
        case .storedReceive(let link, _, _):
            self.init(isSend: false, isText: false, codeHint: CodeHint.storedLink(link))
        }
    }

    private init(sending urls: [URL], codeHint: String) {
        self.init(isSend: true, isText: false, codeHint: codeHint)
        names = urls.prefix(TransferRecord.maxNames).map(\.lastPathComponent)
        fileCount = urls.count
    }

    private init(isSend: Bool, isText: Bool, codeHint: String) {
        self.isSend = isSend
        self.isText = isText
        self.codeHint = codeHint
    }

    /// A receive learns its names, count and size from the offer.
    mutating func offer(_ list: FileList) {
        names = Array(list.files.map(\.name).prefix(TransferRecord.maxNames))
        fileCount = list.files.count
        totalBytes = list.totalSize
    }

    /// The record of a transfer that ended with `status`. A received text
    /// marks it as a text transfer, so call this while that text is known.
    func record(
        status: TransferRecord.Status, summary: Summary?, receivedText: String?
    ) -> TransferRecord {
        var fileCount = fileCount
        var totalBytes = totalBytes
        if let summary {
            totalBytes = summary.totalSize
            if summary.files > 0 { fileCount = summary.files }
        }
        return TransferRecord(
            isSend: isSend, status: status, isText: isText || receivedText != nil,
            fileCount: fileCount, totalBytes: totalBytes, names: names, codeHint: codeHint,
            bookmarks: bookmarks, storedID: storedID, expiresAt: expiresAt)
    }

    /// Bookmarks for every one of `urls`, or nil: a record keeps all of them
    /// or none, so Send Again hides rather than resending part of a send.
    /// Up to `maxBookmarks` (200) `bookmarkData` calls run off the main actor,
    /// so a slow volume cannot stall the send tap. The caller holds the
    /// security scope, so the URLs stay readable throughout.
    static func bookmarks(for urls: [URL]) async -> [Data]? {
        guard urls.count <= TransferRecord.maxBookmarks else { return nil }
        let all = await Task.detached(priority: .userInitiated) {
            urls.compactMap { SecurityScopedBookmark.create(for: $0) }
        }.value
        return all.count == urls.count ? all : nil
    }
}
