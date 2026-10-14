import Foundation
import SwiftData
import Testing

@testable import CrocApp

/// R19: a history written by 0.9.9 must open under the current schema with
/// every record intact. `V099` is 0.9.9's `TransferRecord` verbatim (git tag
/// `v0.9.9`, `TransferHistory.swift`); the three fields added since are
/// optional, so SwiftData migrates the store by itself.
@MainActor @Suite struct HistoryUpgradeTests {
    enum V099 {
        @Model
        final class TransferRecord {
            var date: Date
            var isSend: Bool
            var statusRaw: String
            var isText: Bool
            var fileCount: Int
            var totalBytes: Int64
            var names: [String]
            var codeHint: String
            var bookmarks: [Data]

            init(
                isSend: Bool, statusRaw: String, isText: Bool, fileCount: Int,
                totalBytes: Int64, names: [String], codeHint: String, bookmarks: [Data]
            ) {
                self.date = Date()
                self.isSend = isSend
                self.statusRaw = statusRaw
                self.isText = isText
                self.fileCount = fileCount
                self.totalBytes = totalBytes
                self.names = names
                self.codeHint = codeHint
                self.bookmarks = bookmarks
            }
        }
    }

    @Test func historyFromV099OpensWithEveryRecord() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(
            "CrocAppTests.\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("history.store")

        do {
            let old = try ModelContainer(
                for: V099.TransferRecord.self, configurations: ModelConfiguration(url: url))
            for i in 0..<5 {
                old.mainContext.insert(
                    V099.TransferRecord(
                        isSend: i.isMultiple(of: 2), statusRaw: "completed", isText: false,
                        fileCount: i + 1, totalBytes: Int64(i) * 1_000, names: ["file\(i).txt"],
                        codeHint: "word-…", bookmarks: [Data([UInt8(i)])]))
            }
            try old.mainContext.save()
        }

        // The app's own open path swallows a failure and falls back to memory,
        // so open the store directly: a migration error must fail this test.
        let current = try ModelContainer(
            for: TransferRecord.self, configurations: ModelConfiguration(url: url))
        let records = try current.mainContext.fetch(
            FetchDescriptor<TransferRecord>(sortBy: [SortDescriptor(\.fileCount)]))
        #expect(records.count == 5)
        #expect(records.map(\.names) == (0..<5).map { ["file\($0).txt"] })
        #expect(
            records.allSatisfy { $0.storedID == nil && $0.expiresAt == nil && $0.revokedAt == nil })
        #expect(records.allSatisfy { $0.bookmarks.count == 1 })
    }
}
