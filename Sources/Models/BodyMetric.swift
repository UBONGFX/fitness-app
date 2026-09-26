import Foundation

/// The twelve tracked body metrics, in the order they are entered and displayed.
nonisolated enum BodyMetric: String, CaseIterable, Codable, Identifiable, Sendable {
    case weight
    case bodyFat
    case ffmi
    case chest
    case shoulders
    case waist
    case belly
    case armRelaxed
    case armFlexed
    case thigh
    case calf
    case hips

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .weight: "Gewicht"
        case .bodyFat: "Körperfett"
        case .ffmi: "FFMI"
        case .chest: "Brust"
        case .shoulders: "Schultern"
        case .waist: "Taille"
        case .belly: "Bauch"
        case .armRelaxed: "Oberarm entsp."
        case .armFlexed: "Oberarm angesp."
        case .thigh: "Oberschenkel"
        case .calf: "Wade"
        case .hips: "Hüfte"
        }
    }

    var unit: String {
        switch self {
        case .weight: "kg"
        case .bodyFat: "%"
        case .ffmi: ""
        default: "cm"
        }
    }

    /// Metrics that describe body composition rather than a circumference.
    var isComposition: Bool {
        self == .weight || self == .bodyFat || self == .ffmi
    }

    func formatted(_ value: Double) -> String {
        let number = value.formatted(.number.precision(.fractionLength(0...1)))
        return unit.isEmpty ? number : "\(number) \(unit)"
    }
}
