import Foundation

/// Four optional body ratios shown with general reference ranges.
nonisolated enum BodyProportion: String, CaseIterable, Identifiable, Sendable {
    case shouldersToWaist
    case chestToWaist
    case armToCalf
    case thighToWaist

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .shouldersToWaist: "Schulter ÷ Taille"
        case .chestToWaist: "Brust ÷ Taille"
        case .armToCalf: "Arm ÷ Wade"
        case .thighToWaist: "Oberschenkel ÷ Taille"
        }
    }

    var subtitle: String? {
        switch self {
        case .shouldersToWaist: "V-Taper — wichtigster Wert"
        case .armToCalf: "Symmetrie Ober-/Unterkörper"
        case .chestToWaist, .thighToWaist: nil
        }
    }

    var numerator: BodyMetric {
        switch self {
        case .shouldersToWaist: .shoulders
        case .chestToWaist: .chest
        case .armToCalf: .armFlexed
        case .thighToWaist: .thigh
        }
    }

    var denominator: BodyMetric {
        switch self {
        case .shouldersToWaist, .chestToWaist, .thighToWaist: .waist
        case .armToCalf: .calf
        }
    }

    /// A generic reference marker at the start of the ideal band.
    var target: Double { ideal.lowerBound }

    /// The classical ideal band. Single-value ideals are a band of zero width.
    var ideal: ClosedRange<Double> {
        switch self {
        case .shouldersToWaist: 1.50...1.62
        case .chestToWaist: 1.35...1.45
        case .armToCalf: 1.00...1.00
        case .thighToWaist: 0.75...0.75
        }
    }

    var idealText: String {
        let low = ideal.lowerBound
        let high = ideal.upperBound
        if low == high { return Self.format(low) }
        return "\(Self.format(low))–\(Self.format(high))"
    }

    /// Ratios are unitless and compared at two decimals.
    static func format(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(2)))
    }

    func value(from measurement: BodyMeasurement) -> Double? {
        guard let top = measurement[numerator],
              let bottom = measurement[denominator],
              bottom > 0
        else { return nil }
        return top / bottom
    }

    /// The most recent measurement that carries both metrics.
    ///
    /// A month where only the weight was recorded must not blank the whole card,
    /// so this falls back to the newest measurement that actually has both.
    func latestValue(from measurements: [BodyMeasurement]) -> (value: Double, date: Date)? {
        measurements
            .sorted { $0.date > $1.date }
            .lazy
            .compactMap { measurement in
                value(from: measurement).map { ($0, measurement.date) }
            }
            .first
    }
}
