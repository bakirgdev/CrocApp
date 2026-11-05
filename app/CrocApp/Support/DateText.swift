import SwiftUI

extension Date {
    /// Whether `self` is inside the last week, counted back from `now` by the
    /// calendar. A date after `now` (a clock that moved back) counts as recent.
    func isWithinAWeek(of now: Date = .now, calendar: Calendar = .current) -> Bool {
        guard let weekAgo = calendar.date(byAdding: .weekOfYear, value: -1, to: now) else {
            return true
        }
        return self > weekAgo
    }

    /// One formatter for every row: a list rewrites its dates every minute, and
    /// a formatter per row per minute is wasted allocation. Calendar and locale
    /// are set on each use, since callers pass their own.
    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.dateTimeStyle = .named
        return formatter
    }()

    /// "yesterday", "3 days ago": `self` written relative to `now`.
    func relativeText(to now: Date, calendar: Calendar) -> String {
        let formatter = Self.relativeFormatter
        formatter.calendar = calendar
        formatter.locale = calendar.locale ?? .current
        return formatter.localizedString(for: self, relativeTo: now)
    }

    /// A past date written as design/voice.md → Dates asks: relative inside
    /// a week ("yesterday", "3 days ago"), a short absolute date after ("Oct
    /// 20", with the year when it is not this year). Never a raw timestamp.
    func recordText(now: Date = .now, calendar: Calendar = .current) -> String {
        let locale = calendar.locale ?? .current
        if isWithinAWeek(of: now, calendar: calendar) {
            return relativeText(to: now, calendar: calendar)
        }
        var style = Date.FormatStyle(
            locale: locale, calendar: calendar, timeZone: calendar.timeZone
        )
        .month(.abbreviated).day()
        if !calendar.isDate(self, equalTo: now, toGranularity: .year) { style = style.year() }
        return formatted(style)
    }
}

/// A record's date as `Date.recordText` writes it, rewritten every minute so
/// "yesterday" and "3 days ago" do not go stale while the screen is open.
struct DateText: View {
    let date: Date

    init(_ date: Date) {
        self.date = date
    }

    var body: some View {
        TimelineView(.everyMinute) { context in
            Text(verbatim: date.recordText(now: context.date))
        }
    }
}
