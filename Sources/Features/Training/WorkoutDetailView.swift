import SwiftData
import SwiftUI

/// A saved workout's exercises and edit controls, separate from the quick start action.
struct WorkoutDetailView: View {
    @Environment(\.modelContext) private var context
    @Environment(SaveReporter.self) private var saveReporter

    let template: PlanDay
    let lastCompleted: Date?
    let onStart: () -> Void
    let onDelete: () -> Void

    @State private var showingDeleteConfirmation = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.regular) {
                SolidCard {
                    VStack(alignment: .leading, spacing: Theme.Spacing.regular) {
                        Text(template.name)
                            .font(.title2.weight(.bold))
                        if !template.focus.isEmpty {
                            Text(template.focus)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Text("\(template.sortedExercises.count) Übungen · \(template.totalSets) Sätze")
                            .font(.subheadline.weight(.medium))
                        Text(lastCompleted.map {
                            "Zuletzt trainiert: \($0.formatted(.dateTime.day().month(.abbreviated).year()))"
                        } ?? "Noch nicht trainiert")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Button(action: onStart) {
                            Label("Workout starten", systemImage: "play.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .accessibilityIdentifier("startWorkoutDetail")
                    }
                }

                Text("Übungen")
                    .font(.title2.weight(.bold))
                    .padding(.top, Theme.Spacing.tight)

                if template.sortedExercises.isEmpty {
                    SolidCard {
                        Text("Noch keine Übungen. Füge sie über Bearbeiten hinzu.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    ForEach(template.sortedExercises) { item in
                        SolidCard {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.exercise?.name ?? "Übung")
                                        .font(.headline)
                                    Text(item.restText + " Pause")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(item.setsAndRepsText)
                                    .font(.subheadline.weight(.semibold).monospacedDigit())
                            }
                        }
                    }
                }

                Button("Workout löschen", role: .destructive) {
                    showingDeleteConfirmation = true
                }
                .font(.subheadline)
                .padding(.top, Theme.Spacing.regular)
            }
            .padding(Theme.Spacing.regular)
        }
        .background(AppBackground())
        .navigationTitle(template.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                NavigationLink("Bearbeiten") {
                    PlanDayEditorView(day: template)
                }
                .accessibilityIdentifier("editWorkout")
            }
        }
        .confirmationDialog("Workout löschen?", isPresented: $showingDeleteConfirmation) {
            Button("Workout löschen", role: .destructive) {
                context.delete(template)
                saveReporter.perform("Workout löschen") { try context.save() }
                onDelete()
            }
        } message: {
            Text("Vergangene Trainingseinheiten bleiben erhalten.")
        }
    }
}
