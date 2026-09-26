import Foundation

/// One plotted value: a metric reading at a point in time.
struct MetricPoint: Identifiable, Equatable, Sendable {
    let id: UUID
    let date: Date
    let value: Double
}

/// Turns measurements into a plottable series.
///
/// Kept free of SwiftUI and SwiftData so the selection and trend maths can be
/// tested directly instead of through the chart.
nonisolated enum MeasurementSeries {
    /// Chronological points for one metric. Measurements without a value for
    /// that metric are skipped — a missing month must not read as a drop to zero.
    static func points(for metric: BodyMetric, from measurements: [BodyMeasurement]) -> [MetricPoint] {
        measurements
            .compactMap { measurement in
                guard let value = measurement[metric] else { return nil }
                return MetricPoint(id: measurement.id, date: measurement.date, value: value)
            }
            .sorted { $0.date < $1.date }
    }

    /// Difference between the first and the most recent reading.
    static func change(in points: [MetricPoint]) -> Double? {
        guard let first = points.first, let last = points.last, points.count > 1 else { return nil }
        return last.value - first.value
    }

    /// The point closest to a date, used to resolve a chart selection.
    static func nearest(to date: Date, in points: [MetricPoint]) -> MetricPoint? {
        points.min { lhs, rhs in
            abs(lhs.date.timeIntervalSince(date)) < abs(rhs.date.timeIntervalSince(date))
        }
    }

    /// A y-range with headroom, so the line never touches the plot edges.
    /// Circumference metrics vary by a few centimetres, so a zero-based axis
    /// would flatten every trend into a straight line.
    /// `covering` pulls extra values into the range — the goal corridor, so the
    /// target band stays visible instead of sitting outside the plot.
    static func range(for points: [MetricPoint], covering extra: [Double] = []) -> ClosedRange<Double>? {
        let values = points.map(\.value) + extra
        guard let low = values.min(), let high = values.max() else { return nil }
        if low == high {
            let padding = max(abs(low) * 0.05, 1)
            return (low - padding)...(high + padding)
        }
        let padding = (high - low) * 0.2
        return (low - padding)...(high + padding)
    }
}
