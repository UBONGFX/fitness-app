import SwiftUI

/// Progress towards every goal, most-complete last so the open work reads first.
struct GoalsCard: View {
    let measurements: [BodyMeasurement]
    let goals: [MetricGoal]
    var onEdit: () -> Void

    private struct Row: Identifiable {
        let id: String
        let metric: BodyMetric
        let goal: MetricGoal
        let current: Double
        let evaluation: GoalEvaluation
    }

    private var rows: [Row] {
        goals.compactMap { goal in
            let points = MeasurementSeries.points(for: goal.metric, from: measurements)
            guard let start = points.first?.value, let current = points.last?.value else { return nil }
            return Row(
                id: goal.metric.rawValue,
                metric: goal.metric,
                goal: goal,
                current: current,
                evaluation: GoalProgress.evaluate(
                    start: start,
                    current: current,
                    lower: goal.lowerBound,
                    upper: goal.upperBound
                )
            )
        }
        .sorted { $0.evaluation.progress < $1.evaluation.progress }
    }

    private var reachedCount: Int {
        rows.filter(\.evaluation.isReached).count
    }

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: Theme.Spacing.regular) {
                HStack(alignment: .firstTextBaseline) {
                    SectionHeader(
                        title: "Ziele",
                        subtitle: goals.isEmpty
                            ? "Noch keine Ziele festgelegt"
                            : rows.isEmpty
                                ? "Noch keine Messung zum Vergleichen"
                                : "\(reachedCount) von \(rows.count) erreicht"
                    )
                    Button("Ziele bearbeiten", systemImage: "slider.horizontal.3", action: onEdit)
                        .labelStyle(.iconOnly)
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier("editGoals")
                }

                ForEach(rows) { row in
                    GoalRow(
                        metric: row.metric,
                        current: row.current,
                        target: row.goal.formattedTarget,
                        evaluation: row.evaluation
                    )
                }

                if goals.isEmpty {
                    Button("Ziele festlegen", action: onEdit)
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier("openGoals")
                }
            }
        }
    }
}

private struct GoalRow: View {
    let metric: BodyMetric
    let current: Double
    let target: String
    let evaluation: GoalEvaluation

    private var tint: Color {
        return .accentColor
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline) {
                Text(metric.displayName)
                    .font(.subheadline)
                Spacer(minLength: Theme.Spacing.tight)
                Text(metric.formatted(current))
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                Text("→ \(target)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: Theme.Spacing.tight) {
                ProgressView(value: evaluation.progress)
                    .tint(tint)
                if evaluation.isReached {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.tint)
                } else {
                    Text(evaluation.progress, format: .percent.precision(.fractionLength(0)))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(minWidth: 38, alignment: .trailing)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            evaluation.isReached
                ? "\(metric.displayName), Ziel erreicht"
                : "\(metric.displayName), \(Int(evaluation.progress * 100)) Prozent"
        )
    }
}
