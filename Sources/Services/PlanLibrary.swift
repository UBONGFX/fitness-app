import Foundation

/// Managing several plans of which exactly one is active.
///
/// The "only one" rule is enforced here rather than by the store: CloudKit
/// forbids unique constraints, so nothing stops two records from both claiming
/// to be active — a device that was offline while another activated a plan will
/// sync exactly that. Every read therefore goes through `active(in:)`, which
/// resolves a tie deterministically instead of returning whichever came first.
nonisolated enum PlanLibrary {

    /// Plans in a stable order: active first, then newest to oldest.
    static func ordered(_ plans: [WorkoutPlan]) -> [WorkoutPlan] {
        plans.sorted { lhs, rhs in
            if lhs.isActive != rhs.isActive { return lhs.isActive }
            if lhs.createdAt != rhs.createdAt { return lhs.createdAt > rhs.createdAt }
            // Same instant: fall back to the id so the order never flickers.
            return lhs.id.uuidString < rhs.id.uuidString
        }
    }

    /// The plan the training screen, the week and the volume analysis read.
    ///
    /// Falls back to the newest plan when none is flagged — an import from an
    /// older export carries no flag at all, and a library that shows no plan
    /// would look empty rather than un-migrated.
    static func active(in plans: [WorkoutPlan]) -> WorkoutPlan? {
        let flagged = plans.filter(\.isActive)
        if !flagged.isEmpty { return ordered(flagged).first }
        return ordered(plans).first
    }

    /// Makes one plan the active one and clears the flag everywhere else.
    ///
    /// Clearing every other plan rather than only the previously active one is
    /// what repairs a store that already holds two actives.
    static func activate(_ plan: WorkoutPlan, in plans: [WorkoutPlan]) {
        for one in plans {
            one.isActive = one.id == plan.id
        }
    }

    /// A fresh week: seven rest days, nothing prescribed.
    ///
    /// Empty by design — the days are what gets adjusted one by one, and
    /// pre-filling a split would mean deleting someone else's idea of a week
    /// before writing your own.
    static func makeEmptyPlan(name: String, focus: String = "", createdAt: Date = Date()) -> WorkoutPlan {
        let plan = WorkoutPlan(name: name, focus: focus, createdAt: createdAt)
        let days = (1...7).map { weekday in
            let day = PlanDay(weekday: weekday, name: "Ruhetag", category: .rest)
            day.plan = plan
            return day
        }
        plan.days = days
        return plan
    }

    /// A copy under a new name, including every day and prescription.
    ///
    /// New identities throughout: sharing ids with the original would make the
    /// export match them as the same records and merge them back into one.
    /// Exercises are **not** copied — they are the shared catalogue, and two
    /// plans referring to the same bench press is the point.
    static func duplicate(_ plan: WorkoutPlan, name: String, createdAt: Date = Date()) -> WorkoutPlan {
        let copy = WorkoutPlan(name: name, focus: plan.focus, createdAt: createdAt)
        let days = plan.sortedDays.map { day -> PlanDay in
            let newDay = PlanDay(
                weekday: day.weekday,
                name: day.name,
                focus: day.focus,
                category: day.category,
                tip: day.tip
            )
            let exercises = day.sortedExercises.map { item -> PlanExercise in
                let newItem = PlanExercise(
                    order: item.order,
                    sets: item.sets,
                    reps: item.repsLower...max(item.repsUpper, item.repsLower),
                    rest: item.restLowerSeconds...max(item.restUpperSeconds, item.restLowerSeconds),
                    rir: item.rirLower.map { $0...max(item.rirUpper ?? $0, $0) },
                    note: item.note,
                    exercise: item.exercise
                )
                newItem.day = newDay
                return newItem
            }
            newDay.exercises = exercises
            newDay.plan = copy
            return newDay
        }
        copy.days = days
        return copy
    }

    /// Which plan should take over when `plan` is deleted, if any.
    ///
    /// Deleting the active plan must not leave the app with none active — the
    /// training screen would show an empty week with no way to explain why.
    static func successor(after plan: WorkoutPlan, in plans: [WorkoutPlan]) -> WorkoutPlan? {
        guard plan.isActive else { return nil }
        return ordered(plans.filter { $0.id != plan.id }).first
    }

    /// A name that is not already taken, by appending a counter.
    ///
    /// Duplicates are allowed by the store, but two plans called "Full Body" in
    /// the same list cannot be told apart in the switcher.
    static func availableName(_ wanted: String, in plans: [WorkoutPlan]) -> String {
        let taken = Set(plans.map { $0.name.trimmingCharacters(in: .whitespaces).lowercased() })
        let base = wanted.trimmingCharacters(in: .whitespaces)
        guard taken.contains(base.lowercased()) else { return base }
        var counter = 2
        while taken.contains("\(base) \(counter)".lowercased()) {
            counter += 1
        }
        return "\(base) \(counter)"
    }
}
