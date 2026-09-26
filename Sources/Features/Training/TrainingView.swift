import SwiftData
import SwiftUI

/// Start a saved workout on any day, or continue the current session.
struct TrainingView: View {
    @Environment(\.modelContext) private var context
    @Environment(SaveReporter.self) private var saveReporter
    @Environment(RestTimer.self) private var restTimer
    @Query private var allDays: [PlanDay]
    @Query(sort: \WorkoutSession.startedAt, order: .reverse)
    private var sessions: [WorkoutSession]

    @State private var showingActions = false
    @State private var showingPicker = false
    @State private var showingCreator = false
    @State private var editingTemplate: PlanDay?

    private var templates: [PlanDay] { WorkoutLibrary.templates(in: allDays) }
    private var activeSession: WorkoutSession? { sessions.first(where: \.isActive) }

    var body: some View {
        NavigationStack {
            Group {
                if let activeSession {
                    SessionView(session: activeSession)
                } else {
                    libraryScreen
                }
            }
            .background(AppBackground())
            .navigationTitle(activeSession?.dayName ?? "Training")
            .confirmationDialog("Training", isPresented: $showingActions) {
                Button("Workout starten") { showingPicker = true }
                Button("Neues Workout erstellen") { showingCreator = true }
                Button("Freies Training starten") { startFreeWorkout() }
            }
            .sheet(isPresented: $showingPicker) {
                NavigationStack {
                    List {
                        ForEach(templates) { template in
                            Button {
                                showingPicker = false
                                start(template)
                            } label: {
                                Label(template.name, systemImage: "play.fill")
                            }
                        }
                    }
                    .navigationTitle("Workout starten")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Abbrechen") { showingPicker = false }
                        }
                    }
                }
            }
            .sheet(isPresented: $showingCreator) {
                CreateWorkoutView { created in editingTemplate = created }
            }
            .navigationDestination(item: $editingTemplate) { template in
                PlanDayEditorView(day: template)
            }
        }
    }

    private var libraryScreen: some View {
        ScrollView {
            GlassEffectContainer(spacing: Theme.Spacing.regular) {
                VStack(spacing: Theme.Spacing.regular) {
                    if templates.isEmpty {
                        GlassCard {
                            VStack(alignment: .leading, spacing: Theme.Spacing.tight) {
                                SectionHeader(title: "Deine Workouts", subtitle: "Trainiere ohne Wochenplan")
                                Text("Erstelle ein Workout oder starte ein freies Training.")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } else {
                        GlassCard {
                            VStack(alignment: .leading, spacing: Theme.Spacing.regular) {
                                SectionHeader(title: "Deine Workouts", subtitle: "Jederzeit starten")
                                ForEach(templates) { template in
                                    HStack(spacing: Theme.Spacing.tight) {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(template.name).font(.headline)
                                            Text("\(template.sortedExercises.count) Übungen · \(template.totalSets) Sätze")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        Spacer(minLength: Theme.Spacing.tight)
                                        Button {
                                            start(template)
                                        } label: {
                                            Image(systemName: "play.fill")
                                        }
                                        .buttonStyle(.glassProminent)
                                        .accessibilityLabel("\(template.name) starten")
                                        .accessibilityIdentifier("start-\(template.name)")
                                    }
                                    .padding(.vertical, 4)
                                }
                            }
                        }
                    }
                    HistoryCard(sessions: sessions)
                }
                .padding(Theme.Spacing.regular)
            }
        }
        .scrollEdgeEffectStyle(.soft, for: .top)
        .clearsBottomAccessory()
        .overlay(alignment: .bottomTrailing) {
            Button {
                showingActions = true
            } label: {
                Image(systemName: "plus")
                    .font(.title2.weight(.medium))
                    .frame(width: 60, height: 60)
            }
            .buttonStyle(.glass)
            .accessibilityLabel("Workout starten oder erstellen")
            .accessibilityIdentifier("workoutPlus")
            .padding(Theme.Spacing.regular)
        }
    }

    private func start(_ template: PlanDay) {
        context.insert(WorkoutLibrary.makeSession(from: template))
        restTimer.prepareNotifications()
        saveReporter.perform("Training starten") { try context.save() }
    }

    private func startFreeWorkout() {
        context.insert(WorkoutSession(dayName: "Freies Training", category: .general))
        restTimer.prepareNotifications()
        saveReporter.perform("Training starten") { try context.save() }
    }
}
