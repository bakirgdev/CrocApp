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

    /// A past date written as design/content.md → Dates asks: relative inside
    /// a week ("yesterday", "3 days ago"), a short absolute date after ("Oct
    /// 20", with the year when it is not this year). Never a raw timestamp.
    func recordText(now: Date = .now, calendar: Calendar = .current) -> String {
        let locale = calendar.locale ?? .current
        if isWithinAWeek(of: now, calendar: calendar) {
            let formatter = RelativeDateTimeFormatter()
            formatter.calendar = calendar
            formatter.locale = locale
            formatter.dateTimeStyle = .named
            return formatter.localizedString(for: self, relativeTo: now)
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
