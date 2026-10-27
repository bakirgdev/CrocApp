import CrocKit
import Foundation
import Testing

@testable import CrocApp

/// The logic behind the History screens: how a date is written, what a search
/// matches, and that a revoke runs once and clears its in-progress flag.
@MainActor @Suite struct HistoryTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private let calendar = Calendar(identifier: .gregorian)

    private func record(
        names: [String] = [], isText: Bool = false, storedID: String? = nil,
        expiresAt: Date? = nil
    ) -> TransferRecord {
        TransferRecord(
            isSend: true, status: .completed, isText: isText, fileCount: max(names.count, 1),
            totalBytes: 1, names: names, codeHint: "wiry-…", bookmarks: [], storedID: storedID,
            expiresAt: expiresAt)
    }

    // MARK: - Dates (design/content.md → Dates)

    @Test func aDateInsideTheLastWeekIsRelative() {
        let sixDays = now.addingTimeInterval(-6 * 24 * 3600)
        #expect(sixDays.isWithinAWeek(of: now, calendar: calendar))
        #expect(now.isWithinAWeek(of: now, calendar: calendar))
    }

    @Test func aDateOlderThanAWeekIsAbsolute() {
        let eightDays = now.addingTimeInterval(-8 * 24 * 3600)
        #expect(!eightDays.isWithinAWeek(of: now, calendar: calendar))
    }

    @Test func aDateAfterNowCountsAsRecent() {
        #expect(now.addingTimeInterval(3600).isWithinAWeek(of: now, calendar: calendar))
    }

    /// Gregorian, UTC and en_US, so the words do not follow the host.
    private var englishCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.locale = Locale(identifier: "en_US")
        return calendar
    }

    @Test func aRecentDateReadsRelative() {
        let calendar = englishCalendar
        let day: TimeInterval = 24 * 3600
        #expect(now.addingTimeInterval(-day).recordText(now: now, calendar: calendar) == "yesterday")
        #expect(
            now.addingTimeInterval(-3 * day).recordText(now: now, calendar: calendar)
                == "3 days ago")
    }

    @Test func anOlderDateReadsAbsoluteAndNamesTheYearOnlyWhenItIsNotThisYear() {
        let calendar = englishCalendar
        let day: TimeInterval = 24 * 3600
        // `now` is 15 January 2027.
        #expect(now.addingTimeInterval(-8 * day).recordText(now: now, calendar: calendar) == "Jan 7")
        #expect(
            now.addingTimeInterval(-20 * day).recordText(now: now, calendar: calendar)
                == "Dec 26, 2026")
    }

    // MARK: - Search

    @Test func searchMatchesPartOfAFileName() {
        let report = record(names: ["Quarterly-Report.pdf", "Notes.md"])
        #expect(report.matches(search: "report"))
        #expect(report.matches(search: "NOTES"))
        #expect(!report.matches(search: "budget"))
    }

    @Test func searchIgnoresDiacriticsAndOuterSpaces() {
        #expect(record(names: ["Résumé.pdf"]).matches(search: " resume "))
    }

    @Test func aBlankSearchMatchesEveryRecord() {
        #expect(record(names: ["a.txt"]).matches(search: ""))
        #expect(record(names: ["a.txt"]).matches(search: "   "))
        #expect(record(isText: true).matches(search: ""))
    }

    @Test func aRecordWithNoNamesMatchesNoSearch() {
        #expect(!record(isText: true).matches(search: "text"))
    }

    // MARK: - Revoke

    private func revokableSetup(
        engine: FakeTransferEngine
    ) -> (TransferController, TransferRecord) {
        let vault = StoredTransferVault(secrets: FakeSecretStore(), now: now)
        vault.add(
            StoredReceipt(
                id: "a", origin: "https://getcroc.com", uploadToken: "token-a",
                link: "https://getcroc.com/s/a#v1.key-a",
                expiresAt: Date.now.addingTimeInterval(3600), downloads: 1))
        let controller = TransferController(
            settings: AppSettings(storage: MemorySettingsStorage(), secrets: FakeSecretStore()),
            vault: vault, engine: engine)
        controller.history = HistoryStore(container: HistoryStore.makeContainer(inMemory: true))
        let record = record(
            names: ["a.txt"], storedID: "a", expiresAt: Date.now.addingTimeInterval(3600))
        controller.history?.add(record)
        return (controller, record)
    }

    @Test func revokeMarksTheRecordAndClearsItsProgress() async {
        let engine = FakeTransferEngine()
        let (controller, record) = revokableSetup(engine: engine)
        let actions = HistoryActions()

        let failure = await actions.revoke(record, with: controller)

        #expect(failure == nil)
        #expect(record.revokedAt != nil)
        #expect(!actions.isRevoking(record))
        #expect(await engine.revokes.count == 1)
    }

    @Test func aSecondRevokeWhileOneRunsDoesNotReachTheEngine() async {
        let engine = FakeTransferEngine()
        let (controller, record) = revokableSetup(engine: engine)
        let actions = HistoryActions()

        async let first = actions.revoke(record, with: controller)
        async let second = actions.revoke(record, with: controller)
        let failures = await [first, second]

        #expect(failures == [nil, nil])
        #expect(await engine.revokes.count == 1)
    }
}
