import SwiftData
import SwiftUI

/// Manage standalone workout templates without assigning them to weekdays.
struct PlanView: View {
    @Environment(\.modelContext) private var context
    @Environment(SaveReporter.self) private var saveReporter
    @Query private var allDays: [PlanDay]
    @State private var creating = false
    @State private var editingTemplate: PlanDay?

    private var templates: [PlanDay] { WorkoutLibrary.templates(in: allDays) }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(templates) { template in
                        NavigationLink {
                            PlanDayEditorView(day: template)
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(template.name).font(.headline)
                                Text("\(template.sortedExercises.count) Übungen · \(template.totalSets) Sätze")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .accessibilityIdentifier("editWorkout-\(template.name)")
                    }
                    .onDelete(perform: delete)
                } header: {
                    Text("Deine Workouts")
                } footer: {
                    Text("Workouts haben keinen festen Wochentag. Starte sie jederzeit unter Training.")
                }
            }
            .glassFormBackground()
            .navigationTitle("Workouts")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Workout erstellen", systemImage: "plus") { creating = true }
                        .accessibilityIdentifier("createWorkout")
                }
            }
            .sheet(isPresented: $creating) {
                CreateWorkoutView { editingTemplate = $0 }
            }
            .navigationDestination(item: $editingTemplate) { template in
                PlanDayEditorView(day: template)
            }
        }
    }

    private func delete(_ offsets: IndexSet) {
        for index in offsets { context.delete(templates[index]) }
        saveReporter.perform("Workout löschen") { try context.save() }
    }
}

struct DayCard: View {
    @ScaledMetric(relativeTo: .caption) private var labelWidth: CGFloat = 24

    let day: PlanDay
    var isEditable = false

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: Theme.Spacing.regular) {
                header
                if day.category.isTrainingDay {
                    VStack(spacing: 0) {
                        ForEach(Array(day.sortedExercises.enumerated()), id: \.element.id) { index, item in
                            if index > 0 {
                                Divider().opacity(0.3)
                            }
                            ExerciseRow(item: item)
                                .padding(.vertical, 9)
                        }
                    }
                    if !day.tip.isEmpty {
                        Label(day.tip, systemImage: "lightbulb")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    if !day.tip.isEmpty {
                        Text(day.tip)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    // A rest day is otherwise a dead end: nothing on the card
                    // suggests it can become a training day.
                    Label("Antippen, um daraus einen Trainingstag zu machen",
                          systemImage: "plus.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.regular) {
            Text(day.shortLabel)
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
                .frame(minWidth: labelWidth, alignment: .leading)
            VStack(alignment: .leading, spacing: 1) {
                Text(day.name)
                    .font(.headline)
                if !day.focus.isEmpty {
                    Text(day.focus)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: Theme.Spacing.tight)
            GlassBadge(text: day.category.badge, tint: day.category.color)
            if isEditable {
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

private struct ExerciseRow: View {
    let item: PlanExercise

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.regular) {
            VStack(alignment: .leading, spacing: 3) {
                Text(item.exercise?.name ?? "—")
                    .font(.subheadline.weight(.medium))
                HStack(spacing: 5) {
                    if !item.note.isEmpty {
                        Text(item.note)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                HStack(spacing: 5) {
                    Text(item.restText)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(.quaternary, in: .capsule)
                    if let rir = item.rirText {
                        Text(rir)
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(
                                (item.rirLower == 0 ? Color.red : Color.orange).opacity(0.22),
                                in: .capsule
                            )
                    }
                    if let muscle = item.exercise?.primary {
                        Text(muscle.displayName)
                            .font(.caption2)
                            .foregroundStyle(muscle.category.color)
                    }
                }
            }
            Spacer(minLength: Theme.Spacing.tight)
            Text(item.setsAndRepsText)
                .font(.caption.weight(.bold).monospacedDigit())
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .glassEffect(
                    Glass.regular.tint((item.exercise?.primary.category.color ?? .secondary).opacity(0.22)),
                    in: .capsule
                )
                .fixedSize()
        }
        .accessibilityElement(children: .combine)
    }
}
