import Charts
import SwiftData
import SwiftUI

/// Saved workouts, recent sessions, and the current session live in one place.
struct TrainingView: View {
    @Environment(\.modelContext) private var context
    @Environment(SaveReporter.self) private var saveReporter
    @Environment(RestTimer.self) private var restTimer
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Query private var allDays: [PlanDay]
    @Query(sort: \WorkoutSession.startedAt, order: .reverse)
    private var sessions: [WorkoutSession]

    @Binding var showingActions: Bool
    @State private var showingPicker = false
    @State private var showingCreator = false
    @State private var selectedTemplate: PlanDay?
    @State private var editingTemplate: PlanDay?
    @State private var pendingAction: WorkoutAction?

    private var templates: [PlanDay] { WorkoutLibrary.templates(in: allDays) }
    private var activeSession: WorkoutSession? { sessions.first(where: \.isActive) }
    private var thisWeek: [WorkoutSession] {
        ActualVolume.sessions(in: ActualVolume.week(containing: Date()), from: sessions)
    }
    private var muscleVolume: [VolumeRow] { ActualVolume.rows(from: thisWeek) }
    private var loggedExercises: [Exercise] {
        var seen = Set<UUID>()
        return SessionHistory.finished(sessions)
            .flatMap(\.sortedExercises)
            .compactMap { entry in
                guard !entry.sortedSets.isEmpty, let exercise = entry.exercise,
                      seen.insert(exercise.id).inserted
                else { return nil }
                return exercise
            }
    }
    private var weeklyLoads: [WeeklyLoad] {
        let start = ActualVolume.week(containing: Date()).start
        return (0..<6).reversed().compactMap { offset in
            guard let weekStart = Calendar.current.date(byAdding: .weekOfYear, value: -offset, to: start),
                  let weekEnd = Calendar.current.date(byAdding: .day, value: 7, to: weekStart)
            else { return nil }
            let logged = ActualVolume.sessions(
                in: DateInterval(start: weekStart, end: weekEnd), from: sessions
            )
            return WeeklyLoad(date: weekStart, load: logged.reduce(0) { $0 + $1.totalLoad })
        }
    }

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
            .navigationTitle(activeSession?.dayName ?? "")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if activeSession == nil && !loggedExercises.isEmpty {
                    ToolbarItem(placement: .primaryAction) {
                        NavigationLink {
                            ExerciseHistoryIndexView(exercises: loggedExercises, sessions: sessions)
                        } label: {
                            Image(systemName: "chart.xyaxis.line")
                        }
                        .accessibilityLabel("Übungsfortschritt")
                        .accessibilityIdentifier("openExerciseProgress")
                    }
                }
            }
            .sheet(isPresented: $showingActions, onDismiss: performPendingAction) {
                WorkoutActionsSheet(hasTemplates: !templates.isEmpty) { action in
                    pendingAction = action
                    showingActions = false
                }
                .presentationDetents(dynamicTypeSize.isAccessibilitySize ? [.large] : [.height(350)])
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
                FieldGuidePageTitle(title: "Training")
                volumeSection
                workoutSection
                if !loggedExercises.isEmpty { exerciseHistorySection }
                HistoryCard(sessions: sessions)
            }
            .padding(.horizontal, Theme.Spacing.regular)
            .padding(.top, Theme.Spacing.loose)
            .padding(.bottom, 100)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
        }
        .scrollEdgeEffectStyle(.soft, for: .top)
        .clearsBottomAccessory()
    }

    private var volumeSection: some View {
        SolidCard {
            VStack(alignment: .leading, spacing: Theme.Spacing.regular) {
                HStack {
                    Text("Diese Woche")
                        .font(.system(.title2, design: .serif).weight(.semibold))
                    Spacer()
                    Text("TRAININGSUMFANG")
                        .font(.caption2.weight(.semibold))
                        .tracking(1.1)
                        .foregroundStyle(.secondary)
                }

                HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.section) {
                    volumeStat("Einheiten", "\(thisWeek.count)")
                    volumeStat("Sätze", "\(thisWeek.reduce(0) { $0 + $1.completedSets })")
                    volumeStat("Last", "\(Int(thisWeek.reduce(0) { $0 + $1.totalLoad })) kg")
                }

                if muscleVolume.isEmpty {
                    Text("Nach dem ersten Satz siehst du hier deine Muskelgruppen.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    Divider()
                    ForEach(muscleVolume.prefix(3)) { row in
                        HStack {
                            Text(row.muscle.displayName)
                            Spacer()
                            Text("\(row.totalText) Sätze")
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                        .font(.footnote)
                    }
                    Text("Direkte Sätze + halbe Beteiligung weiterer Muskelgruppen")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                if weeklyLoads.contains(where: { $0.load > 0 }) {
                    Divider()
                    Text("Last · letzte 6 Wochen")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Chart(weeklyLoads) { week in
                        BarMark(
                            x: .value("Woche", week.date, unit: .weekOfYear),
                            y: .value("Last", week.load)
                        )
                        .foregroundStyle(Color.accentColor)
                    }
                    .chartYAxis(.hidden)
                    .frame(height: 92)
                    .accessibilityLabel("Trainingslast der letzten sechs Wochen")
                    .accessibilityValue(weeklyLoads.map {
                        "\($0.date.formatted(.dateTime.day().month(.abbreviated))): \(Int($0.load)) Kilogramm"
                    }.joined(separator: ", "))
                }
            }
        }
    }

    private func volumeStat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value)
                .font(.title3.weight(.semibold).monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var workoutSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.regular) {
            HStack(alignment: .firstTextBaseline) {
                Text("Workouts")
                    .font(.system(.title2, design: .serif).weight(.semibold))
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
                    workoutCard(template)
                }
            }
        }
    }

    private func workoutCard(_ template: PlanDay) -> some View {
        SolidCard {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: Theme.Spacing.regular) {
                    workoutDetailButton(template)
                    workoutStartButton(template)
                }
            } else {
                HStack(alignment: .center, spacing: Theme.Spacing.regular) {
                    workoutDetailButton(template)
                    workoutStartButton(template)
                }
            }
        }
    }

    private func workoutDetailButton(_ template: PlanDay) -> some View {
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
    }

    private func workoutStartButton(_ template: PlanDay) -> some View {
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

    private var exerciseHistorySection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.regular) {
            HStack(alignment: .firstTextBaseline) {
                Text("Übungsfortschritt")
                    .font(.system(.title2, design: .serif).weight(.semibold))
                Spacer()
                NavigationLink("Alle") {
                    ExerciseHistoryIndexView(exercises: loggedExercises, sessions: sessions)
                }
                .font(.caption)
                .accessibilityIdentifier("allExerciseProgress")
            }
            ForEach(loggedExercises.prefix(3)) { exercise in
                ExerciseHistoryLink(exercise: exercise, sessions: sessions)
            }
        }
    }

    private var savedWorkoutPicker: some View {
        NavigationStack {
            List {
                ForEach(Array(templates.enumerated()), id: \.element.id) { index, template in
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
                    .glassRow(.of(index, count: templates.count))
                }
            }
            .glassFormBackground()
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

private struct ExerciseHistoryIndexView: View {
    let exercises: [Exercise]
    let sessions: [WorkoutSession]
    @State private var search = ""

    private var filtered: [Exercise] {
        search.isEmpty ? exercises : exercises.filter {
            $0.name.localizedCaseInsensitiveContains(search)
        }
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: Theme.Spacing.regular) {
                ForEach(filtered) { exercise in
                    ExerciseHistoryLink(exercise: exercise, sessions: sessions)
                }
            }
            .padding(Theme.Spacing.regular)
        }
        .searchable(text: $search, prompt: "Geloggte Übung suchen")
        .background(AppBackground())
        .navigationTitle("Übungsfortschritt")
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if filtered.isEmpty {
                ContentUnavailableView.search(text: search)
            }
        }
    }
}

private struct ExerciseHistoryLink: View {
    let exercise: Exercise
    let sessions: [WorkoutSession]

    private var entries: [ExerciseHistoryEntry] {
        SessionHistory.entries(for: exercise.id, in: sessions)
    }

    var body: some View {
        NavigationLink {
            ExerciseProgressView(
                exerciseName: exercise.name,
                exerciseID: exercise.id,
                sessions: sessions
            )
        } label: {
            SolidCard {
                HStack(spacing: Theme.Spacing.regular) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(exercise.name)
                            .font(.headline)
                            .foregroundStyle(.primary)
                            .lineLimit(2)
                        Text("\(entries.count) \(entries.count == 1 ? "Einheit" : "Einheiten") · zuletzt \(entries.first?.date.formatted(.dateTime.day().month(.abbreviated)) ?? "—")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: Theme.Spacing.tight)
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(entries.first?.setsAtWorkingWeight.first?.summary ?? "—")
                            .font(.subheadline.weight(.semibold).monospacedDigit())
                            .foregroundStyle(.tint)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        if let change = SessionHistory.weightTrend(entries) {
                            Text("\(ExerciseProgress.signed(change)) seit Start")
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .contentShape(Rectangle())
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("exerciseProgress-\(exercise.name)")
    }
}

private struct WeeklyLoad: Identifiable {
    let date: Date
    let load: Double
    var id: Date { date }
}

private enum WorkoutAction {
    case saved, create, free
}

private struct WorkoutActionsSheet: View {
    @Environment(\.colorScheme) private var scheme
    let hasTemplates: Bool
    let select: (WorkoutAction) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.regular) {
            Text("Training")
                .font(.system(.title2, design: .serif).weight(.semibold))
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
                    .frame(width: 34, height: 44)
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
            .padding(.vertical, Theme.Spacing.tight)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(alignment: .top) {
                Theme.Palette.rule(scheme).frame(height: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.5)
    }
}
