import Foundation

/// The window the home screen compares against: this week, month or quarter.
nonisolated enum GoalPeriod: String, CaseIterable, Identifiable, Sendable {
    case week, month, quarter

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .week: "Woche"
        case .month: "Monat"
        case .quarter: "Quartal"
        }
    }

    /// "diese Woche" / "diesen Monat" — for sentences about the change.
    var thisPeriodText: String {
        switch self {
        case .week: "diese Woche"
        case .month: "diesen Monat"
        case .quarter: "dieses Quartal"
        }
    }

    /// Weeks always start on Monday, because the plan does. Taking the device's
    /// first weekday would put Sunday first in some regions and shift every row
    /// of the week strip by a day.
    static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 2
        calendar.timeZone = .current
        return calendar
    }

    /// The period containing `date`.
    ///
    /// Quarters are computed rather than asked of `Calendar`: its `.quarter`
    /// component is not reliably supported by the Gregorian calendar, and a
    /// silently wrong interval here would misreport every goal on the screen.
    func interval(containing date: Date, calendar: Calendar = GoalPeriod.calendar) -> DateInterval {
        switch self {
        case .week:
            calendar.dateInterval(of: .weekOfYear, for: date) ?? DateInterval(start: date, duration: 0)
        case .month:
            calendar.dateInterval(of: .month, for: date) ?? DateInterval(start: date, duration: 0)
        case .quarter:
            Self.quarterInterval(containing: date, calendar: calendar)
        }
    }

    private static func quarterInterval(containing date: Date, calendar: Calendar) -> DateInterval {
        let parts = calendar.dateComponents([.year, .month], from: date)
        guard let year = parts.year, let month = parts.month else {
            return DateInterval(start: date, duration: 0)
        }
        let firstMonth = ((month - 1) / 3) * 3 + 1
        guard
            let start = calendar.date(from: DateComponents(year: year, month: firstMonth, day: 1)),
            let end = calendar.date(byAdding: DateComponents(month: 3), to: start)
        else {
            return DateInterval(start: date, duration: 0)
        }
        return DateInterval(start: start, end: end)
    }
}
