import Foundation
import SwiftData

/// Standalone workout templates use the existing PlanDay and PlanExercise records.
/// A template has no parent plan, so it has no assigned weekday.
enum WorkoutLibrary {
    private static let migrationKey = "didImportStandaloneWorkouts"

    static func templates(in days: [PlanDay]) -> [PlanDay] {
        days.filter { $0.plan == nil && $0.category.isTrainingDay }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    /// Copies existing training days once, retaining the old plan and all sessions.
    static func importExistingPlansIfNeeded(_ context: ModelContext, inMemoryStore: Bool = false) {
        guard inMemoryStore || !UserDefaults.standard.bool(forKey: migrationKey) else { return }
        do {
            let existing = try context.fetch(FetchDescriptor<PlanDay>())
            if templates(in: existing).isEmpty {
                let plans = try context.fetch(FetchDescriptor<WorkoutPlan>())
                var names = Set<String>()
                for plan in PlanLibrary.ordered(plans) {
                    for day in plan.trainingDays {
                        var name = day.name
                        if names.contains(name.lowercased()) {
                            name = "\(plan.name) · \(day.name)"
                        }
                        names.insert(name.lowercased())
                        let copy = PlanDay(name: name, focus: day.focus, category: day.category, tip: day.tip)
                        context.insert(copy)
                        for item in day.sortedExercises {
                            let cloned = PlanExercise(
                                order: item.order,
                                sets: item.sets,
                                reps: item.repsLower...max(item.repsLower, item.repsUpper),
                                rest: item.restLowerSeconds...max(item.restLowerSeconds, item.restUpperSeconds),
                                rir: item.rirLower.map { $0...max($0, item.rirUpper ?? $0) },
                                note: item.note,
                                exercise: item.exercise
                            )
                            cloned.day = copy
                            context.insert(cloned)
                        }
                    }
                }
            }
            try context.save()
            if !inMemoryStore { UserDefaults.standard.set(true, forKey: migrationKey) }
        } catch {
            // Retry next launch if the store is temporarily unavailable.
        }
    }

    static func makeSession(from template: PlanDay, startedAt: Date = Date()) -> WorkoutSession {
        SessionBuilder.makeSession(from: template, startedAt: startedAt)
    }
}
