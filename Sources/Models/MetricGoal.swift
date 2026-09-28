import Foundation
import SwiftData

nonisolated enum GoalPriority: String, Codable, CaseIterable, Sendable {
    case primary
    case secondary

    var displayName: String {
        switch self {
        case .primary: "Primär"
        case .secondary: "Sekundär"
        }
    }

    var sortOrder: Int { self == .primary ? 0 : 1 }
}

/// A target corridor for one metric, e.g. weight 80–82 kg.
///
/// CloudKit rules again: defaults everywhere, no unique constraint. The metric is
/// stored as its raw string so the schema survives reordering the enum.
@Model
final class MetricGoal {
    var id: UUID = UUID()
    var metricRaw: String = BodyMetric.weight.rawValue
    var lowerBound: Double = 0
    var upperBound: Double = 0
    /// Existing records had numeric targets, so migration keeps that meaning.
    var hasTarget: Bool = true
    /// Existing goals become secondary when this field is added to the store.
    var priorityRaw: String = GoalPriority.secondary.rawValue

    init(
        id: UUID = UUID(),
        metric: BodyMetric = .weight,
        lowerBound: Double = 0,
        upperBound: Double = 0,
        priority: GoalPriority = .secondary,
        hasTarget: Bool = true
    ) {
        self.id = id
        self.metricRaw = metric.rawValue
        self.lowerBound = lowerBound
        self.upperBound = upperBound
        self.priorityRaw = priority.rawValue
        self.hasTarget = hasTarget
    }

    var metric: BodyMetric {
        get { BodyMetric(rawValue: metricRaw) ?? .weight }
        set { metricRaw = newValue.rawValue }
    }

    var priority: GoalPriority {
        get { GoalPriority(rawValue: priorityRaw) ?? .secondary }
        set { priorityRaw = newValue.rawValue }
    }

    /// A single-value goal such as FFMI 21,5 is stored as a corridor of zero width.
    var isSingleValue: Bool { abs(upperBound - lowerBound) < 1e-9 }

    var formattedTarget: String {
        guard hasTarget else { return "Beobachten" }
        let metric = metric
        if isSingleValue {
            return metric.formatted(lowerBound)
        }
        // Display always reads low-to-high, whatever order the bounds were entered in.
        let low = min(lowerBound, upperBound).formatted(.number.precision(.fractionLength(0...1)))
        let high = max(lowerBound, upperBound).formatted(.number.precision(.fractionLength(0...1)))
        return metric.unit.isEmpty ? "\(low)–\(high)" : "\(low)–\(high) \(metric.unit)"
    }
}
