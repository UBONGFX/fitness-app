import Foundation
import SwiftData

/// Reading an export back in.
///
/// Two rules decide everything here:
///
/// 1. **Match by UUID, fall back to name for exercises.** Re-importing an export
///    from this app updates in place. An export from another install has
///    different UUIDs, and without the name fallback every one of the twenty
///    exercises would arrive a second time.
/// 2. **Never delete what the file does not mention.** An import adds and
///    updates; local data the file knows nothing about stays. Losing months of
///    logged sets to a stale backup is far worse than a leftover row.
nonisolated enum DataImport {

    /// What an import would do, shown before anything is written.
    struct Preview: Equatable, Sendable {
        var newExercises = 0
        var updatedExercises = 0
        var newMeasurements = 0
        var updatedMeasurements = 0
        var newGoals = 0
        var updatedGoals = 0
        var newPlans = 0
        var updatedPlans = 0
        var newWorkouts = 0
        var updatedWorkouts = 0
        var newSessions = 0
        var updatedSessions = 0

        var totalNew: Int {
            newExercises + newMeasurements + newGoals + newPlans + newWorkouts + newSessions
        }
        var totalUpdated: Int {
            updatedExercises + updatedMeasurements + updatedGoals + updatedPlans + updatedWorkouts + updatedSessions
        }
        var isEmpty: Bool { totalNew == 0 && totalUpdated == 0 }

        /// One line per entity type that actually changes — types with nothing to
        /// do are left out rather than listed as "0 neu, 0 aktualisiert".
        var lines: [String] {
            var result: [String] = []
            func add(_ label: String, _ new: Int, _ updated: Int) {
                guard new > 0 || updated > 0 else { return }
                var parts: [String] = []
                if new > 0 { parts.append("\(new) neu") }
                if updated > 0 { parts.append("\(updated) aktualisiert") }
                result.append("\(label): \(parts.joined(separator: ", "))")
            }
            add("Messungen", newMeasurements, updatedMeasurements)
            add("Ziele", newGoals, updatedGoals)
            add("Übungen", newExercises, updatedExercises)
            add("Pläne", newPlans, updatedPlans)
            add("Workouts", newWorkouts, updatedWorkouts)
            add("Einheiten", newSessions, updatedSessions)
            return result
        }
    }

    /// Identity of what is already stored, so the preview needs no model context.
    struct ExistingData: Sendable {
        var exerciseIDs: Set<UUID> = []
        var exerciseNames: Set<String> = []
        var measurementIDs: Set<UUID> = []
        var goalIDs: Set<UUID> = []
        var planIDs: Set<UUID> = []
        var workoutIDs: Set<UUID> = []
        var sessionIDs: Set<UUID> = []

        init(
            exercises: [Exercise] = [],
            measurements: [BodyMeasurement] = [],
            goals: [MetricGoal] = [],
            plans: [WorkoutPlan] = [],
            workouts: [PlanDay] = [],
            sessions: [WorkoutSession] = []
        ) {
            exerciseIDs = Set(exercises.map(\.id))
            exerciseNames = Set(exercises.map(\.name))
            measurementIDs = Set(measurements.map(\.id))
            goalIDs = Set(goals.map(\.id))
            planIDs = Set(plans.map(\.id))
            workoutIDs = Set(workouts.map(\.id))
            sessionIDs = Set(sessions.map(\.id))
        }
    }

    /// Why a chosen file could not be read.
    ///
    /// The raw decoding error ("The data couldn't be read because it isn't in the
    /// correct format.") tells the person nothing about what to do. These say
    /// which file they picked and what is wrong with it.
    enum LoadFailure: LocalizedError, Equatable {
        case unreadable
        case notJSON
        case notAnExport
        case newerSchema(Int)

        var errorDescription: String? {
            switch self {
            case .unreadable:
                "Die Datei lässt sich nicht lesen. Liegt sie vielleicht in iCloud und ist noch nicht geladen?"
            case .notJSON:
                "Das ist keine gültige JSON-Datei."
            case .notAnExport:
                "Die Datei ist zwar JSON, stammt aber nicht aus dieser App."
            case .newerSchema(let version):
                "Die Datei stammt aus einer neueren Version (Schema \(version)). "
                    + "Diese App versteht bis Schema \(ExportDocument.currentSchemaVersion)."
            }
        }
    }

    /// Reads and decodes an export file, turning every failure into something a
    /// person can act on.
    static func load(from data: Data) throws -> ExportDocument {
        guard !data.isEmpty else { throw LoadFailure.notJSON }
        guard (try? JSONSerialization.jsonObject(with: data)) != nil else {
            throw LoadFailure.notJSON
        }
        do {
            return try DataExport.decode(data)
        } catch let error as DataExport.ExportError {
            if case .unsupportedSchema(let version) = error {
                throw LoadFailure.newerSchema(version)
            }
            throw LoadFailure.notAnExport
        } catch {
            // Valid JSON, wrong shape — a different app's export, or a file that
            // happens to end in .json.
            throw LoadFailure.notAnExport
        }
    }

    static func preview(_ document: ExportDocument, against existing: ExistingData) -> Preview {
        var preview = Preview()

        for exercise in document.exercises {
            if existing.exerciseIDs.contains(exercise.id) || existing.exerciseNames.contains(exercise.name) {
                preview.updatedExercises += 1
            } else {
                preview.newExercises += 1
            }
        }
        for measurement in document.measurements {
            existing.measurementIDs.contains(measurement.id)
                ? (preview.updatedMeasurements += 1)
                : (preview.newMeasurements += 1)
        }
        for goal in document.goals {
            existing.goalIDs.contains(goal.id) ? (preview.updatedGoals += 1) : (preview.newGoals += 1)
        }
        for plan in document.plans {
            existing.planIDs.contains(plan.id) ? (preview.updatedPlans += 1) : (preview.newPlans += 1)
        }
        for workout in document.workouts ?? [] {
            existing.workoutIDs.contains(workout.id)
                ? (preview.updatedWorkouts += 1)
                : (preview.newWorkouts += 1)
        }
        for session in document.sessions {
            existing.sessionIDs.contains(session.id)
                ? (preview.updatedSessions += 1)
                : (preview.newSessions += 1)
        }
        return preview
    }
}
