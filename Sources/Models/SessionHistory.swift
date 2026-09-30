import Foundation

/// One exercise as it was performed in one past session.
///
/// Not `Sendable`: it holds `LoggedSet` model objects, which belong to their
/// context. This type is a read-side view for the UI, not something to hand
/// across actors.
nonisolated struct ExerciseHistoryEntry: Identifiable {
    let id: UUID
    let date: Date
    let sessionName: String
    let sets: [LoggedSet]

    /// Heaviest weight actually used — the working weight for that day.
    var workingWeight: Double { sets.map(\.weight).max() ?? 0 }

    var setsAtWorkingWeight: [LoggedSet] {
        sets.filter { $0.weight == workingWeight }
    }

    /// "4 × 8 @ 60 kg" when the sets are uniform, otherwise each set listed.
    var summary: String {
        let atWorking = setsAtWorkingWeight
        let reps = Set(atWorking.map(\.reps))
        if reps.count == 1, let only = reps.first, atWorking.count == sets.count {
            let weight = workingWeight > 0 ? " @ \(Progression.format(workingWeight)) kg" : ""
            return "\(sets.count) × \(only)\(weight)"
        }
        return sets.map(\.summary).joined(separator: " · ")
    }
}

/// Reading past sessions: what was done, and how the working weight moved.
nonisolated enum SessionHistory {

    /// Finished sessions, newest first. The running one is not history yet.
    static func finished(_ sessions: [WorkoutSession]) -> [WorkoutSession] {
        sessions
            .filter { !$0.isActive && $0.completedSets > 0 }
            .sorted { $0.startedAt > $1.startedAt }
    }

    /// Every past appearance of one exercise, newest first.
    static func entries(for exerciseID: UUID, in sessions: [WorkoutSession]) -> [ExerciseHistoryEntry] {
        finished(sessions).compactMap { session in
            let sets = session.sortedExercises
                .filter { $0.exercise?.id == exerciseID }
                .flatMap(\.sortedSets)
                .filter { $0.type.contributesToProgress }
            guard !sets.isEmpty else { return nil }
            return ExerciseHistoryEntry(
                id: session.id,
                date: session.startedAt,
                sessionName: session.dayName,
                sets: sets
            )
        }
    }

    /// Change in working weight from the oldest to the newest entry.
    /// `nil` with fewer than two entries — a single session is not a trend.
    static func weightTrend(_ entries: [ExerciseHistoryEntry]) -> Double? {
        guard entries.count > 1,
              let newest = entries.first?.workingWeight,
              let oldest = entries.last?.workingWeight
        else { return nil }
        return newest - oldest
    }

    static func trendText(_ entries: [ExerciseHistoryEntry]) -> String? {
        guard let trend = weightTrend(entries),
              let oldest = entries.last?.workingWeight,
              let newest = entries.first?.workingWeight
        else { return nil }
        let arrow = trend > 0 ? "↑" : (trend < 0 ? "↓" : "→")
        return "\(Progression.format(oldest)) \(arrow) \(Progression.format(newest)) kg"
    }

    /// Total tonnage across all listed sessions, for the history header.
    static func totalLoad(_ sessions: [WorkoutSession]) -> Double {
        sessions.reduce(0) { $0 + $1.totalLoad }
    }
}
