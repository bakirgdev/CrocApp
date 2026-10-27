import AppIntents
import CoreSpotlight
import Foundation
import SwiftData
import Testing

@testable import CrocApp

/// How a `TransferRecord` becomes the entity Shortcuts and Spotlight see:
/// the words, the id, and what must never be in it.
@MainActor @Suite struct HistoryEntityTests {
    private static let hint = "wiry-…"

    private func entity(
        isSend: Bool = true, status: TransferRecord.Status = .completed, isText: Bool = false,
        fileCount: Int = 1, totalBytes: Int64 = 24_000_000, names: [String] = ["report.pdf"],
        date: Date = Date(timeIntervalSince1970: 1_700_000_000)
    ) -> HistoryEntity {
        HistoryEntity(
            id: "id", isSend: isSend, status: status, isText: isText, fileCount: fileCount,
            totalBytes: totalBytes, names: names, date: date)
    }

    // MARK: - The words

    @Test func aSingleFileIsNamedByItsFile() {
        #expect(entity().name == "report.pdf")
    }

    @Test func severalFilesAreNamedByTheFirstPlusTheRest() {
        #expect(
            entity(fileCount: 3, names: ["a.txt", "b.txt", "c.txt"]).name == "a.txt + 2 more")
    }

    @Test func aTextSendIsATextSnippet() {
        #expect(entity(isText: true, names: []).name == "Text snippet")
    }

    @Test func aTransferWithNoNamesFallsBackToItsDirection() {
        #expect(entity(isSend: true, names: []).name == "Sent files")
        #expect(entity(isSend: false, names: []).name == "Received files")
    }

    @Test func theSummaryNamesDirectionStatusAndSize() {
        #expect(entity().summary == "Sent • 24 MB")
        #expect(entity(isSend: false, status: .failed).summary == "Received • Failed • 24 MB")
        #expect(entity(status: .declined, totalBytes: 0).summary == "Sent • Declined")
    }

    @Test func directionStatusDateAndSizeCarryOver() {
        let found = entity(
            isSend: false, status: .cancelled, totalBytes: 2_000,
            date: Date(timeIntervalSince1970: 5))
        #expect(found.direction == .received)
        #expect(found.status == .cancelled)
        #expect(found.date == Date(timeIntervalSince1970: 5))
        #expect(found.size == Measurement(value: 2_000, unit: .bytes))
    }

    // MARK: - Search

    @Test func aSearchFindsAnyFileOfTheTransferIgnoringCase() {
        let found = entity(fileCount: 2, names: ["Holiday.jpg", "Résumé.pdf"])
        #expect(found.matches("holiday"))
        #expect(found.matches("resume"))
        #expect(!found.matches("invoice"))
    }

    @Test func anEmptySearchMatchesEverything() {
        #expect(entity().matches("  "))
    }

    // MARK: - What never leaves the app

    @Test func neitherTheCodeHintNorTheCodeReachesTheEntityOrItsIndexEntry() throws {
        let store = HistoryStore(container: HistoryStore.makeContainer(inMemory: true))
        let record = TransferRecord(
            isSend: true, status: .completed, isText: false, fileCount: 1, totalBytes: 10,
            names: ["report.pdf"], codeHint: Self.hint, bookmarks: [Data("bookmark".utf8)])
        store.add(record)
        let found = try #require(HistoryEntity(record: record))

        let attributes = found.attributeSet
        var seen = [found.id, found.name, found.summary] + found.fileNames
        seen += [attributes.title, attributes.displayName, attributes.contentDescription].compactMap(
            \.self)
        seen += attributes.keywords ?? []
        #expect(seen.contains("report.pdf"))
        for text in seen {
            #expect(!text.contains("wiry"), "a code hint reached \(text)")
            #expect(!text.contains("bookmark"))
        }
    }

    @Test func theIndexEntryCarriesTheNameSummaryFileNamesAndDate() {
        let found = entity(fileCount: 2, names: ["a.txt", "b.txt"])
        let attributes = found.attributeSet
        #expect(attributes.title == "a.txt + 1 more")
        #expect(attributes.contentDescription == "Sent • 24 MB")
        #expect(attributes.keywords == ["a.txt", "b.txt"])
        #expect(attributes.contentCreationDate == found.date)
    }

    // MARK: - The id

    @Test func theIdOfASavedRecordFindsItAgain() throws {
        let history = HistoryStore(container: HistoryStore.makeContainer(inMemory: true))
        let record = TransferRecord(
            isSend: false, status: .completed, isText: false, fileCount: 1, totalBytes: 1,
            names: ["x"], codeHint: "", bookmarks: [])
        history.add(record)
        let found = try #require(HistoryEntity(record: record))
        let identifier = try #require(HistoryEntityID.identifier(from: found.id))
        #expect(identifier == record.persistentModelID)
    }

    @Test func textThatIsNotAnIdFindsNothing() {
        #expect(HistoryEntityID.identifier(from: "not an id") == nil)
        #expect(HistoryEntityID.identifier(from: "") == nil)
    }
}
