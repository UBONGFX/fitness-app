import SwiftUI

/// Only selected goals appear here, grouped by the user's own priorities.
struct GoalsCard: View {
    let measurements: [BodyMeasurement]
    let goals: [MetricGoal]
    var onEdit: () -> Void

    private struct Row: Identifiable {
        let id: String
        let metric: BodyMetric
        let goal: MetricGoal
        let current: Double?
        let evaluation: GoalEvaluation?
    }

    private var rows: [Row] {
        goals.map { goal in
            let points = MeasurementSeries.points(for: goal.metric, from: measurements)
            return Row(
                id: goal.metric.rawValue,
                metric: goal.metric,
                goal: goal,
                current: points.last?.value,
                evaluation: goal.hasTarget ? points.first.flatMap { start in
                    points.last.map { current in
                        GoalProgress.evaluate(
                            start: start.value,
                            current: current.value,
                            lower: goal.lowerBound,
                            upper: goal.upperBound
                        )
                    }
                } : nil
            )
        }
        .sorted { lhs, rhs in
            let all = BodyMetric.allCases
            return (all.firstIndex(of: lhs.metric) ?? all.count)
                < (all.firstIndex(of: rhs.metric) ?? all.count)
        }
    }

    private var reachedCount: Int {
        rows.filter { $0.evaluation?.isReached == true }.count
    }

    private var targetedCount: Int {
        goals.filter(\.hasTarget).count
    }

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: Theme.Spacing.regular) {
                HStack(alignment: .firstTextBaseline) {
                    SectionHeader(
                        title: "Ziele",
                        subtitle: goals.isEmpty
                            ? "Noch keine Ziele festgelegt"
                            : targetedCount == 0
                                ? "Werte beobachten"
                                : "\(reachedCount) von \(targetedCount) Zielwerten erreicht"
                    )
                    Button("Ziele bearbeiten", systemImage: "slider.horizontal.3", action: onEdit)
                        .labelStyle(.iconOnly)
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier("editGoals")
                }

                ForEach(GoalPriority.allCases, id: \.self) { priority in
                    let group = rows.filter { $0.goal.priority == priority }
                    if !group.isEmpty {
                        Text(priority == .primary ? "Primäre Ziele" : "Sekundäre Ziele")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        ForEach(group) { row in
                            GoalRow(
                                metric: row.metric,
                                current: row.current,
                                target: row.goal.hasTarget ? row.goal.formattedTarget : nil,
                                evaluation: row.evaluation
                            )
                        }
                    }
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
    let current: Double?
    let target: String?
    let evaluation: GoalEvaluation?

    private var accessibilitySummary: String {
        var parts = [metric.displayName]
        parts.append(current.map { metric.formatted($0) } ?? "noch kein Messwert")
        if let target {
            parts.append("Zielwert \(target)")
        } else {
            parts.append("ohne Zielwert")
        }
        if let evaluation {
            parts.append(evaluation.isReached
                ? "Ziel erreicht"
                : "\(Int(evaluation.progress * 100)) Prozent Fortschritt")
        } else if target == nil {
            parts.append("Wert beobachten")
        }
        return parts.joined(separator: ", ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline) {
                Text(metric.displayName)
                    .font(.subheadline)
                Spacer(minLength: Theme.Spacing.tight)
                if let current {
                    Text(metric.formatted(current))
                        .font(.subheadline.weight(.semibold).monospacedDigit())
                }
                if let target {
                    Text("→ \(target)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if let evaluation {
                HStack(spacing: Theme.Spacing.tight) {
                    ProgressView(value: evaluation.progress)
                        .tint(.accentColor)
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
            } else if current == nil {
                Text(target == nil ? "Beobachten · noch kein Messwert" : "Noch kein Messwert")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("Wert beobachten")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilitySummary)
    }
}
