import SwiftData
import SwiftUI

struct CreateWorkoutView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(SaveReporter.self) private var saveReporter

    var onCreate: (PlanDay) -> Void
    @State private var name = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name, z. B. Oberkörper", text: $name)
                        .accessibilityIdentifier("workoutName")
                } footer: {
                    Text("Du kannst Übungen nach dem Erstellen hinzufügen. Das Workout hat keinen festen Wochentag.")
                }
            }
            .glassFormBackground()
            .navigationTitle("Neues Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Erstellen") { create() }
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .accessibilityIdentifier("saveWorkout")
                }
            }
        }
    }

    private func create() {
        let template = PlanDay(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            category: .general
        )
        context.insert(template)
        saveReporter.perform("Workout erstellen") { try context.save() }
        dismiss()
        onCreate(template)
    }
}
