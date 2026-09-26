import Foundation

/// A weight / body-fat reading from Health, stripped of the HealthKit types so
/// the merge rules can be tested without a health store.
nonisolated struct HealthSample: Equatable, Sendable {
    let date: Date
    var weightKg: Double?
    var bodyFatPercent: Double?
}

/// What an import from Health would change.
nonisolated struct HealthMergePlan: Equatable, Sendable {
    /// Samples that become new measurements.
    var creations: [HealthSample] = []
    /// Existing measurement id → the values to fill in.
    var updates: [UUID: HealthSample] = [:]
    /// Samples that add nothing, because that day already has those values.
    var skipped: Int = 0

    var isEmpty: Bool { creations.isEmpty && updates.isEmpty }

    var summary: String {
        guard !isEmpty else { return "Nichts zu übernehmen — alles schon erfasst." }
        var parts: [String] = []
        if !creations.isEmpty { parts.append("\(creations.count) neu") }
        if !updates.isEmpty { parts.append("\(updates.count) ergänzt") }
        if skipped > 0 { parts.append("\(skipped) übersprungen") }
        return parts.joined(separator: " · ")
    }
}

/// Merging Health readings into the app's own measurements.
///
/// Two decisions worth stating:
///
/// - **One measurement per calendar day.** Health delivers a reading per
///   weigh-in; the app tracks a monthly body-measurement session. Without
///   collapsing by day, a scale that syncs every morning would bury the manual
///   measurements under hundreds of near-identical rows.
/// - **Manual values win.** Health only fills gaps, never overwrites a number
///   that was typed in. A tape measure beats a bio-impedance estimate, and
///   silently replacing an entered value would be the worse surprise.
nonisolated enum HealthImport {

    static func plan(
        samples: [HealthSample],
        existing: [BodyMeasurement],
        calendar: Calendar = .current
    ) -> HealthMergePlan {
        var plan = HealthMergePlan()

        // One sample per day; later readings win within the same day.
        var byDay: [Date: HealthSample] = [:]
        for sample in samples.sorted(by: { $0.date < $1.date }) {
            let day = calendar.startOfDay(for: sample.date)
            var merged = byDay[day] ?? HealthSample(date: sample.date)
            merged = HealthSample(
                date: sample.date,
                weightKg: sample.weightKg ?? merged.weightKg,
                bodyFatPercent: sample.bodyFatPercent ?? merged.bodyFatPercent
            )
            byDay[day] = merged
        }

        let existingByDay = Dictionary(
            existing.map { (calendar.startOfDay(for: $0.date), $0) },
            uniquingKeysWith: { first, _ in first }
        )

        for day in byDay.keys.sorted() {
            guard let sample = byDay[day] else { continue }
            guard sample.weightKg != nil || sample.bodyFatPercent != nil else {
                plan.skipped += 1
                continue
            }

            guard let measurement = existingByDay[day] else {
                plan.creations.append(sample)
                continue
            }

            let needsWeight = measurement.weight == nil && sample.weightKg != nil
            let needsBodyFat = measurement.bodyFat == nil && sample.bodyFatPercent != nil
            if needsWeight || needsBodyFat {
                plan.updates[measurement.id] = HealthSample(
                    date: sample.date,
                    weightKg: needsWeight ? sample.weightKg : nil,
                    bodyFatPercent: needsBodyFat ? sample.bodyFatPercent : nil
                )
            } else {
                plan.skipped += 1
            }
        }
        return plan
    }

    /// Applies a plan. FFMI is recomputed whenever both inputs are present, so an
    /// imported weight does not sit next to a stale index.
    static func makeMeasurement(from sample: HealthSample, heightMeters: Double) -> BodyMeasurement {
        let measurement = BodyMeasurement(
            date: sample.date,
            note: "aus Health",
            weight: sample.weightKg,
            bodyFat: sample.bodyFatPercent
        )
        measurement.ffmi = derivedFFMI(
            weight: sample.weightKg,
            bodyFat: sample.bodyFatPercent,
            heightMeters: heightMeters
        )
        return measurement
    }

    static func apply(
        _ sample: HealthSample,
        to measurement: BodyMeasurement,
        heightMeters: Double
    ) {
        if let weight = sample.weightKg, measurement.weight == nil {
            measurement.weight = weight
        }
        if let bodyFat = sample.bodyFatPercent, measurement.bodyFat == nil {
            measurement.bodyFat = bodyFat
        }
        if measurement.ffmi == nil {
            measurement.ffmi = derivedFFMI(
                weight: measurement.weight,
                bodyFat: measurement.bodyFat,
                heightMeters: heightMeters
            )
        }
    }

    static func derivedFFMI(weight: Double?, bodyFat: Double?, heightMeters: Double) -> Double? {
        guard let weight, let bodyFat, heightMeters > 0 else { return nil }
        let value = BodyMeasurement.calculateFFMI(
            weight: weight,
            bodyFat: bodyFat,
            heightMeters: heightMeters
        )
        return (value * 10).rounded() / 10
    }
}
