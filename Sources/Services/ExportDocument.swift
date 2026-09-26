import Foundation

/// The JSON shape of a full data export.
///
/// Design rules, all of them so an export stays useful years from now:
/// - **Versioned.** `schemaVersion` is the first field; an importer reads it
///   before anything else and can refuse or migrate.
/// - **Stable identity.** Every entity keeps its own UUID, so re-importing an
///   export updates rather than duplicates.
/// - **Owned data nests, shared data references.** Sets belong to an exercise
///   entry, entries belong to a session — those nest. Exercises are shared
///   across plans and sessions, so they are listed once and referenced by id.
/// - **Enums travel as their raw strings**, never as ordinal numbers, so
///   reordering a Swift enum cannot silently reinterpret old data.
nonisolated struct ExportDocument: Codable, Equatable, Sendable {
    static let currentSchemaVersion = 2

    var schemaVersion: Int = ExportDocument.currentSchemaVersion
    var exportedAt: Date
    var exercises: [ExportedExercise] = []
    var plans: [ExportedPlan] = []
    /// Optional so exports written before standalone workouts still decode.
    var workouts: [ExportedPlanDay]? = nil
    var sessions: [ExportedSession] = []
    var measurements: [ExportedMeasurement] = []
    var goals: [ExportedGoal] = []
}

nonisolated struct ExportedExercise: Codable, Equatable, Sendable {
    var id: UUID
    var name: String
    var primaryMuscle: String
    var secondaryMuscles: [String]
    var kind: String
    /// Only present when the rule-derived weekly step was overridden.
    var stepOverrideKg: Double?
}

nonisolated struct ExportedPlan: Codable, Equatable, Sendable {
    var id: UUID
    var name: String
    var focus: String
    /// Optional, because files written before several plans existed carry no
    /// flag at all. Decoding them as "not active" and then falling back to the
    /// newest plan is what keeps such a file readable.
    var isActive: Bool?
    var days: [ExportedPlanDay]
}

nonisolated struct ExportedPlanDay: Codable, Equatable, Sendable {
    var id: UUID
    var weekday: Int
    var name: String
    var focus: String
    var category: String
    var tip: String
    var exercises: [ExportedPlanExercise]
}

nonisolated struct ExportedPlanExercise: Codable, Equatable, Sendable {
    var id: UUID
    var order: Int
    var exerciseID: UUID?
    var sets: Int
    var repsLower: Int
    var repsUpper: Int
    var restLowerSeconds: Int
    var restUpperSeconds: Int
    var rirLower: Int?
    var rirUpper: Int?
    var note: String
}

nonisolated struct ExportedSession: Codable, Equatable, Sendable {
    var id: UUID
    var startedAt: Date
    var endedAt: Date?
    var dayName: String
    var category: String
    var note: String
    var exercises: [ExportedLoggedExercise]
}

nonisolated struct ExportedLoggedExercise: Codable, Equatable, Sendable {
    var id: UUID
    var order: Int
    var exerciseID: UUID?
    var targetText: String
    var restSeconds: Int
    var targetRepsLower: Int
    var targetRepsUpper: Int
    var sets: [ExportedSet]
}

nonisolated struct ExportedSet: Codable, Equatable, Sendable {
    var id: UUID
    var order: Int
    var weight: Double
    var reps: Int
    var rir: Int?
    var completedAt: Date
}

nonisolated struct ExportedMeasurement: Codable, Equatable, Sendable {
    var id: UUID
    var date: Date
    var note: String
    var weight: Double?
    var bodyFat: Double?
    var ffmi: Double?
    var chest: Double?
    var shoulders: Double?
    var waist: Double?
    var belly: Double?
    var armRelaxed: Double?
    var armFlexed: Double?
    var thigh: Double?
    var calf: Double?
    var hips: Double?
}

nonisolated struct ExportedGoal: Codable, Equatable, Sendable {
    var id: UUID
    var metric: String
    var lowerBound: Double
    var upperBound: Double
}
