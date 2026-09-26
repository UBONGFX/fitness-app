import Foundation
import SwiftData

/// Public starter catalogue. Measurements, goals, and workout history belong to
/// the person using the app and are created on-device, never bundled in source.
enum SeedData {
    private static let seededKey = "didSeedExerciseCatalogue"

    static func seedIfNeeded(_ context: ModelContext) {
        guard !UserDefaults.standard.bool(forKey: seededKey) else { return }
        // Stores made by older builds already have a catalogue. Leave those
        // records alone, including any edits made by the user.
        if let existing = try? context.fetch(FetchDescriptor<Exercise>()), !existing.isEmpty {
            UserDefaults.standard.set(true, forKey: seededKey)
            return
        }
        seed(context)
        UserDefaults.standard.set(true, forKey: seededKey)
    }

    /// A small generic catalogue for new installs and isolated UI tests.
    static func seed(_ context: ModelContext) {
        for exercise in sampleExercises() {
            context.insert(exercise)
        }
        try? context.save()
    }

    static func sampleExercises() -> [Exercise] {
        [
            Exercise(name: "Bankdrücken", primary: .chest, secondary: [.frontDelts, .triceps], kind: .compound),
            Exercise(name: "Butterfly", primary: .chest, kind: .isolation),
            Exercise(name: "Rudern", primary: .back, secondary: [.biceps], kind: .compound),
            Exercise(name: "Latzug", primary: .back, secondary: [.biceps], kind: .compound),
            Exercise(name: "Schulterdrücken", primary: .frontDelts, secondary: [.triceps], kind: .compound),
            Exercise(name: "Seitheben", primary: .sideDelts, kind: .isolation),
            Exercise(name: "Beinpresse", primary: .quads, secondary: [.hamstrings], kind: .compound),
            Exercise(name: "Beinbeuger", primary: .hamstrings, kind: .isolation),
            Exercise(name: "Bizepscurls", primary: .biceps, kind: .isolation),
            Exercise(name: "Trizepsdrücken", primary: .triceps, kind: .isolation),
        ]
    }
}
