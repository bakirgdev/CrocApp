import SwiftData
import SwiftUI

/// What one Home recent-transfer row says about its record, kept apart from
/// the view so a test can pin the wording (design/components.md → Home).
struct RecentTransferSummary: Equatable {
    /// A date inside this window reads relative ("yesterday"); an older one
    /// reads as a short absolute date (design/content.md → Dates).
    static let relativeWindow: TimeInterval = 7 * 24 * 60 * 60

    /// The file's name, "3 files", or "Text snippet". One line: HistoryRow's
    /// "+ N more" would need a second one.
    let title: String
    /// Leads the metadata for a record that did not complete: a glyph color
    /// alone is not a status. `nil` for a completed record.
    let statusWord: String?
    let dateText: String
    /// The whole row as one VoiceOver label, "Sent 3 files, yesterday".
    let spokenLabel: String

    init(_ record: TransferRecord, now: Date = .now, calendar: Calendar = .current) {
        title = Self.title(for: record, locale: calendar.locale ?? .current)
        statusWord = record.status == .completed ? nil : record.status.word
        dateText = Self.dateText(for: record.date, now: now, calendar: calendar)
        spokenLabel = Self.spokenLabel(
            record, title: title, statusWord: statusWord, dateText: dateText)
    }

    private static func title(for record: TransferRecord, locale: Locale) -> String {
        if record.isText { return String(localized: "Text snippet") }
        if record.fileCount > 1 {
            return inflected(
                AttributedString(
                    localized: "^[\(record.fileCount) file](inflect: true)", locale: locale))
        }
        if let name = record.names.first { return name }
        return record.isSend
            ? String(localized: "Sent files") : String(localized: "Received files")
    }

    private static func dateText(for date: Date, now: Date, calendar: Calendar) -> String {
        let locale = calendar.locale ?? .current
        if now.timeIntervalSince(date) < relativeWindow {
            let formatter = RelativeDateTimeFormatter()
            formatter.calendar = calendar
            formatter.locale = locale
            formatter.dateTimeStyle = .named
            return formatter.localizedString(for: date, relativeTo: now)
        }
        var style = Date.FormatStyle(
            locale: locale, calendar: calendar, timeZone: calendar.timeZone
        )
        .month(.abbreviated).day()
        if !calendar.isDate(date, equalTo: now, toGranularity: .year) { style = style.year() }
        return date.formatted(style)
    }

    private static func spokenLabel(
        _ record: TransferRecord, title: String, statusWord: String?, dateText: String
    ) -> String {
        guard let statusWord else {
            return record.isSend
                ? String(
                    localized: "Sent \(title), \(dateText)",
                    comment:
                        "VoiceOver label of a finished send. The placeholders are what was sent and when, as in \"Sent 3 files, yesterday\"."
                )
                : String(
                    localized: "Received \(title), \(dateText)",
                    comment:
                        "VoiceOver label of a finished receive. The placeholders are what was received and when, as in \"Received 3 files, yesterday\"."
                )
        }
        return record.isSend
            ? String(
                localized: "\(statusWord), sending \(title), \(dateText)",
                comment:
                    "VoiceOver label of a send that did not finish. The placeholders are Failed, Cancelled or Declined, what was sent, and when."
            )
            : String(
                localized: "\(statusWord), receiving \(title), \(dateText)",
                comment:
                    "VoiceOver label of a receive that did not finish. The placeholders are Failed, Cancelled or Declined, what was received, and when."
            )
    }
}

extension TransferRecord.Status {
    /// The status as a word. HistoryRow keeps its own copy of these strings,
    /// private to its file.
    fileprivate var word: String {
        switch self {
        case .completed: String(localized: "Completed")
        case .failed: String(localized: "Failed")
        case .cancelled: String(localized: "Cancelled")
        case .declined: String(localized: "Declined")
        }
    }
}

/// design/components.md → Home → Recent transfers: the latest three records
/// in a grouped section, an EmptyState when there are none, nothing at all
/// while Save Transfer History is off (an empty state would promise rows
/// that never come). Rows go in a `Form`.
struct RecentTransfersSection: View {
    /// "Up to three records".
    static let limit = 3

    /// The newest `limit` records, so Home never loads the whole history.
    private static var latest: FetchDescriptor<TransferRecord> {
        var descriptor = FetchDescriptor<TransferRecord>(
            sortBy: [SortDescriptor(\.date, order: .reverse)])
        descriptor.fetchLimit = limit
        return descriptor
    }

    @Environment(AppSettings.self) private var settings
    @Query(RecentTransfersSection.latest) private var records: [TransferRecord]

    // components.md → Home: the EmptyState glyph is 34 (compact), scaled with
    // Dynamic Type.
    @ScaledMetric(relativeTo: .largeTitle) private var emptyGlyphSize: CGFloat = 34

    var body: some View {
        if settings.saveTransferHistory {
            if records.isEmpty {
                emptyState
            } else {
                Section {
                    ForEach(records) { RecentTransferRow(record: $0) }
                } header: {
                    Text("Recent transfers").foregroundStyle(Color.textSecondary)
                }
            }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label {
                Text("No transfers yet")
            } icon: {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: emptyGlyphSize))
            }
        } description: {
            Text("Finished sends and receives appear here.")
                .foregroundStyle(Color.textSecondary)
        }
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }
}

/// A HistoryRow cut to what a glance needs: no size, no code hint, and a tap
/// opens History. Wiring a tap to the record's own detail waits for that
/// screen.
private struct RecentTransferRow: View {
    let record: TransferRecord
    private let summary: RecentTransferSummary
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    // components.md → HistoryRow: direction glyph at --icon-size-md, scaled.
    @ScaledMetric(relativeTo: .title3) private var glyphSize: CGFloat = IconSize.medium

    private var isLargeText: Bool { dynamicTypeSize.isAccessibilitySize }

    init(record: TransferRecord) {
        self.record = record
        summary = RecentTransferSummary(record)
    }

    var body: some View {
        NavigationLink(value: AppRouter.Route.history) {
            // The glyph sits above the text at accessibility sizes so the text
            // keeps the row's width (the same switch HistoryRow makes).
            let layout =
                isLargeText
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: Spacing.space3))
                : AnyLayout(HStackLayout(spacing: Spacing.space3))
            layout {
                directionGlyph
                textColumn
            }
            .frame(minHeight: ControlHeight.hitTargetMin)
        }
        .listRowInsets(
            EdgeInsets(
                top: Spacing.space3, leading: Spacing.space4, bottom: Spacing.space3,
                trailing: Spacing.space4)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(summary.spokenLabel)
    }

    private var directionGlyph: some View {
        Image(systemName: record.isSend ? "arrow.up.circle" : "arrow.down.circle")
            .font(.system(size: glyphSize))
            .foregroundStyle(record.status == .completed ? Color.accentFill : Color.textSecondary)
            // The row's spoken label carries the direction.
            .accessibilityHidden(true)
    }

    private var textColumn: some View {
        VStack(alignment: .leading, spacing: Spacing.space1) {
            Text(summary.title)
                .lineLimit(isLargeText ? 3 : 1)
                .truncationMode(.middle)
            metadata
                .font(.caption)
                .foregroundStyle(Color.textSecondary)
        }
    }

    /// One line at regular sizes; stacked at accessibility sizes, where one
    /// line would truncate.
    private var metadata: some View {
        let layout =
            isLargeText
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: Spacing.space1))
            : AnyLayout(HStackLayout(spacing: Spacing.space3))
        return layout {
            if let word = summary.statusWord { Text(word) }
            Text(summary.dateText)
        }
    }
}

#Preview("Recent transfers") {
    let history = HistoryStore(container: HistoryStore.makeContainer(inMemory: true))
    let samples: [TransferRecord] = [
        TransferRecord(
            isSend: false, status: .completed, isText: false, fileCount: 3, totalBytes: 177_000,
            names: ["Quarterly-Report.pdf", "Ridge-Sunrise.jpg", "Meeting-Notes.md"],
            codeHint: "cape-…", bookmarks: []),
        TransferRecord(
            isSend: true, status: .failed, isText: true, fileCount: 1, totalBytes: 148,
            names: [], codeHint: "wiry-…", bookmarks: []),
        TransferRecord(
            isSend: true, status: .completed, isText: false, fileCount: 1, totalBytes: 55_000,
            names: ["Design-Assets-Final-Version-For-Print-Tomorrow-Morning.zip"],
            codeHint: "getcroc.com", bookmarks: []),
    ]
    for (index, record) in samples.enumerated() {
        record.date = .now.addingTimeInterval(-Double(index + 1) * 20 * 3600)
        history.add(record)
    }
    return NavigationStack {
        Form { RecentTransfersSection() }
    }
    .environment(AppSettings(storage: MemorySettingsStorage(), secrets: MemorySecretStore()))
    .modelContainer(history.container)
}
