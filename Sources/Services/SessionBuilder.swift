import Foundation

/// Creates sessions from plan days, and answers "which day is today?".
///
/// Kept free of SwiftUI and SwiftData APIs so the weekday mapping and the
/// prescription snapshot can be tested directly.
nonisolated enum SessionBuilder {

    /// Converts `Calendar`'s Sunday-first weekday to the plan's Monday-first one.
    static func planWeekday(from calendarWeekday: Int) -> Int {
        ((calendarWeekday + 5) % 7) + 1
    }

    static func todayWeekday(calendar: Calendar = .current, now: Date = Date()) -> Int {
        planWeekday(from: calendar.component(.weekday, from: now))
    }

    /// The plan day matching today, if the plan has one.
    static func todaysDay(in plan: WorkoutPlan, calendar: Calendar = .current, now: Date = Date()) -> PlanDay? {
        let weekday = todayWeekday(calendar: calendar, now: now)
        return plan.sortedDays.first { $0.weekday == weekday }
    }

    /// Builds a session with one entry per prescribed exercise, no sets yet.
    /// The prescription text is snapshotted so a later plan edit cannot rewrite
    /// what a past session said the target was.
    static func makeSession(from day: PlanDay, startedAt: Date = Date()) -> WorkoutSession {
        let session = WorkoutSession(
            startedAt: startedAt,
            dayName: day.name,
            category: day.category,
            planDay: day
        )
        let entries = day.sortedExercises.enumerated().map { index, prescription in
            LoggedExercise(
                order: index,
                targetText: prescription.setsAndRepsText,
                restSeconds: prescription.restLowerSeconds,
                targetReps: prescription.repsLower...max(prescription.repsUpper, prescription.repsLower),
                exercise: prescription.exercise
            )
        }
        session.exercises = entries
        for entry in entries {
            entry.session = session
        }
        return session
    }
}
