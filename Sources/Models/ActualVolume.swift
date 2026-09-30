import Foundation

/// Planned versus performed volume for one muscle group.
nonisolated struct VolumeComparison: Identifiable, Equatable, Sendable {
    let muscle: MuscleGroup
    let planned: Double
    let actualDirect: Int
    let actualIndirect: Int

    var id: String { muscle.rawValue }

    var actual: Double { Double(actualDirect) + Double(actualIndirect) * 0.5 }

    /// Share of the plan that was actually done. Above 1 when more was trained
    /// than planned, which is information, not an error.
    var completion: Double {
        planned > 0 ? actual / planned : 0
    }

    var actualText: String { WeeklyVolume.format(actual) }
    var plannedText: String { WeeklyVolume.format(planned) }

    var breakdownText: String? {
        guard actualIndirect > 0 else { return nil }
        return "\(actualDirect) + \(WeeklyVolume.format(Double(actualIndirect) * 0.5))"
    }
}

/// A current weekly muscle total placed against a conservative, visible start
/// target. Indirect work counts as half, matching the rest of the app.
nonisolated struct MuscleWeekProgress: Identifiable, Equatable, Sendable {
    let muscle: MuscleGroup
    let effectiveSets: Double
    let previousEffectiveSets: Double
    let targetSets: Double

    var id: String { muscle.rawValue }
    var remainingSets: Double { max(0, targetSets - effectiveSets) }
    var hasReachedTarget: Bool { effectiveSets >= targetSets }
}

/// Volume actually performed, counted from logged sets.
///
/// Uses the same weighting as the plan side (`direct + 0,5 × indirect`), so the
/// two numbers are comparable. Anything else would make the comparison
/// meaningless even if each half were right on its own.
nonisolated enum ActualVolume {
    /// A practical starting target, not a claim of an individual growth
    /// threshold. Users can see exactly what is counted and adjust training from
    /// their own performance and recovery.
    static let defaultWeeklyMuscleTarget: Double = 10

    /// The Monday–Sunday week containing `date`.
    ///
    /// The plan is written Mo–So, so the training week must be too; relying on
    /// the device's locale would silently start the week on Sunday in some regions.
    static func week(containing date: Date, calendar: Calendar = .current) -> DateInterval {
        var weekCalendar = calendar
        weekCalendar.firstWeekday = 2 // Monday
        let startOfDay = weekCalendar.startOfDay(for: date)
        let weekday = SessionBuilder.planWeekday(from: weekCalendar.component(.weekday, from: startOfDay))
        let monday = weekCalendar.date(byAdding: .day, value: -(weekday - 1), to: startOfDay) ?? startOfDay
        let end = weekCalendar.date(byAdding: .day, value: 7, to: monday) ?? monday
        return DateInterval(start: monday, end: end)
    }

    /// Sessions that started within the given week and actually recorded sets.
    static func sessions(in interval: DateInterval, from sessions: [WorkoutSession]) -> [WorkoutSession] {
        sessions
            .filter { $0.completedSets > 0 && interval.contains($0.startedAt) }
            .sorted { $0.startedAt < $1.startedAt }
    }

    /// Performed sets per muscle group, weighted like the plan side.
    static func rows(from sessions: [WorkoutSession]) -> [VolumeRow] {
        var direct: [MuscleGroup: Int] = [:]
        var indirect: [MuscleGroup: Int] = [:]

        for session in sessions {
            for entry in session.sortedExercises {
                guard let exercise = entry.exercise else { continue }
                let setCount = entry.sortedSets.filter { $0.type.contributesToProgress }.count
                guard setCount > 0 else { continue }
                direct[exercise.primary, default: 0] += setCount
                for muscle in exercise.secondary {
                    indirect[muscle, default: 0] += setCount
                }
            }
        }

        return MuscleGroup.allCases
            .map { VolumeRow(muscle: $0, directSets: direct[$0, default: 0], indirectSets: indirect[$0, default: 0]) }
            .filter { $0.directSets > 0 || $0.indirectSets > 0 }
            .sorted { $0.total > $1.total }
    }

    static func weeklyProgress(
        from sessions: [WorkoutSession],
        now: Date = Date(),
        targetSets: Double = defaultWeeklyMuscleTarget
    ) -> [MuscleWeekProgress] {
        let currentInterval = week(containing: now)
        let previousInterval = DateInterval(
            start: currentInterval.start.addingTimeInterval(-7 * 86_400),
            end: currentInterval.start
        )
        let current = Dictionary(uniqueKeysWithValues: rows(from: self.sessions(in: currentInterval, from: sessions)).map { ($0.muscle, $0.total) })
        let previous = Dictionary(uniqueKeysWithValues: rows(from: self.sessions(in: previousInterval, from: sessions)).map { ($0.muscle, $0.total) })
        return MuscleGroup.allCases.compactMap { muscle in
            let value = current[muscle, default: 0]
            let prior = previous[muscle, default: 0]
            guard value > 0 || prior > 0 else { return nil }
            return MuscleWeekProgress(
                muscle: muscle,
                effectiveSets: value,
                previousEffectiveSets: prior,
                targetSets: targetSets
            )
        }
        .sorted { lhs, rhs in
            if lhs.remainingSets != rhs.remainingSets { return lhs.remainingSets > rhs.remainingSets }
            return lhs.effectiveSets > rhs.effectiveSets
        }
    }

    /// One row per muscle group the **plan** covers, so a group trained zero
    /// times this week still shows up — that is exactly what needs to be seen.
    static func comparison(plan planRows: [VolumeRow], actual actualRows: [VolumeRow]) -> [VolumeComparison] {
        let actualByMuscle = Dictionary(uniqueKeysWithValues: actualRows.map { ($0.muscle, $0) })
        return planRows.map { planned in
            let done = actualByMuscle[planned.muscle]
            return VolumeComparison(
                muscle: planned.muscle,
                planned: planned.total,
                actualDirect: done?.directSets ?? 0,
                actualIndirect: done?.indirectSets ?? 0
            )
        }
    }

    /// Overall share of the planned weekly volume that was performed.
    static func overallCompletion(_ rows: [VolumeComparison]) -> Double {
        let planned = rows.reduce(0) { $0 + $1.planned }
        guard planned > 0 else { return 0 }
        return rows.reduce(0) { $0 + $1.actual } / planned
    }
}
