import Foundation
import SwiftData

/// One measuring session — taken monthly, in the morning, fasted.
///
/// CloudKit compatibility rules apply throughout: every attribute has a default
/// value, nothing is `@Attribute(.unique)`, and metric values are optional so a
/// partial measurement (a month where not everything was measured) is valid.
@Model
final class BodyMeasurement {
    var id: UUID = UUID()
    var date: Date = Date()
    var note: String = ""

    var weight: Double?
    var bodyFat: Double?
    var ffmi: Double?
    var chest: Double?
    var shoulders: Double?
    var waist: Double?
    var belly: Double?
    var armRelaxed: Double?
    var armFlexed: Double?
    var thigh: Double?
    var calf: Double?
    var hips: Double?

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        note: String = "",
        weight: Double? = nil,
        bodyFat: Double? = nil,
        ffmi: Double? = nil,
        chest: Double? = nil,
        shoulders: Double? = nil,
        waist: Double? = nil,
        belly: Double? = nil,
        armRelaxed: Double? = nil,
        armFlexed: Double? = nil,
        thigh: Double? = nil,
        calf: Double? = nil,
        hips: Double? = nil
    ) {
        self.id = id
        self.date = date
        self.note = note
        self.weight = weight
        self.bodyFat = bodyFat
        self.ffmi = ffmi
        self.chest = chest
        self.shoulders = shoulders
        self.waist = waist
        self.belly = belly
        self.armRelaxed = armRelaxed
        self.armFlexed = armFlexed
        self.thigh = thigh
        self.calf = calf
        self.hips = hips
    }

    subscript(metric: BodyMetric) -> Double? {
        get {
            switch metric {
            case .weight: weight
            case .bodyFat: bodyFat
            case .ffmi: ffmi
            case .chest: chest
            case .shoulders: shoulders
            case .waist: waist
            case .belly: belly
            case .armRelaxed: armRelaxed
            case .armFlexed: armFlexed
            case .thigh: thigh
            case .calf: calf
            case .hips: hips
            }
        }
        set {
            switch metric {
            case .weight: weight = newValue
            case .bodyFat: bodyFat = newValue
            case .ffmi: ffmi = newValue
            case .chest: chest = newValue
            case .shoulders: shoulders = newValue
            case .waist: waist = newValue
            case .belly: belly = newValue
            case .armRelaxed: armRelaxed = newValue
            case .armFlexed: armFlexed = newValue
            case .thigh: thigh = newValue
            case .calf: calf = newValue
            case .hips: hips = newValue
            }
        }
    }

    /// Metrics that actually carry a value, for compact display.
    var filledMetrics: [BodyMetric] {
        BodyMetric.allCases.filter { self[$0] != nil }
    }

    /// Fat-free mass index, derived from weight, body fat, and the profile height.
    static func calculateFFMI(weight: Double, bodyFat: Double, heightMeters: Double) -> Double {
        let fatFreeMass = weight * (1 - bodyFat / 100)
        return fatFreeMass / (heightMeters * heightMeters)
    }
}
