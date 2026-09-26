import SwiftUI

/// The muscle groups tracked by the workout volume analysis.
nonisolated enum MuscleGroup: String, CaseIterable, Codable, Identifiable, Sendable {
    case chest
    case frontDelts
    case sideDelts
    case rearDelts
    case back
    case lowerBack
    case biceps
    case triceps
    case quads
    case hamstrings
    case calves

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .chest: "Brust"
        case .frontDelts: "Schulter (Front)"
        case .sideDelts: "Seitl. Schulter"
        case .rearDelts: "Hint. Schulter"
        case .back: "Rücken"
        case .lowerBack: "Unt. Rücken"
        case .biceps: "Bizeps"
        case .triceps: "Trizeps"
        case .quads: "Quadrizeps"
        case .hamstrings: "Hamstrings"
        case .calves: "Waden"
        }
    }

    /// Which training day a group primarily belongs to — drives the accent colour.
    var category: TrainingCategory {
        switch self {
        case .chest, .frontDelts, .sideDelts, .triceps: .push
        case .rearDelts, .back, .lowerBack, .biceps: .pull
        case .quads, .hamstrings, .calves: .legs
        }
    }

    // No per-muscle palette here on purpose.
    //
    // Eleven hues could not be told apart in dark mode — rear delts, lower back
    // and biceps were all the same blue-green — and they carried no information:
    // every place that showed a colour also spelled the muscle out next to it.
    // The UI uses `category.color` instead: three colours that actually mean
    // something (push, pull, legs), and always distinguishable.
}
