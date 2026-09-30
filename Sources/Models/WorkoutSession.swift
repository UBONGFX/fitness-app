import Foundation
import SwiftData

/// One training session — started from a plan day or free-form.
///
/// The day's name and category are **copied**, not only referenced: a plan can be
/// edited or replaced later, and a past session must keep saying what it actually
/// was. The link to `planDay` stays for convenience but is not the source of truth.
@Model
final class WorkoutSession {
    var id: UUID = UUID()
    var startedAt: Date = Date()
    var endedAt: Date?
    var dayName: String = ""
    var categoryRaw: String = TrainingCategory.push.rawValue
    var note: String = ""

    var planDay: PlanDay?

    @Relationship(deleteRule: .cascade, inverse: \LoggedExercise.session)
    var exercises: [LoggedExercise]? = []

    init(
        id: UUID = UUID(),
        startedAt: Date = Date(),
        dayName: String = "",
        category: TrainingCategory = .push,
        planDay: PlanDay? = nil
    ) {
        self.id = id
        self.startedAt = startedAt
        self.dayName = dayName
        self.categoryRaw = category.rawValue
        self.planDay = planDay
    }

    var category: TrainingCategory {
        get { TrainingCategory(rawValue: categoryRaw) ?? .push }
        set { categoryRaw = newValue.rawValue }
    }

    var isActive: Bool { endedAt == nil }

    var sortedExercises: [LoggedExercise] {
        (exercises ?? []).sorted { $0.order < $1.order }
    }

    /// Only sets that were actually logged count — an exercise opened but not
    /// performed contributes nothing.
    var completedSets: Int {
        sortedExercises.reduce(0) { $0 + $1.sortedSets.count }
    }

    var totalLoad: Double {
        sortedExercises.reduce(0) { $0 + $1.totalLoad }
    }

    var duration: TimeInterval {
        (endedAt ?? Date()).timeIntervalSince(startedAt)
    }

    var durationText: String {
        let minutes = Int(duration / 60)
        if minutes < 60 { return "\(minutes) Min" }
        return "\(minutes / 60) Std \(minutes % 60) Min"
    }
}

/// One exercise within a session, holding the sets performed for it.
@Model
final class LoggedExercise {
    var id: UUID = UUID()
    var order: Int = 0
    /// Snapshot of the prescription, so the target stays readable even if the plan changes.
    var targetText: String = ""
    /// Prescribed rest in seconds, snapshotted alongside the target so the pause
    /// timer starts with what the plan actually asked for.
    var restSeconds: Int = 90
    /// Prescribed rep corridor, snapshotted for the progression suggestion.
    var targetRepsLower: Int = 8
    var targetRepsUpper: Int = 12

    var exercise: Exercise?
    var session: WorkoutSession?

    @Relationship(deleteRule: .cascade, inverse: \LoggedSet.loggedExercise)
    var sets: [LoggedSet]? = []

    init(
        id: UUID = UUID(),
        order: Int = 0,
        targetText: String = "",
        restSeconds: Int = 90,
        targetReps: ClosedRange<Int> = 8...12,
        exercise: Exercise? = nil
    ) {
        self.id = id
        self.order = order
        self.targetText = targetText
        self.restSeconds = restSeconds
        self.targetRepsLower = targetReps.lowerBound
        self.targetRepsUpper = targetReps.upperBound
        self.exercise = exercise
    }

    var targetReps: ClosedRange<Int> {
        targetRepsLower...max(targetRepsUpper, targetRepsLower)
    }

    var name: String { exercise?.name ?? "Übung" }

    var sortedSets: [LoggedSet] {
        (sets ?? []).sorted { $0.order < $1.order }
    }

    /// Weight × reps, summed. A rough tonnage figure, useful for comparing the
    /// same exercise across sessions.
    var totalLoad: Double {
        sortedSets.reduce(0) { $0 + $1.load }
    }

    var lastSet: LoggedSet? { sortedSets.last }

    /// Next order index, so sets stay in the sequence they were performed.
    var nextOrder: Int { (sortedSets.last?.order ?? -1) + 1 }
}

nonisolated enum SetType: String, CaseIterable, Codable, Hashable, Sendable {
    case warmUp, working, drop, failure, superset

    var displayName: String {
        switch self {
        case .warmUp: "Aufwärmen"
        case .working: "Arbeitssatz"
        case .drop: "Dropsatz"
        case .failure: "Bis Versagen"
        case .superset: "Supersatz"
        }
    }

    var shortLabel: String? {
        switch self {
        case .warmUp: "Warm-up"
        case .working: nil
        case .drop: "Drop"
        case .failure: "Versagen"
        case .superset: "Supersatz"
        }
    }

    var contributesToProgress: Bool { self != .warmUp }
}

/// A single logged set.
@Model
final class LoggedSet {
    var id: UUID = UUID()
    var order: Int = 0
    var weight: Double = 0
    var reps: Int = 0
    var rir: Int?
    /// A raw value keeps existing stores and older exports compatible.
    var typeRaw: String = SetType.working.rawValue
    var completedAt: Date = Date()

    var loggedExercise: LoggedExercise?

    init(
        id: UUID = UUID(),
        order: Int = 0,
        weight: Double = 0,
        reps: Int = 0,
        rir: Int? = nil,
        type: SetType = .working,
        completedAt: Date = Date()
    ) {
        self.id = id
        self.order = order
        self.weight = weight
        self.reps = reps
        self.rir = rir
        self.typeRaw = type.rawValue
        self.completedAt = completedAt
    }

    var load: Double { weight * Double(reps) }

    var type: SetType {
        get { SetType(rawValue: typeRaw) ?? .working }
        set { typeRaw = newValue.rawValue }
    }

    var weightText: String {
        weight.formatted(.number.grouping(.never).precision(.fractionLength(0...1)))
    }

    /// "60 kg × 8". Bodyweight sets are logged with weight 0; "KG" would read as
    /// the kilogram unit right next to it, so they say "Eigengewicht".
    var summary: String {
        weight > 0 ? "\(weightText) kg × \(reps)" : "Eigengewicht × \(reps)"
    }
}
