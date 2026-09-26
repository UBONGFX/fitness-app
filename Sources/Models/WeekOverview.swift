import Foundation

/// One day of the week strip: what the plan asked for, and what happened.
///
/// Not `Sendable`: it carries model objects, which belong to their context.
nonisolated struct WeekDayRow: Identifiable {
    let weekday: Int
    let date: Date
    let planDay: PlanDay?
    let sessions: [WorkoutSession]
    let status: Status

    var id: Int { weekday }

    var plannedSets: Int { planDay?.category.isTrainingDay == true ? (planDay?.totalSets ?? 0) : 0 }
    var completedSets: Int { sessions.reduce(0) { $0 + $1.completedSets } }

    /// What was actually trained, which is not always what was planned — a
    /// session started from another day keeps its own name.
    var performedName: String? {
        let names = Array(Set(sessions.map(\.dayName))).sorted()
        return names.isEmpty ? nil : names.joined(separator: " · ")
    }

    /// True when the day was trained with something other than its own plan day,
    /// so the strip can say so instead of quietly showing a mismatched name.
    var isSwapped: Bool {
        guard let performedName, let planned = planDay?.name else { return false }
        return performedName != planned
    }

    enum Status: Equatable, Sendable {
        /// Planned and trained.
        case done
        /// A rest day in the plan, and nothing was trained.
        case rest
        /// A training day in the past with nothing logged.
        case missed
        /// Today, not yet trained.
        case today
        /// Still ahead this week.
        case upcoming
    }
}

/// The seven-day strip on the home screen, for any week.
nonisolated enum WeekOverview {

    static func week(containing date: Date, calendar: Calendar = GoalPeriod.calendar) -> DateInterval {
        calendar.dateInterval(of: .weekOfYear, for: date)
            ?? DateInterval(start: date, duration: 7 * 86_400)
    }

    /// Steps whole weeks, so a stretch of paging back and forward lands exactly
    /// where it started instead of drifting across a daylight-saving boundary.
    static func week(_ interval: DateInterval, offsetBy weeks: Int, calendar: Calendar = GoalPeriod.calendar) -> DateInterval {
        guard let moved = calendar.date(byAdding: .weekOfYear, value: weeks, to: interval.start) else {
            return interval
        }
        return week(containing: moved, calendar: calendar)
    }

    static func rows(
        plan: WorkoutPlan?,
        sessions: [WorkoutSession],
        week: DateInterval,
        now: Date = Date(),
        calendar: Calendar = GoalPeriod.calendar
    ) -> [WeekDayRow] {
        let today = calendar.startOfDay(for: now)
        let days = plan.map { plan in
            Dictionary(uniqueKeysWithValues: plan.sortedDays.map { ($0.weekday, $0) })
        } ?? [:]

        return (0..<7).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: week.start) else { return nil }
            let startOfDay = calendar.startOfDay(for: date)
            let weekday = SessionBuilder.planWeekday(from: calendar.component(.weekday, from: date))
            let planDay = days[weekday]

            // An in-progress session belongs on the strip too; only sessions that
            // were opened and abandoned without a single set are left out.
            let daySessions = sessions
                .filter { calendar.isDate($0.startedAt, inSameDayAs: date) }
                .filter { $0.completedSets > 0 || $0.isActive }
                .sorted { $0.startedAt < $1.startedAt }

            return WeekDayRow(
                weekday: weekday,
                date: date,
                planDay: planDay,
                sessions: daySessions,
                status: status(
                    planDay: planDay,
                    sessions: daySessions,
                    startOfDay: startOfDay,
                    today: today
                )
            )
        }
    }

    static func status(
        planDay: PlanDay?,
        sessions: [WorkoutSession],
        startOfDay: Date,
        today: Date
    ) -> WeekDayRow.Status {
        // Anything trained counts as done, including a session on a rest day —
        // the strip reports what happened, not what was supposed to happen.
        if sessions.contains(where: { $0.completedSets > 0 }) { return .done }
        if startOfDay > today { return planDay?.category.isTrainingDay == true ? .upcoming : .rest }
        guard planDay?.category.isTrainingDay == true else { return .rest }
        if startOfDay == today { return .today }
        return .missed
    }

    /// "KW 38 · 15.–21. Sep"
    static func title(for week: DateInterval, calendar: Calendar = GoalPeriod.calendar) -> String {
        let number = calendar.component(.weekOfYear, from: week.start)
        let last = calendar.date(byAdding: .day, value: 6, to: week.start) ?? week.start

        let day = Date.FormatStyle(date: .omitted).day()
        let dayMonth = Date.FormatStyle(date: .omitted).day().month(.abbreviated)
        return "KW \(number) · \(week.start.formatted(day)).–\(last.formatted(dayMonth))"
    }

    /// True for the week that contains `now`, which is the only one where "heute"
    /// means anything.
    static func isCurrent(_ week: DateInterval, now: Date = Date()) -> Bool {
        week.contains(now)
    }

    static func summary(_ rows: [WeekDayRow]) -> String {
        let trained = rows.filter { $0.status == .done }.count
        let sets = rows.reduce(0) { $0 + $1.completedSets }
        let einheit = trained == 1 ? "Einheit" : "Einheiten"
        return "\(trained) \(einheit) · \(sets) Sätze"
    }
}
