import Foundation

/// Turns model objects into an `ExportDocument` and JSON, and back.
nonisolated enum DataExport {

    // MARK: - Coding

    /// ISO-8601 dates and sorted keys: the output stays diff-able and readable
    /// years later, and two exports of the same data are byte-identical.
    static func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return encoder
    }

    static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    static func encode(_ document: ExportDocument) throws -> Data {
        try encoder().encode(document)
    }

    static func decode(_ data: Data) throws -> ExportDocument {
        let document = try decoder().decode(ExportDocument.self, from: data)
        guard document.schemaVersion <= ExportDocument.currentSchemaVersion else {
            throw ExportError.unsupportedSchema(document.schemaVersion)
        }
        return document
    }

    enum ExportError: LocalizedError, Equatable {
        case unsupportedSchema(Int)

        var errorDescription: String? {
            switch self {
            case .unsupportedSchema(let version):
                "Die Datei stammt aus einer neueren Version (Schema \(version)). "
                    + "Diese App versteht bis Schema \(ExportDocument.currentSchemaVersion)."
            }
        }
    }

    /// File name with a sortable date prefix, so a folder of exports sorts itself.
    static func fileName(for date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return "fitness-export-\(formatter.string(from: date)).json"
    }

    // MARK: - Building

    static func makeDocument(
        exercises: [Exercise],
        plans: [WorkoutPlan],
        workouts: [PlanDay] = [],
        sessions: [WorkoutSession],
        measurements: [BodyMeasurement],
        goals: [MetricGoal],
        exportedAt: Date = Date()
    ) -> ExportDocument {
        ExportDocument(
            exportedAt: exportedAt,
            // Sorted throughout: an export must not depend on the order SwiftData
            // happens to return, or two exports of identical data would differ.
            exercises: exercises
                .sorted { $0.name < $1.name }
                .map(exported(_:)),
            plans: plans
                .sorted { $0.name < $1.name }
                .map(exported(_:)),
            workouts: workouts
                .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
                .map(exportedDay(_:)),
            sessions: sessions
                .sorted { $0.startedAt < $1.startedAt }
                .map(exported(_:)),
            measurements: measurements
                .sorted { $0.date < $1.date }
                .map(exported(_:)),
            goals: goals
                .sorted { $0.metricRaw < $1.metricRaw }
                .map(exported(_:))
        )
    }

    private static func exported(_ exercise: Exercise) -> ExportedExercise {
        ExportedExercise(
            id: exercise.id,
            name: exercise.name,
            primaryMuscle: exercise.primaryRaw,
            secondaryMuscles: exercise.secondaryRaw.sorted(),
            kind: exercise.kindRaw,
            stepOverrideKg: exercise.stepOverrideKg
        )
    }

    private static func exported(_ plan: WorkoutPlan) -> ExportedPlan {
        ExportedPlan(
            id: plan.id,
            name: plan.name,
            focus: plan.focus,
            isActive: plan.isActive,
            days: plan.sortedDays.map(exportedDay(_:))
        )
    }

    private static func exportedDay(_ day: PlanDay) -> ExportedPlanDay {
        ExportedPlanDay(
            id: day.id,
            weekday: day.weekday,
            name: day.name,
            focus: day.focus,
            category: day.categoryRaw,
            tip: day.tip,
            exercises: day.sortedExercises.map { item in
                ExportedPlanExercise(
                    id: item.id,
                    order: item.order,
                    exerciseID: item.exercise?.id,
                    sets: item.sets,
                    repsLower: item.repsLower,
                    repsUpper: item.repsUpper,
                    restLowerSeconds: item.restLowerSeconds,
                    restUpperSeconds: item.restUpperSeconds,
                    rirLower: item.rirLower,
                    rirUpper: item.rirUpper,
                    note: item.note
                )
            }
        )
    }

    private static func exported(_ session: WorkoutSession) -> ExportedSession {
        ExportedSession(
            id: session.id,
            startedAt: session.startedAt,
            endedAt: session.endedAt,
            dayName: session.dayName,
            category: session.categoryRaw,
            note: session.note,
            exercises: session.sortedExercises.map { entry in
                ExportedLoggedExercise(
                    id: entry.id,
                    order: entry.order,
                    exerciseID: entry.exercise?.id,
                    targetText: entry.targetText,
                    restSeconds: entry.restSeconds,
                    targetRepsLower: entry.targetRepsLower,
                    targetRepsUpper: entry.targetRepsUpper,
                    sets: entry.sortedSets.map { set in
                        ExportedSet(
                            id: set.id,
                            order: set.order,
                            weight: set.weight,
                            reps: set.reps,
                            rir: set.rir,
                            completedAt: set.completedAt
                        )
                    }
                )
            }
        )
    }

    private static func exported(_ measurement: BodyMeasurement) -> ExportedMeasurement {
        ExportedMeasurement(
            id: measurement.id,
            date: measurement.date,
            note: measurement.note,
            weight: measurement.weight,
            bodyFat: measurement.bodyFat,
            ffmi: measurement.ffmi,
            chest: measurement.chest,
            shoulders: measurement.shoulders,
            waist: measurement.waist,
            belly: measurement.belly,
            armRelaxed: measurement.armRelaxed,
            armFlexed: measurement.armFlexed,
            thigh: measurement.thigh,
            calf: measurement.calf,
            hips: measurement.hips
        )
    }

    private static func exported(_ goal: MetricGoal) -> ExportedGoal {
        ExportedGoal(
            id: goal.id,
            metric: goal.metricRaw,
            lowerBound: goal.lowerBound,
            upperBound: goal.upperBound
        )
    }

    // MARK: - Summary

    /// Short human summary for the export screen, so it is clear what is inside
    /// before sharing the file.
    static func summary(_ document: ExportDocument) -> String {
        let setCount = document.sessions
            .flatMap(\.exercises)
            .reduce(0) { $0 + $1.sets.count }
        return [
            "\(document.measurements.count) Messungen",
            "\(document.sessions.count) Einheiten",
            "\(setCount) Sätze",
            "\(document.exercises.count) Übungen",
            "\(document.workouts?.count ?? 0) Workouts",
            "\(document.goals.count) Ziele",
        ].joined(separator: " · ")
    }
}
