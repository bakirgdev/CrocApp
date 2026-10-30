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

    // MARK: - Dates (design/voice.md → Dates)

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
        #expect(
            now.addingTimeInterval(-day).recordText(now: now, calendar: calendar) == "yesterday")
        #expect(
            now.addingTimeInterval(-3 * day).recordText(now: now, calendar: calendar)
                == "3 days ago")
    }

    @Test func anOlderDateReadsAbsoluteAndNamesTheYearOnlyWhenItIsNotThisYear() {
        let calendar = englishCalendar
        let day: TimeInterval = 24 * 3600
        // `now` is 15 January 2027.
        #expect(
            now.addingTimeInterval(-8 * day).recordText(now: now, calendar: calendar) == "Jan 7")
        #expect(
            now.addingTimeInterval(-20 * day).recordText(now: now, calendar: calendar)
                == "Dec 26, 2026")
    }

    @Test func theWeekBoundaryIsAbsoluteAndTheSecondBeforeItIsRelative() {
        let calendar = englishCalendar
        // `now` is 15 January 2027, so a week back is 8 January.
        let weekAgo = now.addingTimeInterval(-7 * 24 * 3600)
        #expect(!weekAgo.isWithinAWeek(of: now, calendar: calendar))
        #expect(weekAgo.addingTimeInterval(1).isWithinAWeek(of: now, calendar: calendar))
        #expect(weekAgo.recordText(now: now, calendar: calendar) == "Jan 8")
        #expect(weekAgo.addingTimeInterval(1).recordText(now: now, calendar: calendar) != "Jan 8")
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

        let first = Task { await actions.revoke(record, with: controller) }
        let second = Task { await actions.revoke(record, with: controller) }
        let failures = await [first.value, second.value]

        #expect(failures == [nil, nil])
        #expect(await engine.revokes.count == 1)
    }

    @Test func revokingARecordDeletedMidwayNeitherCrashesNorMarksIt() async throws {
        let engine = FakeTransferEngine()
        let (controller, record) = revokableSetup(engine: engine)
        let history = try #require(controller.history)
        let actions = HistoryActions()
        await engine.holdNextRevoke()

        let revoke = Task { await actions.revoke(record, with: controller) }
        while !(await engine.isHoldingRevoke) { await Task.yield() }
        #expect(actions.isRevoking(record))
        history.delete(record)
        await engine.releaseRevoke()

        #expect(await revoke.value == nil)
        #expect(record.revokedAt == nil)
        #expect(!actions.isRevoking(record))
        #expect(history.recordCount() == 0)
        // A second delete of the gone record is a no-op too.
        history.delete(record)
    }

    // MARK: - Send Again

    private func resendRecord(bookmarks: [Data]) -> TransferRecord {
        TransferRecord(
            isSend: true, status: .completed, isText: false, fileCount: 1, totalBytes: 1,
            names: ["a.txt"], codeHint: "wiry-…", bookmarks: bookmarks)
    }

    private func temporaryFile() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appending(path: "CrocAppResend-\(UUID().uuidString).txt")
        try Data("hi".utf8).write(to: url)
        return url
    }

    @Test func sendAgainWithNoBookmarkReturnsFalseAndStagesNothing() {
        let router = AppRouter()
        let record = resendRecord(bookmarks: [])

        #expect(!HistoryActions().resend(record, router: router))
        #expect(router.pendingSendURLs.isEmpty)
        #expect(router.path.isEmpty)
    }

    @Test func sendAgainWithAnUnresolvableBookmarkReturnsFalseAndStagesNothing() {
        let router = AppRouter()
        let record = resendRecord(bookmarks: [Data("not a bookmark".utf8)])

        #expect(!HistoryActions().resend(record, router: router))
        #expect(router.pendingSendURLs.isEmpty)
    }

    @Test func sendAgainWithADeletedOriginalReturnsFalseAndStagesNothing() throws {
        let url = try temporaryFile()
        let bookmark = try #require(SecurityScopedBookmark.create(for: url))
        try FileManager.default.removeItem(at: url)
        let router = AppRouter()

        #expect(!HistoryActions().resend(resendRecord(bookmarks: [bookmark]), router: router))
        #expect(router.pendingSendURLs.isEmpty)
    }

    @Test func sendAgainWithAReachableOriginalOpensSend() throws {
        let url = try temporaryFile()
        defer { try? FileManager.default.removeItem(at: url) }
        let bookmark = try #require(SecurityScopedBookmark.create(for: url))
        let router = AppRouter()

        #expect(HistoryActions().resend(resendRecord(bookmarks: [bookmark]), router: router))
        #expect(router.pendingSendURLs.map(\.lastPathComponent) == [url.lastPathComponent])
        #expect(router.path == [.send])
    }
}
