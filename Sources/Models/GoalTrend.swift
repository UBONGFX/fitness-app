import Foundation

/// One goal as the home screen shows it: where it stands, and which way it moved
/// during the selected period.
nonisolated struct GoalTrend: Identifiable, Equatable, Sendable {
    let metric: BodyMetric
    let targetText: String
    /// Most recent reading, `nil` when the metric has never been measured.
    let current: Double?
    /// Progress from the very first reading to the goal corridor.
    let evaluation: GoalEvaluation?
    /// Reading the period is compared against, `nil` when there is nothing to
    /// compare — a single measurement is a value, not a trend.
    let baseline: Double?

    var id: String { metric.rawValue }

    var currentText: String? { current.map { metric.formatted($0) } }

    /// Raw change in the metric, e.g. −1,2 kg. Signed as measured, not as judged.
    var delta: Double? {
        guard let current, let baseline else { return nil }
        return current - baseline
    }

    /// How much of the gap to the goal corridor was closed during the period.
    ///
    /// Positive means closer, negative means further away. This is the number the
    /// question "bin ich meinem Ziel nähergekommen?" actually asks about — the raw
    /// delta cannot answer it, because for body fat down is good and for chest
    /// circumference up is.
    let closedDistance: Double?

    var direction: Direction {
        guard let closedDistance else { return .unknown }
        if abs(closedDistance) < 0.05 { return .unchanged }
        return closedDistance > 0 ? .closer : .further
    }

    enum Direction: Equatable, Sendable {
        case closer, further, unchanged, unknown
    }

    /// "−1,2 kg" — the measured change, always with an explicit sign so a drop is
    /// never mistaken for a value.
    var deltaText: String? {
        guard let delta else { return nil }
        let number = abs(delta).formatted(.number.precision(.fractionLength(0...1)))
        let sign = delta < 0 ? "−" : "+"
        let unit = metric.unit.isEmpty ? "" : " \(metric.unit)"
        return "\(sign)\(number)\(unit)"
    }
}

/// Builds the goal overview shown on the home screen.
nonisolated enum GoalTrends {

    static func trends(
        goals: [MetricGoal],
        measurements: [BodyMeasurement],
        period: GoalPeriod,
        now: Date = Date(),
        calendar: Calendar = GoalPeriod.calendar
    ) -> [GoalTrend] {
        let periodStart = period.interval(containing: now, calendar: calendar).start
        return goals
            .sorted { lhs, rhs in
                // Follow the metric order used everywhere else rather than the
                // order goals happened to be created in.
                let all = BodyMetric.allCases
                let left = all.firstIndex(of: lhs.metric) ?? all.count
                let right = all.firstIndex(of: rhs.metric) ?? all.count
                return left < right
            }
            .map { goal in
                trend(for: goal, measurements: measurements, periodStart: periodStart)
            }
    }

    static func trend(
        for goal: MetricGoal,
        measurements: [BodyMeasurement],
        periodStart: Date
    ) -> GoalTrend {
        let points = MeasurementSeries.points(for: goal.metric, from: measurements)
        let current = points.last
        let baseline = baseline(in: points, periodStart: periodStart, current: current)

        let evaluation = current.flatMap { latest -> GoalEvaluation? in
            guard let first = points.first else { return nil }
            return GoalProgress.evaluate(
                start: first.value,
                current: latest.value,
                lower: goal.lowerBound,
                upper: goal.upperBound
            )
        }

        let closed: Double? = {
            guard let current, let baseline else { return nil }
            return distanceToCorridor(baseline.value, lower: goal.lowerBound, upper: goal.upperBound)
                - distanceToCorridor(current.value, lower: goal.lowerBound, upper: goal.upperBound)
        }()

        return GoalTrend(
            metric: goal.metric,
            targetText: goal.formattedTarget,
            current: current?.value,
            evaluation: evaluation,
            baseline: baseline?.value,
            closedDistance: closed
        )
    }

    /// What the period is measured against: the last reading taken **before** the
    /// period began, so "diesen Monat" means the change since the month started.
    ///
    /// With no earlier reading the first one inside the period stands in — better
    /// a partial window than no answer at all. Returns `nil` when that would be
    /// the current reading itself, because comparing a value to itself would
    /// always report "unverändert" and read as a measured fact.
    static func baseline(in points: [MetricPoint], periodStart: Date, current: MetricPoint?) -> MetricPoint? {
        let candidate = points.last { $0.date < periodStart }
            ?? points.first { $0.date >= periodStart }
        guard let candidate, candidate.id != current?.id else { return nil }
        return candidate
    }

    /// Distance from a value to the goal corridor; zero once inside it.
    static func distanceToCorridor(_ value: Double, lower: Double, upper: Double) -> Double {
        let low = min(lower, upper)
        let high = max(lower, upper)
        if value < low { return low - value }
        if value > high { return value - high }
        return 0
    }
}
