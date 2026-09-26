import SwiftUI

/// Push / Pull / Legs — plus the two non-training day kinds used by the plan.
/// Push / Pull / Legs, plus the one kind of non-training day.
///
/// There used to be a separate "Bürotag" alongside "Ruhetag". Two names for
/// "no training today" is one too many — old data carrying `office` falls back
/// to `rest` through the raw-value initialiser.
nonisolated enum TrainingCategory: String, CaseIterable, Codable, Identifiable, Sendable {
    case push
    case pull
    case legs
    case general
    case rest

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .push: "Push"
        case .pull: "Pull"
        case .legs: "Beine"
        case .general: "Training"
        case .rest: "Ruhetag"
        }
    }

    /// Short badge label for workout cards.
    var badge: String {
        switch self {
        case .push: "BST"
        case .pull: "RB"
        case .legs: "BWB"
        case .general: "Training"
        case .rest: "Pause"
        }
    }

    var color: Color {
        switch self {
        case .push: .purple
        case .pull: .green
        case .legs: .orange
        case .general: .blue
        case .rest: .secondary
        }
    }

    var isTrainingDay: Bool {
        self != .rest
    }
}
