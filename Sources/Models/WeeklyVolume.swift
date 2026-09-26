import Foundation

/// Weekly working sets for one muscle group.
nonisolated struct VolumeRow: Identifiable, Equatable, Sendable {
    let muscle: MuscleGroup
    let directSets: Int
    let indirectSets: Int

    var id: String { muscle.rawValue }

    /// Secondary involvement counts half.
    var weightedIndirect: Double { Double(indirectSets) * 0.5 }
    var total: Double { Double(directSets) + weightedIndirect }

    var totalText: String { WeeklyVolume.format(total) }

    /// "13 + 7,5" — omitted entirely when nothing indirect contributes, so a bar
    /// without secondary work does not carry a pointless "+ 0".
    var breakdownText: String? {
        guard indirectSets > 0 else { return nil }
        return "\(directSets) + \(WeeklyVolume.format(weightedIndirect))"
    }
}

/// Weekly set volume per muscle group.
///
/// **Volume = direct sets + 0,5 × indirect sets**.
nonisolated enum WeeklyVolume {
    /// A general hypertrophy guideline, shown as a reference band.
    static let guidelineRange: ClosedRange<Double> = 10...20

    /// Only training days count.
    ///
    /// This mattered the moment a day's category became editable: switching a
    /// day to "Ruhetag" has to take its sets out of the week, not leave them
    /// silently counted. Exercises stay on the day so nothing is lost when it is
    /// switched back.
    static func rows(for plan: WorkoutPlan) -> [VolumeRow] {
        rows(from: plan.trainingDays.flatMap(\.sortedExercises))
    }

    static func rows(from prescriptions: [PlanExercise]) -> [VolumeRow] {
        var direct: [MuscleGroup: Int] = [:]
        var indirect: [MuscleGroup: Int] = [:]

        for prescription in prescriptions {
            guard let exercise = prescription.exercise else { continue }
            direct[exercise.primary, default: 0] += prescription.sets
            for muscle in exercise.secondary {
                indirect[muscle, default: 0] += prescription.sets
            }
        }

        return MuscleGroup.allCases
            .map { muscle in
                VolumeRow(
                    muscle: muscle,
                    directSets: direct[muscle, default: 0],
                    indirectSets: indirect[muscle, default: 0]
                )
            }
            .filter { $0.directSets > 0 || $0.indirectSets > 0 }
            .sorted { lhs, rhs in
                // Highest volume first. Ties fall back to
                // the enum order so the chart never reshuffles between redraws.
                if lhs.total != rhs.total { return lhs.total > rhs.total }
                return lhs.muscle.rawValue < rhs.muscle.rawValue
            }
    }

    /// One decimal, trimmed — "16" not "16,0", but "20,5" stays "20,5".
    static func format(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...1)))
    }

    /// Groups whose weekly volume sits below the guideline band.
    static func belowGuideline(_ rows: [VolumeRow]) -> [VolumeRow] {
        rows.filter { $0.total < guidelineRange.lowerBound }
    }
}
