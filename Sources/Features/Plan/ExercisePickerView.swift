import SwiftData
import SwiftUI

/// Choosing an exercise to add to a day, or creating a new one.
struct ExercisePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(SaveReporter.self) private var saveReporter

    let day: PlanDay
    let allExercises: [Exercise]

    @State private var search = ""
    @State private var showingNew = false

    private var available: [Exercise] {
        let candidates = PlanEditing.available(allExercises, for: day)
        guard !search.isEmpty else { return candidates }
        return candidates.filter { $0.name.localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button("Neue Übung anlegen", systemImage: "plus.circle") {
                        showingNew = true
                    }
                    .accessibilityIdentifier("newExercise")
                    .glassRow()
                }

                Section {
                    ForEach(Array(available.enumerated()), id: \.element.id) { index, exercise in
                        Button {
                            add(exercise)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(exercise.name)
                                        .font(.subheadline)
                                    Text(muscleSummary(exercise))
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("pick-\(exercise.name)")
                        .glassRow(.of(index, count: available.count))
                    }
                } header: {
                    Text("Vorhandene Übungen")
                } footer: {
                    if available.isEmpty {
                        Text(search.isEmpty
                             ? "Alle Übungen stehen schon an diesem Tag."
                             : "Keine Übung gefunden.")
                    }
                }
            }
            .glassFormBackground()
            .searchable(text: $search, prompt: "Übung suchen")
            .navigationTitle("Übung hinzufügen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
            }
            .sheet(isPresented: $showingNew) {
                NewExerciseView(existing: allExercises) { created in
                    add(created)
                }
            }
        }
    }

    private func muscleSummary(_ exercise: Exercise) -> String {
        var parts = [exercise.primary.displayName]
        if !exercise.secondary.isEmpty {
            parts.append("+ " + exercise.secondary.map(\.displayName).joined(separator: ", "))
        }
        return parts.joined(separator: " ")
    }

    private func add(_ exercise: Exercise) {
        PlanEditing.add(exercise, to: day, context: context)
        saveReporter.perform("Übung hinzufügen") { try context.save() }
        dismiss()
    }
}

/// Creating an exercise the plan does not have yet.
///
/// The muscle assignment is mandatory, not optional: it is what the weekly
/// volume analysis counts. An exercise without it would silently vanish from
/// the one chart it should appear in.
struct NewExerciseView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(SaveReporter.self) private var saveReporter

    let existing: [Exercise]
    var onCreate: (Exercise) -> Void

    @State private var name = ""
    @State private var primary: MuscleGroup = .chest
    @State private var secondary: Set<MuscleGroup> = []
    @State private var kind: ExerciseKind = .isolation

    private var problem: String? {
        PlanEditing.nameProblem(name, existing: existing)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("z. B. Face Pull", text: $name)
                        .accessibilityIdentifier("newExerciseName")
                        .glassRow(problem != nil && !name.isEmpty ? .first : .only)
                    if let problem, !name.isEmpty {
                        Text(problem)
                            .font(.caption)
                            .foregroundStyle(.orange)
                            .accessibilityIdentifier("newExerciseProblem")
                            .glassRow(.last)
                    }
                }

                Section {
                    Picker("Primär", selection: $primary) {
                        ForEach(MuscleGroup.allCases) { muscle in
                            Text(muscle.displayName).tag(muscle)
                        }
                    }
                    .accessibilityIdentifier("newExercisePrimary")
                    .glassRow()
                } header: {
                    Text("Hauptmuskel")
                } footer: {
                    Text("Zählt im Wochenvolumen als voller Satz.")
                }

                Section {
                    let others = MuscleGroup.allCases.filter { $0 != primary }
                    ForEach(Array(others.enumerated()), id: \.element.id) { index, muscle in
                        Button {
                            if secondary.contains(muscle) {
                                secondary.remove(muscle)
                            } else {
                                secondary.insert(muscle)
                            }
                        } label: {
                            HStack {
                                Text(muscle.displayName)
                                Spacer()
                                if secondary.contains(muscle) {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.tint)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("secondary-\(muscle.rawValue)")
                        .glassRow(.of(index, count: others.count))
                    }
                } header: {
                    Text("Mitbelastet")
                } footer: {
                    Text("Zählt je halbem Satz — genau wie im Rest des Plans.")
                }

                Section {
                    Picker("Art", selection: $kind) {
                        Text("Grundübung").tag(ExerciseKind.compound)
                        Text("Isolation").tag(ExerciseKind.isolation)
                    }
                    .pickerStyle(.segmented)
                    .glassRow()
                } header: {
                    Text("Art")
                } footer: {
                    Text("Bestimmt den Steigerungsschritt: Grundübung +2,5 kg, "
                         + "Isolation +1 kg, Beinübungen +5 kg.")
                }
            }
            .glassFormBackground()
            .navigationTitle("Neue Übung")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Anlegen") { create() }
                        .disabled(problem != nil)
                        .accessibilityIdentifier("createExercise")
                }
            }
        }
    }

    private func create() {
        guard problem == nil else { return }
        let exercise = Exercise(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            primary: primary,
            secondary: Array(secondary).sorted { $0.rawValue < $1.rawValue },
            kind: kind
        )
        context.insert(exercise)
        saveReporter.perform("Übung anlegen") { try context.save() }
        dismiss()
        onCreate(exercise)
    }
}
