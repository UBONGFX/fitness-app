import Foundation
import SwiftData

/// A legacy weekly training plan. New workouts use standalone templates.
///
/// Several plans can exist side by side — switching to full body should not cost
/// the split you might come back to — but exactly one is active at a time, and
/// that is the one the training screen, the week and the volume analysis read.
/// The flag lives on the plan rather than in a "currentPlanID" setting because
/// CloudKit gives no ordering guarantee between two records: a pointer could
/// arrive before the plan it points at.
@Model
final class WorkoutPlan {
    var id: UUID = UUID()
    var name: String = ""
    var focus: String = ""
    /// Defaulted, never unique — CloudKit forbids unique constraints, so the
    /// "only one" rule is enforced in `PlanLibrary`, not by the store.
    var isActive: Bool = false
    /// Only for ordering the library, so a newly created plan does not jump
    /// around between launches.
    var createdAt: Date = Date()

    @Relationship(deleteRule: .cascade, inverse: \PlanDay.plan)
    var days: [PlanDay]? = []

    init(
        id: UUID = UUID(),
        name: String = "",
        focus: String = "",
        isActive: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.focus = focus
        self.isActive = isActive
        self.createdAt = createdAt
    }

    /// SwiftData relationships are unordered; the week has to be sorted explicitly.
    var sortedDays: [PlanDay] {
        (days ?? []).sorted { $0.weekday < $1.weekday }
    }

    var trainingDays: [PlanDay] {
        sortedDays.filter(\.category.isTrainingDay)
    }

    var totalSets: Int {
        trainingDays.reduce(0) { $0 + $1.totalSets }
    }

    /// "5 Trainingstage · 109 Arbeitssätze" — what a plan is, in one line.
    ///
    /// "Arbeitssätze", not "Sätze": it is the word the plan editor and the volume
    /// analysis already use, and two names for the same number invite the reader
    /// to look for a difference that is not there.
    var summaryText: String {
        let days = trainingDays.count
        return "\(days) \(days == 1 ? "Trainingstag" : "Trainingstage") · \(totalSets) Arbeitssätze"
    }
}

/// One day of the week within a plan. Rest and office days carry no exercises.
@Model
final class PlanDay {
    /// 1 = Monday … 7 = Sunday.
    var id: UUID = UUID()
    var weekday: Int = 1
    var name: String = ""
    var focus: String = ""
    var categoryRaw: String = TrainingCategory.rest.rawValue
    var tip: String = ""

    var plan: WorkoutPlan?

    @Relationship(deleteRule: .cascade, inverse: \PlanExercise.day)
    var exercises: [PlanExercise]? = []

    init(
        id: UUID = UUID(),
        weekday: Int = 1,
        name: String = "",
        focus: String = "",
        category: TrainingCategory = .rest,
        tip: String = ""
    ) {
        self.id = id
        self.weekday = weekday
        self.name = name
        self.focus = focus
        self.categoryRaw = category.rawValue
        self.tip = tip
    }

    var category: TrainingCategory {
        get { TrainingCategory(rawValue: categoryRaw) ?? .rest }
        set { categoryRaw = newValue.rawValue }
    }

    var sortedExercises: [PlanExercise] {
        (exercises ?? []).sorted { $0.order < $1.order }
    }

    var totalSets: Int {
        sortedExercises.reduce(0) { $0 + $1.sets }
    }

    var shortLabel: String {
        ["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"][max(0, min(weekday - 1, 6))]
    }
}

/// One exercise as it is prescribed on a specific day: sets, rep range, rest and
/// an optional RIR target. The same `Exercise` appears on several days with
/// different prescriptions, which is why this is a separate entity.
@Model
final class PlanExercise {
    var id: UUID = UUID()
    var order: Int = 0
    var sets: Int = 0
    var repsLower: Int = 0
    var repsUpper: Int = 0
    var restLowerSeconds: Int = 90
    var restUpperSeconds: Int = 90
    var rirLower: Int?
    var rirUpper: Int?
    var note: String = ""

    var exercise: Exercise?
    var day: PlanDay?

    init(
        id: UUID = UUID(),
        order: Int = 0,
        sets: Int = 0,
        reps: ClosedRange<Int> = 8...12,
        rest: ClosedRange<Int> = 90...90,
        rir: ClosedRange<Int>? = nil,
        note: String = "",
        exercise: Exercise? = nil
    ) {
        self.id = id
        self.order = order
        self.sets = sets
        self.repsLower = reps.lowerBound
        self.repsUpper = reps.upperBound
        self.restLowerSeconds = rest.lowerBound
        self.restUpperSeconds = rest.upperBound
        self.rirLower = rir?.lowerBound
        self.rirUpper = rir?.upperBound
        self.note = note
        self.exercise = exercise
    }

    var repsText: String {
        repsLower == repsUpper ? "\(repsLower)" : "\(repsLower)–\(repsUpper)"
    }

    /// "3 Min", "2–3 Min", "90 Sek" — minutes once the value divides evenly,
    /// matching the values entered in the editor.
    var restText: String {
        func part(_ seconds: Int) -> String {
            seconds % 60 == 0 ? "\(seconds / 60)" : "\(seconds)"
        }
        let useMinutes = restLowerSeconds % 60 == 0 && restLowerSeconds >= 120
        let unit = useMinutes ? "Min" : "Sek"
        if restLowerSeconds == restUpperSeconds {
            return useMinutes ? "\(part(restLowerSeconds)) \(unit)" : "\(restLowerSeconds) \(unit)"
        }
        return "\(part(restLowerSeconds))–\(part(restUpperSeconds)) \(unit)"
    }

    var rirText: String? {
        guard let rirLower, let rirUpper else { return nil }
        return rirLower == rirUpper ? "RIR \(rirLower)" : "RIR \(rirLower)–\(rirUpper)"
    }

    var setsAndRepsText: String { "\(sets) × \(repsText)" }
}
