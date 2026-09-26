import SwiftData
import SwiftUI

/// Saved workouts, recent sessions, and the current session live in one place.
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
    @State private var selectedTemplate: PlanDay?
    @State private var editingTemplate: PlanDay?
    @State private var pendingAction: WorkoutAction?

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
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingActions, onDismiss: performPendingAction) {
                WorkoutActionsSheet(hasTemplates: !templates.isEmpty) { action in
                    pendingAction = action
                    showingActions = false
                }
                .presentationDetents([.height(350)])
                .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showingPicker) { savedWorkoutPicker }
            .sheet(isPresented: $showingCreator) {
                CreateWorkoutView { created in editingTemplate = created }
            }
            .navigationDestination(item: $selectedTemplate) { template in
                WorkoutDetailView(template: template, lastCompleted: lastCompleted(for: template)) {
                    selectedTemplate = nil
                    start(template)
                } onDelete: {
                    selectedTemplate = nil
                }
            }
            .navigationDestination(item: $editingTemplate) { template in
                PlanDayEditorView(day: template)
            }
        }
    }

    private var libraryScreen: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.section) {
                header
                workoutSection
                HistoryCard(sessions: sessions)
            }
            .padding(.horizontal, Theme.Spacing.regular)
            .padding(.top, Theme.Spacing.loose)
            .padding(.bottom, 100)
        }
        .scrollEdgeEffectStyle(.soft, for: .top)
        .clearsBottomAccessory()
        .toolbar(.hidden, for: .navigationBar)
        .overlay(alignment: .bottomTrailing) {
            Button {
                showingActions = true
            } label: {
                Image(systemName: "plus")
                    .font(.title2.weight(.medium))
                    .frame(width: 62, height: 62)
            }
            .buttonStyle(.glass)
            .accessibilityLabel("Workout starten oder erstellen")
            .accessibilityIdentifier("workoutPlus")
            .padding(Theme.Spacing.loose)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("DEIN TRAINING")
                .font(.caption.weight(.bold))
                .tracking(1.8)
                .foregroundStyle(.tint)
            Text("Trainiere, wann du willst.")
                .font(.largeTitle.weight(.bold))
                .tracking(-0.8)
                .fixedSize(horizontal: false, vertical: true)
            Text("Wähle ein Workout oder starte frei.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.bottom, 2)
    }

    private var workoutSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.regular) {
            HStack(alignment: .firstTextBaseline) {
                Text("Workouts")
                    .font(.title2.weight(.bold))
                Spacer()
                Text("\(templates.count) gespeichert")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if templates.isEmpty {
                SolidCard {
                    VStack(alignment: .leading, spacing: Theme.Spacing.tight) {
                        Image(systemName: "dumbbell")
                            .font(.title2)
                            .foregroundStyle(.tint)
                        Text("Dein erstes Workout")
                            .font(.headline)
                        Text("Lege Übungen fest und starte es jederzeit wieder.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Button("Workout erstellen") { showingCreator = true }
                            .buttonStyle(.borderedProminent)
                            .padding(.top, 4)
                    }
                }
            } else {
                ForEach(templates) { template in
                    SolidCard {
                        HStack(alignment: .center, spacing: Theme.Spacing.regular) {
                            Button {
                                selectedTemplate = template
                            } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(template.name)
                                        .font(.headline)
                                        .foregroundStyle(.primary)
                                    Text("\(template.sortedExercises.count) Übungen · \(template.totalSets) Sätze")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text(lastCompletedText(for: template))
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("workoutDetail-\(template.name)")

                            Button {
                                start(template)
                            } label: {
                                Label("Start", systemImage: "play.fill")
                                    .font(.subheadline.weight(.semibold))
                            }
                            .buttonStyle(.borderedProminent)
                            .accessibilityLabel("\(template.name) starten")
                            .accessibilityIdentifier("start-\(template.name)")
                        }
                    }
                }
            }
        }
    }

    private var savedWorkoutPicker: some View {
        NavigationStack {
            List {
                ForEach(templates) { template in
                    Button {
                        showingPicker = false
                        start(template)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(template.name).font(.headline)
                                Text("\(template.sortedExercises.count) Übungen")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "play.fill")
                                .foregroundStyle(.tint)
                        }
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

    private func lastCompleted(for template: PlanDay) -> Date? {
        sessions.first { session in
            guard !session.isActive else { return false }
            if session.planDay?.id == template.id { return true }
            // Migrated weekly plans were copied into standalone workouts.
            return session.planDay?.plan != nil && session.dayName == template.name
        }?.endedAt
    }

    private func lastCompletedText(for template: PlanDay) -> String {
        guard let date = lastCompleted(for: template) else { return "Noch nicht trainiert" }
        return "Zuletzt: \(date.formatted(.dateTime.day().month(.abbreviated).year()))"
    }

    private func performPendingAction() {
        guard let action = pendingAction else { return }
        pendingAction = nil
        switch action {
        case .saved: showingPicker = true
        case .create: showingCreator = true
        case .free: startFreeWorkout()
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

private enum WorkoutAction {
    case saved, create, free
}

private struct WorkoutActionsSheet: View {
    let hasTemplates: Bool
    let select: (WorkoutAction) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.regular) {
            Text("Training starten")
                .font(.title2.weight(.bold))
                .padding(.top, Theme.Spacing.regular)
            action("Gespeichertes Workout starten", subtitle: "Aus deinen Workouts wählen", icon: "dumbbell", enabled: hasTemplates) {
                select(.saved)
            }
            action("Neues Workout erstellen", subtitle: "Übungen für später speichern", icon: "plus.square") {
                select(.create)
            }
            action("Freies Training starten", subtitle: "Ohne Vorlage loslegen", icon: "bolt.fill") {
                select(.free)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Theme.Spacing.loose)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppBackground())
    }

    private func action(
        _ title: String,
        subtitle: String,
        icon: String,
        enabled: Bool = true,
        perform: @escaping () -> Void
    ) -> some View {
        Button(action: perform) {
            HStack(spacing: Theme.Spacing.regular) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(.tint)
                    .frame(width: 44, height: 44)
                    .background(Color.accentColor.opacity(0.12), in: .rect(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(Theme.Spacing.tight)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemBackground), in: .rect(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.5)
    }
}
