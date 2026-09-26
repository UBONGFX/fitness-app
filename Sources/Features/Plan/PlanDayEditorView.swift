import SwiftData
import SwiftUI

/// Editing one training day: which exercises, in which order, with what sets.
///
/// A plain `List` rather than the glass cards of the read-only view. Swipe to
/// delete and drag to reorder only work in a `List`, and an editing screen is
/// where people expect standard iOS behaviour anyway.
struct PlanDayEditorView: View {
    @Environment(\.modelContext) private var context
    @Environment(SaveReporter.self) private var saveReporter
    @Query(sort: \Exercise.name) private var allExercises: [Exercise]

    let day: PlanDay

    @State private var editingItem: PlanExercise?
    @State private var showingPicker = false

    var body: some View {
        List {
            Section {
                TextField("Name", text: Binding(
                    get: { day.name },
                    set: { day.name = $0; save() }
                ))
                .accessibilityIdentifier("dayName")
                .glassRow(.first)

                Picker("Art", selection: Binding(
                    get: { day.category },
                    set: { day.category = $0; save() }
                )) {
                    ForEach(day.plan == nil
                            ? TrainingCategory.allCases.filter(\.isTrainingDay)
                            : TrainingCategory.allCases) { category in
                        Text(category.displayName).tag(category)
                    }
                }
                .accessibilityIdentifier("dayCategory")
                .glassRow(.middle)

                if day.category.isTrainingDay {
                    TextField("Fokus, z. B. Brust · Schulter · Trizeps", text: Binding(
                        get: { day.focus },
                        set: { day.focus = $0; save() }
                    ))
                    .accessibilityIdentifier("dayFocus")
                    .glassRow(.middle)
                }

                TextField(
                    day.plan == nil ? "Notiz zum Workout" : (day.category.isTrainingDay ? "Tipp für diesen Tag" : "Hinweis"),
                    text: Binding(get: { day.tip }, set: { day.tip = $0; save() }),
                    axis: .vertical
                )
                .accessibilityIdentifier("dayTip")
                .glassRow(.last)
            } header: {
                Text(day.plan == nil ? "Workout" : "Tag")
            } footer: {
                if !day.category.isTrainingDay && !day.sortedExercises.isEmpty {
                    // The exercises are kept, not deleted — switching back must
                    // not have cost the day's content.
                    Text("\(day.sortedExercises.count) Übungen bleiben gespeichert, "
                         + "zählen aber nicht ins Wochenvolumen.")
                } else if day.plan != nil && day.category.isTrainingDay {
                    Text("Aus einem Ruhetag wird ein Trainingstag, sobald du hier die Art umstellst.")
                }
            }

            Section {
                ForEach(Array(day.sortedExercises.enumerated()), id: \.element.id) { index, item in
                    Button {
                        editingItem = item
                    } label: {
                        row(item)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("editItem-\(item.exercise?.name ?? "?")")
                    .glassRow(.of(index, count: day.sortedExercises.count))
                }
                .onDelete { offsets in
                    PlanEditing.remove(atOffsets: offsets, from: day, context: context)
                    save()
                }
                .onMove { source, destination in
                    PlanEditing.move(in: day, fromOffsets: source, toOffset: destination)
                    save()
                }
            } header: {
                Text("\(day.sortedExercises.count) Übungen · \(day.totalSets) Sätze")
            } footer: {
                Text("Zum Bearbeiten antippen, zum Löschen wischen, zum Umsortieren ziehen.")
            }

            Section {
                // The identifier goes on the button itself, before the row
                // background: behind `glassRow` it lands on the wrapper and the
                // button becomes unfindable.
                Button("Übung hinzufügen", systemImage: "plus") {
                    showingPicker = true
                }
                .accessibilityIdentifier("addExercise")
            }
            .glassRow()
        }
        .glassFormBackground()
        .navigationTitle(day.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { EditButton() }
        .sheet(item: $editingItem) { item in
            PlanExerciseEditorView(item: item)
        }
        .sheet(isPresented: $showingPicker) {
            ExercisePickerView(day: day, allExercises: allExercises)
        }
    }

    private func row(_ item: PlanExercise) -> some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.exercise?.name ?? "—")
                    .font(.subheadline.weight(.medium))
                HStack(spacing: 6) {
                    Text(item.restText)
                    if let rir = item.rirText { Text(rir) }
                    if let muscle = item.exercise?.primary {
                        Text(muscle.displayName)
                    }
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
            Spacer(minLength: Theme.Spacing.tight)
            Text(item.setsAndRepsText)
                .font(.caption.weight(.bold).monospacedDigit())
        }
        .contentShape(Rectangle())
    }

    private func save() {
        saveReporter.perform("Plan ändern") { try context.save() }
    }
}

/// Sets, reps, rest and RIR for one prescribed exercise.
struct PlanExerciseEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(SaveReporter.self) private var saveReporter

    @Bindable var item: PlanExercise

    /// RIR is optional in the plan — most exercises carry no target at all.
    @State private var hasRIR = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Sätze und Wiederholungen") {
                    Stepper(value: $item.sets, in: 1...12) {
                        LabeledContent("Sätze", value: "\(item.sets)")
                    }
                    .accessibilityIdentifier("planSets")
                    .glassRow(.first)
                    Stepper(value: $item.repsLower, in: 1...50) {
                        LabeledContent("Wdh. von", value: "\(item.repsLower)")
                    }
                    .accessibilityIdentifier("planRepsLower")
                    .glassRow(.middle)
                    Stepper(value: $item.repsUpper, in: item.repsLower...50) {
                        LabeledContent("Wdh. bis", value: "\(item.repsUpper)")
                    }
                    .accessibilityIdentifier("planRepsUpper")
                    .glassRow(.last)
                }

                Section("Pause") {
                    Picker("Pause", selection: $item.restLowerSeconds) {
                        ForEach(RestTimer.presets, id: \.self) { seconds in
                            Text(RestFormat.label(seconds)).tag(seconds)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("planRest")
                    .glassRow()
                }

                Section {
                    Toggle("Vorgabe setzen", isOn: $hasRIR)
                        .accessibilityIdentifier("planHasRIR")
                        .glassRow(hasRIR ? .first : .only)
                    if hasRIR {
                        Stepper(value: Binding(
                            get: { item.rirLower ?? 2 },
                            set: { item.rirLower = $0; item.rirUpper = max($0, item.rirUpper ?? $0) }
                        ), in: 0...5) {
                            LabeledContent("RIR von", value: "\(item.rirLower ?? 2)")
                        }
                        .glassRow(.middle)
                        Stepper(value: Binding(
                            get: { item.rirUpper ?? item.rirLower ?? 2 },
                            set: { item.rirUpper = max($0, item.rirLower ?? 0) }
                        ), in: 0...5) {
                            LabeledContent("RIR bis", value: "\(item.rirUpper ?? 2)")
                        }
                        .glassRow(.last)
                    }
                } header: {
                    Text("RIR — Reps in Reserve")
                } footer: {
                    Text("Wie viele Wiederholungen am Ende eines Satzes noch übrig sein sollen. "
                         + "0 heißt Training bis zum Muskelversagen.")
                }

                if let exercise = item.exercise {
                    Section {
                        Toggle("Eigener Schritt", isOn: Binding(
                            get: { exercise.usesCustomStep },
                            set: { exercise.stepOverrideKg = $0 ? exercise.derivedProgressionStepKg : nil }
                        ))
                        .accessibilityIdentifier("planCustomStep")
                        .glassRow(exercise.usesCustomStep ? .first : .only)

                        if exercise.usesCustomStep {
                            DecimalField(
                                label: "Schritt",
                                unit: "kg",
                                identifier: "planStep",
                                maximum: 20,
                                value: Binding(
                                    get: { exercise.stepOverrideKg },
                                    set: { exercise.stepOverrideKg = $0 }
                                )
                            )
                            .glassRow(.last)
                        }
                    } header: {
                        Text("Steigerung")
                    } footer: {
                        // The rule is stated in the user's own document, so the
                        // derived value is named rather than silently replaced.
                        Text(exercise.usesCustomStep
                             ? "Statt der Regel (\(Progression.format(exercise.derivedProgressionStepKg)) kg)."
                             : "Nach der Regel: \(Progression.format(exercise.derivedProgressionStepKg)) kg pro Woche. "
                               + "Gilt für diese Übung überall, nicht nur an diesem Tag.")
                    }
                }

                Section("Notiz") {
                    TextField("z. B. Obere Brust — Priorität", text: $item.note, axis: .vertical)
                        .accessibilityIdentifier("planNote")
                        .glassRow()
                }
            }
            .glassFormBackground()
            .navigationTitle(item.exercise?.name ?? "Übung")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { save() }
                        .accessibilityIdentifier("planItemDone")
                }
            }
            .onAppear { hasRIR = item.rirLower != nil }
            .onChange(of: hasRIR) { _, enabled in
                if !enabled {
                    item.rirLower = nil
                    item.rirUpper = nil
                } else if item.rirLower == nil {
                    item.rirLower = 2
                    item.rirUpper = 3
                }
            }
        }
    }

    private func save() {
        // The upper bound can end up below the lower one while stepping; fix it
        // rather than storing a range that reads backwards.
        if item.repsUpper < item.repsLower { item.repsUpper = item.repsLower }
        item.restUpperSeconds = max(item.restUpperSeconds, item.restLowerSeconds)
        saveReporter.perform("Übung ändern") { try context.save() }
        dismiss()
    }
}

/// Name and focus of the plan itself.
///
/// Without this a plan keeps its original name even after the week has
/// been rebuilt into something else entirely.
struct PlanHeaderEditorView: View {
    @Environment(\.modelContext) private var context
    @Environment(SaveReporter.self) private var saveReporter

    @Bindable var plan: WorkoutPlan

    var body: some View {
        List {
            Section {
                TextField("Name, z. B. Ganzkörper", text: $plan.name)
                    .accessibilityIdentifier("planName")
                    .glassRow(.first)
                TextField("Fokus", text: $plan.focus, axis: .vertical)
                    .accessibilityIdentifier("planFocus")
                    .glassRow(.last)
            } footer: {
                Text(plan.summaryText)
            }
        }
        .glassFormBackground()
        .navigationTitle("Plan")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear {
            saveReporter.perform("Plan sichern") { try context.save() }
        }
    }
}
