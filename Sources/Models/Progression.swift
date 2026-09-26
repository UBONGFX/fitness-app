import Foundation

/// What to attempt next for one exercise.
nonisolated struct ProgressionSuggestion: Equatable, Sendable {
    let weight: Double
    let reps: Int
    /// True when the weight goes up, false when the target is more reps at the same weight.
    let raisesWeight: Bool
    /// One line explaining where the number comes from, shown under the exercise.
    let rationale: String
}

/// Double progression, following `progressionsregeln_muskelaufbau.html`:
/// "Wenn du alle vorgegebenen Sätze und Wiederholungen mit guter Technik
/// abgeschlossen hast, steigere beim nächsten Training das Gewicht."
///
/// So: work the rep range up at a fixed weight; once every set reaches the top
/// of the range, add weight and start again at the bottom.
nonisolated enum Progression {

    /// Sets of `exercise` from the most recent **finished** session that contains it.
    /// The running session is excluded — the point is to compare against last time.
    static func lastSets(
        for exerciseID: UUID,
        excluding current: WorkoutSession?,
        in sessions: [WorkoutSession]
    ) -> (sets: [LoggedSet], date: Date)? {
        sessions
            .filter { $0.id != current?.id && !$0.isActive }
            .sorted { $0.startedAt > $1.startedAt }
            .lazy
            .compactMap { session -> (sets: [LoggedSet], date: Date)? in
                let sets = session.sortedExercises
                    .filter { $0.exercise?.id == exerciseID }
                    .flatMap(\.sortedSets)
                return sets.isEmpty ? nil : (sets, session.startedAt)
            }
            .first
    }

    /// `nil` when there is nothing to go on — a suggestion invented from no data
    /// would be worse than none.
    static func suggest(
        stepKg: Double,
        targetReps: ClosedRange<Int>,
        lastSets: [LoggedSet]
    ) -> ProgressionSuggestion? {
        guard !lastSets.isEmpty else { return nil }

        // The working weight is the heaviest one actually used; warm-up-ish
        // lighter sets should not drag the suggestion down.
        let workingWeight = lastSets.map(\.weight).max() ?? 0
        let setsAtWorkingWeight = lastSets.filter { $0.weight == workingWeight }
        let bestReps = setsAtWorkingWeight.map(\.reps).max() ?? 0
        let allReachedTop = setsAtWorkingWeight.allSatisfy { $0.reps >= targetReps.upperBound }

        if allReachedTop {
            return ProgressionSuggestion(
                weight: workingWeight + stepKg,
                reps: targetReps.lowerBound,
                raisesWeight: true,
                rationale: "Letztes Mal alle Sätze auf \(targetReps.upperBound) Wdh. — "
                    + "+\(format(stepKg)) kg, wieder bei \(targetReps.lowerBound) anfangen."
            )
        }

        let nextReps = min(max(bestReps + 1, targetReps.lowerBound), targetReps.upperBound)
        return ProgressionSuggestion(
            weight: workingWeight,
            reps: nextReps,
            raisesWeight: false,
            rationale: "Letztes Mal \(format(workingWeight)) kg × \(bestReps) — "
                + "Gewicht halten, \(nextReps) Wdh. anpeilen."
        )
    }

    static func format(_ value: Double) -> String {
        value.formatted(.number.grouping(.never).precision(.fractionLength(0...1)))
    }
}
