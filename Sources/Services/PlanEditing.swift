import Foundation
import SwiftData

/// Changing a plan: adding, removing and reordering exercises within a day.
///
/// `order` is what puts the exercises in sequence — SwiftData relationships come
/// back unordered. Every operation here leaves it **contiguous from zero**, so a
/// gap or a duplicate can never quietly reshuffle a training day.
@MainActor
enum PlanEditing {

    @discardableResult
    static func add(
        _ exercise: Exercise,
        to day: PlanDay,
        sets: Int = 3,
        reps: ClosedRange<Int> = 8...12,
        rest: ClosedRange<Int> = 90...90,
        context: ModelContext
    ) -> PlanExercise {
        let item = PlanExercise(
            order: day.sortedExercises.count,
            sets: sets,
            reps: reps,
            rest: rest,
            exercise: exercise
        )
        item.day = day
        day.exercises = day.sortedExercises + [item]
        context.insert(item)
        return item
    }

    static func remove(_ item: PlanExercise, from day: PlanDay, context: ModelContext) {
        day.exercises = day.sortedExercises.filter { $0.id != item.id }
        context.delete(item)
        renumber(day)
    }

    static func remove(atOffsets offsets: IndexSet, from day: PlanDay, context: ModelContext) {
        let doomed = offsets.map { day.sortedExercises[$0] }
        for item in doomed {
            remove(item, from: day, context: context)
        }
    }

    static func move(in day: PlanDay, fromOffsets source: IndexSet, toOffset destination: Int) {
        var items = day.sortedExercises
        items.move(fromOffsets: source, toOffset: destination)
        // Renumber from the moved array, not via `sortedExercises`: that sorts by
        // the old `order` values and would put everything straight back, undoing
        // the move without a trace.
        applyOrder(items)
        day.exercises = items
    }

    /// Rewrites `order` to 0, 1, 2 … in the day's current sequence.
    static func renumber(_ day: PlanDay) {
        applyOrder(day.sortedExercises)
    }

    private static func applyOrder(_ items: [PlanExercise]) {
        for (index, item) in items.enumerated() {
            item.order = index
        }
    }

    /// Exercises not yet on this day, for the picker. Sorted by name; a movement
    /// already prescribed twice on one day is almost always a mistake.
    static func available(_ all: [Exercise], for day: PlanDay) -> [Exercise] {
        let used = Set(day.sortedExercises.compactMap { $0.exercise?.id })
        return all
            .filter { !used.contains($0.id) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    /// Validates a new exercise before it is created.
    static func nameProblem(_ name: String, existing: [Exercise]) -> String? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "Die Übung braucht einen Namen." }
        if existing.contains(where: { $0.name.localizedCaseInsensitiveCompare(trimmed) == .orderedSame }) {
            return "Diese Übung gibt es schon."
        }
        return nil
    }
}
