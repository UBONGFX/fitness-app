import Foundation
import SwiftData

/// Writing an imported document into the store.
///
/// Split from `DataImport` so the preview stays free of SwiftData and testable
/// on its own. Order matters here: exercises first, because plans and sessions
/// reference them.
@MainActor
enum DataImportApply {

    static func apply(
        _ document: ExportDocument,
        exercises: [Exercise],
        measurements: [BodyMeasurement],
        goals: [MetricGoal],
        plans: [WorkoutPlan],
        workouts: [PlanDay] = [],
        sessions: [WorkoutSession],
        into context: ModelContext
    ) throws {
        let exerciseLookup = importExercises(document.exercises, existing: exercises, into: context)
        importMeasurements(document.measurements, existing: measurements, into: context)
        importGoals(document.goals, existing: goals, into: context)
        importPlans(document.plans, existing: plans, exercises: exerciseLookup, into: context)
        importWorkouts(document.workouts ?? [], existing: workouts, exercises: exerciseLookup, into: context)
        if document.workouts == nil && workouts.isEmpty {
            WorkoutLibrary.importExistingPlansIfNeeded(context, inMemoryStore: true)
        }
        importSessions(document.sessions, existing: sessions, exercises: exerciseLookup, into: context)
        try context.save()
    }

    // MARK: - Exercises

    private static func importExercises(
        _ imported: [ExportedExercise],
        existing: [Exercise],
        into context: ModelContext
    ) -> [UUID: Exercise] {
        var byID = Dictionary(existing.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let byName = Dictionary(existing.map { ($0.name, $0) }, uniquingKeysWith: { first, _ in first })
        var lookup: [UUID: Exercise] = byID

        for entry in imported {
            // Name fallback keeps an import from a different install from
            // duplicating the whole exercise catalogue.
            let target = byID[entry.id] ?? byName[entry.name]
            if let target {
                target.name = entry.name
                target.primaryRaw = entry.primaryMuscle
                target.secondaryRaw = entry.secondaryMuscles
                target.kindRaw = entry.kind
                target.stepOverrideKg = entry.stepOverrideKg
                lookup[entry.id] = target
            } else {
                let created = Exercise(id: entry.id, name: entry.name)
                created.primaryRaw = entry.primaryMuscle
                created.secondaryRaw = entry.secondaryMuscles
                created.kindRaw = entry.kind
                created.stepOverrideKg = entry.stepOverrideKg
                context.insert(created)
                byID[entry.id] = created
                lookup[entry.id] = created
            }
        }
        return lookup
    }

    // MARK: - Measurements and goals

    private static func importMeasurements(
        _ imported: [ExportedMeasurement],
        existing: [BodyMeasurement],
        into context: ModelContext
    ) {
        let byID = Dictionary(existing.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        for entry in imported {
            let target = byID[entry.id] ?? {
                let created = BodyMeasurement(id: entry.id)
                context.insert(created)
                return created
            }()
            target.date = entry.date
            target.note = entry.note
            target.weight = entry.weight
            target.bodyFat = entry.bodyFat
            target.ffmi = entry.ffmi
            target.chest = entry.chest
            target.shoulders = entry.shoulders
            target.waist = entry.waist
            target.belly = entry.belly
            target.armRelaxed = entry.armRelaxed
            target.armFlexed = entry.armFlexed
            target.thigh = entry.thigh
            target.calf = entry.calf
            target.hips = entry.hips
        }
    }

    private static func importGoals(
        _ imported: [ExportedGoal],
        existing: [MetricGoal],
        into context: ModelContext
    ) {
        let byID = Dictionary(existing.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let byMetric = Dictionary(existing.map { ($0.metricRaw, $0) }, uniquingKeysWith: { first, _ in first })
        for entry in imported {
            // One goal per metric: matching on the metric as well stops an import
            // from leaving two competing targets for the same measurement.
            let target = byID[entry.id] ?? byMetric[entry.metric] ?? {
                let created = MetricGoal(id: entry.id)
                context.insert(created)
                return created
            }()
            target.metricRaw = entry.metric
            target.lowerBound = entry.lowerBound
            target.upperBound = entry.upperBound
            target.priority = GoalPriority(rawValue: entry.priority ?? "") ?? .secondary
            target.hasTarget = entry.hasTarget ?? true
        }
    }

    // MARK: - Plans

    private static func importPlans(
        _ imported: [ExportedPlan],
        existing: [WorkoutPlan],
        exercises: [UUID: Exercise],
        into context: ModelContext
    ) {
        let byID = Dictionary(existing.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        for entry in imported {
            let plan = byID[entry.id] ?? {
                let created = WorkoutPlan(id: entry.id)
                context.insert(created)
                return created
            }()
            plan.name = entry.name
            plan.focus = entry.focus
            // Deliberately not applied here: which plan is active is decided
            // after the whole batch, so a file naming two of them — or none —
            // cannot leave the store in a state the app has no rule for.

            // Days are replaced wholesale rather than diffed. A plan is small,
            // and a half-merged week would be harder to reason about than a
            // clean overwrite.
            for day in plan.days ?? [] {
                context.delete(day)
            }
            plan.days = entry.days.map { day in
                let planDay = PlanDay(
                    id: day.id,
                    weekday: day.weekday,
                    name: day.name,
                    focus: day.focus,
                    tip: day.tip
                )
                planDay.categoryRaw = day.category
                planDay.plan = plan
                planDay.exercises = day.exercises.map { item in
                    let planExercise = PlanExercise(
                        id: item.id,
                        order: item.order,
                        sets: item.sets,
                        reps: item.repsLower...max(item.repsUpper, item.repsLower),
                        rest: item.restLowerSeconds...max(item.restUpperSeconds, item.restLowerSeconds),
                        rir: item.rirLower.flatMap { lower in
                            item.rirUpper.map { lower...max($0, lower) }
                        },
                        note: item.note,
                        exercise: item.exerciseID.flatMap { exercises[$0] }
                    )
                    planExercise.day = planDay
                    return planExercise
                }
                return planDay
            }
        }

        settleActivePlan(imported, in: context)
    }

    /// Exactly one plan ends up active, whatever the file said.
    ///
    /// An import can name two actives (two devices, two exports merged) or none
    /// (a file written before several plans existed). Both are resolved with the
    /// same rule the app uses everywhere else, so the store never holds a
    /// combination the rest of the code has no answer for. A plan already in the
    /// store keeps its flag when the file mentions no active at all — an import
    /// of measurements must not silently switch the training plan.
    private static func settleActivePlan(_ imported: [ExportedPlan], in context: ModelContext) {
        let all = (try? context.fetch(FetchDescriptor<WorkoutPlan>())) ?? []
        guard !all.isEmpty else { return }

        let namedActive = Set(imported.filter { $0.isActive == true }.map(\.id))
        if namedActive.isEmpty {
            // Nothing claimed: only step in when the store has no active either.
            guard all.allSatisfy({ !$0.isActive }), let fallback = PlanLibrary.active(in: all) else { return }
            PlanLibrary.activate(fallback, in: all)
            return
        }
        let claimed = all.filter { namedActive.contains($0.id) }
        guard let winner = PlanLibrary.active(in: claimed) ?? PlanLibrary.active(in: all) else { return }
        PlanLibrary.activate(winner, in: all)
    }

    // MARK: - Workouts

    private static func importWorkouts(
        _ imported: [ExportedPlanDay],
        existing: [PlanDay],
        exercises: [UUID: Exercise],
        into context: ModelContext
    ) {
        let byID = Dictionary(existing.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        for entry in imported {
            let workout = byID[entry.id] ?? {
                let created = PlanDay(id: entry.id)
                context.insert(created)
                return created
            }()
            workout.plan = nil
            workout.name = entry.name
            workout.focus = entry.focus
            workout.categoryRaw = entry.category
            workout.tip = entry.tip
            for item in workout.exercises ?? [] { context.delete(item) }
            workout.exercises = entry.exercises.map { item in
                let created = PlanExercise(
                    id: item.id,
                    order: item.order,
                    sets: item.sets,
                    reps: item.repsLower...max(item.repsLower, item.repsUpper),
                    rest: item.restLowerSeconds...max(item.restLowerSeconds, item.restUpperSeconds),
                    rir: item.rirLower.map { $0...max($0, item.rirUpper ?? $0) },
                    note: item.note,
                    exercise: item.exerciseID.flatMap { exercises[$0] }
                )
                created.day = workout
                return created
            }
        }
    }

    // MARK: - Sessions

    private static func importSessions(
        _ imported: [ExportedSession],
        existing: [WorkoutSession],
        exercises: [UUID: Exercise],
        into context: ModelContext
    ) {
        let byID = Dictionary(existing.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        for entry in imported {
            let session = byID[entry.id] ?? {
                let created = WorkoutSession(id: entry.id)
                context.insert(created)
                return created
            }()
            session.startedAt = entry.startedAt
            session.endedAt = entry.endedAt
            session.dayName = entry.dayName
            session.categoryRaw = entry.category
            session.note = entry.note

            for logged in session.exercises ?? [] {
                context.delete(logged)
            }
            session.exercises = entry.exercises.map { item in
                let logged = LoggedExercise(
                    id: item.id,
                    order: item.order,
                    targetText: item.targetText,
                    restSeconds: item.restSeconds,
                    targetReps: item.targetRepsLower...max(item.targetRepsUpper, item.targetRepsLower),
                    exercise: item.exerciseID.flatMap { exercises[$0] }
                )
                logged.session = session
                logged.sets = item.sets.map { set in
                    let loggedSet = LoggedSet(
                        id: set.id,
                        order: set.order,
                        weight: set.weight,
                        reps: set.reps,
                        rir: set.rir,
                        type: SetType(rawValue: set.type ?? "") ?? .working,
                        completedAt: set.completedAt
                    )
                    loggedSet.loggedExercise = logged
                    return loggedSet
                }
                return logged
            }
        }
    }
}
