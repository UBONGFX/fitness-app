import Foundation

/// One exercise on one day, reduced to the numbers that show progress.
nonisolated struct ExercisePoint: Identifiable, Equatable, Sendable {
    let id: UUID
    let date: Date
    let sessionName: String
    /// Heaviest weight used that day — the working weight.
    let workingWeight: Double
    /// Weight × reps, summed over every set that day.
    let volume: Double
    let sets: Int
    let reps: Int
    /// Best estimated one-rep max of the day, `nil` for bodyweight-only sessions.
    let estimatedOneRepMax: Double?
}

/// Reading one exercise across every session it appeared in.
///
/// Free of SwiftUI so the arithmetic that the progress screen claims can be
/// tested directly rather than through a chart.
nonisolated enum ExerciseProgress {

    /// Chronological, oldest first — the order a chart needs.
    static func points(from entries: [ExerciseHistoryEntry]) -> [ExercisePoint] {
        entries
            .map { entry in
                let sets = entry.sets
                return ExercisePoint(
                    id: entry.id,
                    date: entry.date,
                    sessionName: entry.sessionName,
                    workingWeight: entry.workingWeight,
                    volume: sets.reduce(0) { $0 + $1.load },
                    sets: sets.count,
                    reps: sets.reduce(0) { $0 + $1.reps },
                    estimatedOneRepMax: bestOneRepMax(in: sets)
                )
            }
            .sorted { $0.date < $1.date }
    }

    /// Epley: weight × (1 + reps / 30).
    ///
    /// An **estimate**, and labelled as one wherever it is shown. It is the most
    /// useful single number for progress because it folds weight and reps into
    /// one: five more reps at the same weight is progress that the working weight
    /// alone reports as standing still.
    static func epley(weight: Double, reps: Int) -> Double? {
        guard weight > 0, reps > 0 else { return nil }
        return weight * (1 + Double(reps) / 30)
    }

    /// Bodyweight sets carry no weight, so they have no estimate — counting them
    /// as zero would drag the number down on exactly the days they were trained.
    static func bestOneRepMax(in sets: [LoggedSet]) -> Double? {
        sets.compactMap { epley(weight: $0.weight, reps: $0.reps) }.max()
    }

    // MARK: - Summary

    /// Change in working weight from the first logged session to the latest.
    /// `nil` with fewer than two sessions — one session is a value, not a trend.
    static func weightChange(_ points: [ExercisePoint]) -> Double? {
        guard points.count > 1, let first = points.first, let last = points.last else { return nil }
        return last.workingWeight - first.workingWeight
    }

    /// The plotted session nearest to a finger position on a time axis.
    static func nearest(to date: Date, in points: [ExercisePoint]) -> ExercisePoint? {
        points.min { lhs, rhs in
            abs(lhs.date.timeIntervalSince(date)) < abs(rhs.date.timeIntervalSince(date))
        }
    }

    static func volumeChange(_ points: [ExercisePoint]) -> Double? {
        guard points.count > 1, let first = points.first, let last = points.last else { return nil }
        return last.volume - first.volume
    }

    /// The heaviest single set ever logged, and when.
    static func heaviestSet(in entries: [ExerciseHistoryEntry]) -> (set: LoggedSet, date: Date)? {
        entries
            .flatMap { entry in entry.sets.map { (set: $0, date: entry.date) } }
            .filter { $0.set.weight > 0 }
            .max { $0.set.weight < $1.set.weight }
    }

    /// The day with the most tonnage.
    static func bestVolume(_ points: [ExercisePoint]) -> ExercisePoint? {
        points.max { $0.volume < $1.volume }
    }

    static func bestOneRepMax(_ points: [ExercisePoint]) -> ExercisePoint? {
        points
            .filter { $0.estimatedOneRepMax != nil }
            .max { ($0.estimatedOneRepMax ?? 0) < ($1.estimatedOneRepMax ?? 0) }
    }

    /// A y-range with headroom, so a line never touches the edges of the plot.
    /// Working weights move by a few kilos, so a zero-based axis would flatten
    /// every trend into a straight line.
    static func range(of values: [Double]) -> ClosedRange<Double>? {
        guard let low = values.min(), let high = values.max() else { return nil }
        if low == high {
            let padding = max(abs(low) * 0.1, 1)
            return (low - padding)...(high + padding)
        }
        let padding = (high - low) * 0.2
        return (low - padding)...(high + padding)
    }

    /// "+5 kg" — always signed, so a drop can never be mistaken for a value.
    static func signed(_ value: Double, unit: String = "kg") -> String {
        let number = Progression.format(abs(value))
        let sign = value < 0 ? "−" : "+"
        return unit.isEmpty ? "\(sign)\(number)" : "\(sign)\(number) \(unit)"
    }
}
