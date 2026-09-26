import Foundation
import SwiftData

/// How an exercise progresses, per `progressionsregeln_muskelaufbau.html`.
///
/// Stated explicitly rather than derived: a rule like "has secondary muscles =
/// compound" would classify the Butterfly as a compound lift, and it is not one.
nonisolated enum ExerciseKind: String, CaseIterable, Codable, Sendable {
    case compound
    case isolation
}

/// A movement, independent of any plan that uses it.
///
/// The muscle assignment is the whole basis of the volume analysis: `primary`
/// counts as a direct set, every `secondary` as half a set. The mapping is
/// documented and cross-checked in `docs/volume-reference.md`.
@Model
final class Exercise {
    var id: UUID = UUID()
    var name: String = ""
    var primaryRaw: String = MuscleGroup.chest.rawValue
    var secondaryRaw: [String] = []
    var kindRaw: String = ExerciseKind.compound.rawValue
    /// Overrides the rule-derived weekly step when set.
    var stepOverrideKg: Double?

    @Relationship(deleteRule: .nullify, inverse: \PlanExercise.exercise)
    var planEntries: [PlanExercise]? = []

    init(
        id: UUID = UUID(),
        name: String = "",
        primary: MuscleGroup = .chest,
        secondary: [MuscleGroup] = [],
        kind: ExerciseKind = .compound
    ) {
        self.id = id
        self.name = name
        self.primaryRaw = primary.rawValue
        self.secondaryRaw = secondary.map(\.rawValue)
        self.kindRaw = kind.rawValue
    }

    var primary: MuscleGroup {
        get { MuscleGroup(rawValue: primaryRaw) ?? .chest }
        set { primaryRaw = newValue.rawValue }
    }

    var secondary: [MuscleGroup] {
        get { secondaryRaw.compactMap(MuscleGroup.init(rawValue:)) }
        set { secondaryRaw = newValue.map(\.rawValue) }
    }

    var kind: ExerciseKind {
        get { ExerciseKind(rawValue: kindRaw) ?? .compound }
        set { kindRaw = newValue.rawValue }
    }

    /// Primary first, then the secondaries — the order badges are shown in.
    var allMuscles: [MuscleGroup] { [primary] + secondary }

    /// Weekly weight step, verbatim from `progressionsregeln_muskelaufbau.html`:
    /// compound +2,5 kg · isolation +1 kg · leg exercises +5 kg.
    /// Leg movements win over the compound/isolation split because the source
    /// states them as their own category.
    var derivedProgressionStepKg: Double {
        switch primary {
        case .quads, .hamstrings, .calves: 5.0
        default: kind == .compound ? 2.5 : 1.0
        }
    }

    /// The step actually used, with `stepOverrideKg` taking precedence.
    ///
    /// The rule is a rule of thumb, and it does not fit every movement: it puts
    /// +5 kg a week on a seated leg curl, which is a lot for an isolation
    /// exercise. Rather than quietly deviate from the documented rule, the
    /// derived value stays the default and can be overridden per exercise.
    var progressionStepKg: Double {
        stepOverrideKg ?? derivedProgressionStepKg
    }

    var usesCustomStep: Bool { stepOverrideKg != nil }
}
