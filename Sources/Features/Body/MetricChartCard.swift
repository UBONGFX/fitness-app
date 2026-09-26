import Charts
import SwiftUI

/// Progress over time for one selectable metric.
struct MetricChartCard: View {
    let measurements: [BodyMeasurement]
    var goal: MetricGoal?
    @Binding var metric: BodyMetric

    private var points: [MetricPoint] {
        MeasurementSeries.points(for: metric, from: measurements)
    }

    private var change: Double? {
        MeasurementSeries.change(in: points)
    }

    /// Which points get their value printed above them.
    ///
    /// Replaces the tap-to-select overlay: `chartXSelection` never produced a
    /// selection in any test, tap or drag, and Swift Charts keeps annotations out
    /// of the accessibility tree anyway — so the values were neither reliable nor
    /// readable. With a handful of monthly measurements, printing them is simply
    /// better than hiding them behind a gesture. Beyond six points only the ends
    /// are labelled, or the plot turns into a wall of numbers.
    private var labelledPointIDs: Set<UUID> {
        guard points.count > 6 else { return Set(points.map(\.id)) }
        return Set([points.first, points.last].compactMap { $0?.id })
    }

    /// A spoken summary of the series, because the printed labels above are
    /// annotations and those never reach VoiceOver.
    private var seriesDescription: String {
        guard let first = points.first, let last = points.last else {
            return "Keine Werte"
        }
        if points.count == 1 {
            return "\(metric.displayName): \(metric.formatted(first.value))"
        }
        return "\(metric.displayName) über \(points.count) Messungen, "
            + "von \(metric.formatted(first.value)) auf \(metric.formatted(last.value))"
    }

    /// Padding on both ends so the final date label is not clipped at the plot
    /// edge and the last point does not collide with the y-axis labels.
    private var xDomain: ClosedRange<Date>? {
        guard let first = points.first?.date, let last = points.last?.date else { return nil }
        let threeDays: TimeInterval = 60 * 60 * 24 * 3
        let span = last.timeIntervalSince(first)
        // Asymmetric on purpose: the trailing label ("Sept. 26") is wider than the
        // leading one, so an equal margin clips it at the plot edge.
        let leading = max(span * 0.08, threeDays)
        let trailing = max(span * 0.22, threeDays * 3)
        return first.addingTimeInterval(-leading)...last.addingTimeInterval(trailing)
    }

    private var goalBounds: [Double] {
        guard let goal else { return [] }
        return [goal.lowerBound, goal.upperBound]
    }

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: Theme.Spacing.regular) {
                header
                if points.isEmpty {
                    Text("Für \(metric.displayName) ist noch nichts erfasst.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 160)
                } else {
                    chart
                }
            }
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Verlauf")
                    .font(.title3.weight(.semibold))
                if let change {
                    let sign = change > 0 ? "+" : ""
                    Text("\(sign)\(change, format: .number.precision(.fractionLength(0...1))) \(metric.unit) seit Start")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Mindestens zwei Messungen für einen Trend")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: Theme.Spacing.tight)
            Picker("Metrik", selection: $metric) {
                ForEach(BodyMetric.allCases) { option in
                    Text(option.displayName).tag(option)
                }
            }
            .pickerStyle(.menu)
            .tint(.primary)
            // SwiftUI prefixes the picker's own title to the accessibility label,
            // so the stable handle for tests is an identifier, not a label.
            .accessibilityIdentifier("metricPicker")
        }
    }

    private var chart: some View {
        Chart {
            if let goal {
                RectangleMark(
                    yStart: .value("Ziel von", min(goal.lowerBound, goal.upperBound)),
                    yEnd: .value("Ziel bis", max(goal.lowerBound, goal.upperBound))
                )
                .foregroundStyle(.green.opacity(0.14))

                RuleMark(y: .value("Ziel", goal.lowerBound))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    .foregroundStyle(.green.opacity(0.7))
            }

            ForEach(points) { point in
                LineMark(
                    x: .value("Datum", point.date),
                    y: .value(metric.displayName, point.value)
                )
                .interpolationMethod(.linear)
                .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                .foregroundStyle(.teal)

                PointMark(
                    x: .value("Datum", point.date),
                    y: .value(metric.displayName, point.value)
                )
                .symbolSize(60)
                .foregroundStyle(.teal)
                .annotation(position: .top, spacing: 4, overflowResolution: .init(x: .fit, y: .disabled)) {
                    if labelledPointIDs.contains(point.id) {
                        Text(metric.formatted(point.value))
                            .font(.caption2.weight(.semibold).monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .chartYScale(domain: MeasurementSeries.range(for: points, covering: goalBounds) ?? 0...1)
        .chartXScale(domain: xDomain ?? Date.distantPast...Date.distantFuture)
        .chartYAxis {
            // Leading, so the trailing edge stays free for the last date label.
            AxisMarks(position: .leading) { value in
                AxisGridLine().foregroundStyle(.secondary.opacity(0.25))
                AxisValueLabel {
                    if let number = value.as(Double.self) {
                        Text(number, format: .number.precision(.fractionLength(0...1)))
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: points.map(\.date)) { value in
                AxisGridLine().foregroundStyle(.secondary.opacity(0.25))
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        Text(date, format: .dateTime.month(.abbreviated).year(.twoDigits))
                    }
                }
            }
        }
        .frame(height: 200)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Verlauf")
        .accessibilityValue(seriesDescription)
        .accessibilityIdentifier("chartSummary")
    }
}
