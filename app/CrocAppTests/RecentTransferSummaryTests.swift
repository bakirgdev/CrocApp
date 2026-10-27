import Foundation
import Testing

@testable import CrocApp

/// What a Home recent-transfers row says about its record (design/components.md
/// → Home, "Recent transfers"; design/content.md → Dates).
@MainActor @Suite struct RecentTransferSummaryTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US")
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    /// Tuesday 27 October 2026, noon.
    private var now: Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: 27, hour: 12))!
    }

    private func summary(
        send: Bool = true, status: TransferRecord.Status = .completed, text: Bool = false,
        files: Int = 1, names: [String] = ["Report.pdf"], ago: TimeInterval = 26 * 3600
    ) -> RecentTransferSummary {
        let record = TransferRecord(
            isSend: send, status: status, isText: text, fileCount: files, totalBytes: 1_000,
            names: names, codeHint: "wiry-…", bookmarks: [])
        record.date = now.addingTimeInterval(-ago)
        return RecentTransferSummary(record, now: now, calendar: calendar)
    }

    // MARK: Title

    @Test func oneFileShowsItsName() {
        #expect(summary().title == "Report.pdf")
    }

    @Test func severalFilesShowACount() {
        #expect(summary(files: 3, names: ["a", "b", "c"]).title == "3 files")
    }

    @Test func aTextSendIsATextSnippet() {
        #expect(summary(text: true, names: []).title == "Text snippet")
    }

    @Test func aRecordWithoutNamesFallsBackToItsDirection() {
        #expect(summary(send: true, names: []).title == "Sent files")
        #expect(summary(send: false, names: []).title == "Received files")
    }

    // MARK: Status word

    @Test func aCompletedRecordHasNoStatusWord() {
        #expect(summary(status: .completed).statusWord == nil)
    }

    @Test(arguments: [
        (TransferRecord.Status.failed, "Failed"),
        (.cancelled, "Cancelled"),
        (.declined, "Declined"),
    ])
    func aRecordThatDidNotCompleteLeadsWithItsStatus(
        status: TransferRecord.Status, word: String
    ) {
        #expect(summary(status: status).statusWord == word)
    }

    // MARK: Date

    @Test(arguments: [
        (TimeInterval(12 * 60), "12 minutes ago"),
        (TimeInterval(26 * 3600), "yesterday"),
        (TimeInterval(3 * 24 * 3600), "3 days ago"),
    ])
    func aDateInsideAWeekIsRelative(ago: TimeInterval, text: String) {
        #expect(summary(ago: ago).dateText == text)
    }

    @Test func aDateOlderThanAWeekIsAShortAbsoluteDate() {
        #expect(summary(ago: 10 * 24 * 3600).dateText == "Oct 17")
    }

    @Test func aDateFromAnotherYearCarriesTheYear() {
        #expect(summary(ago: 365 * 24 * 3600).dateText == "Oct 27, 2025")
    }

    // MARK: Spoken label

    @Test func aFinishedSendIsSpokenAsOneLabel() {
        #expect(
            summary(files: 3, names: ["a", "b", "c"]).spokenLabel == "Sent 3 files, yesterday")
    }

    @Test func aFinishedReceiveIsSpokenAsOneLabel() {
        #expect(summary(send: false).spokenLabel == "Received Report.pdf, yesterday")
    }

    @Test func aRecordThatDidNotCompleteSaysSoInTheLabel() {
        #expect(
            summary(send: false, status: .declined).spokenLabel
                == "Declined, receiving Report.pdf, yesterday")
    }
}
