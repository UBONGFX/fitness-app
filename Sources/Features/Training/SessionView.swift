import SwiftData
import SwiftUI

/// One session — running, or a past one being corrected.
///
/// The same screen serves both, because the thing being edited is the same: the
/// sets of a session. Only two things differ, and both follow from the session
/// itself rather than from a flag the caller could get wrong: a finished session
/// has nothing to end, and a set entered afterwards must not start a rest timer.
struct SessionView: View {
    @Environment(\.modelContext) private var context
    @Environment(SaveReporter.self) private var saveReporter
    @Query(sort: \WorkoutSession.startedAt, order: .reverse)
    private var allSessions: [WorkoutSession]
    @Bindable var session: WorkoutSession

    @State private var editing: SetEditorTarget?
    @State private var showingExercisePicker = false
    @State private var showingFinishConfirmation = false

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.regular) {
                summaryCard

                ForEach(session.sortedExercises) { entry in
                    LoggedExerciseCard(
                        entry: entry,
                        suggestion: suggestion(for: entry),
                        onAddSet: { editing = .newSet(entry) },
                        onEditSet: { editing = .existingSet($0, entry) },
                        onDeleteSet: { delete($0, from: entry) }
                    )
                }

                if session.isActive {
                    Button("Übung hinzufügen", systemImage: "plus") {
                        showingExercisePicker = true
                    }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier("addSessionExercise")
                }
            }
            .padding(Theme.Spacing.regular)
        }
        .scrollEdgeEffectStyle(.soft, for: .top)
        .clearsBottomAccessory()
        .toolbar {
            if session.isActive {
                ToolbarItem(placement: .primaryAction) {
                    Button("Beenden") { showingFinishConfirmation = true }
                        .accessibilityIdentifier("finishSession")
                }
            }
        }
        .sheet(item: $editing) { target in
            SetEditorView(
                entry: target.entry,
                existing: target.set,
                session: session,
                suggestion: suggestion(for: target.entry)
            )
            .presentationDetents([.medium])
        }
        .sheet(isPresented: $showingExercisePicker) {
            SessionExercisePickerView(session: session)
        }
        .confirmationDialog(
            "Training beenden?",
            isPresented: $showingFinishConfirmation,
            titleVisibility: .visible
        ) {
            Button("Training beenden", role: .destructive) { finish() }
            Button("Weiter trainieren", role: .cancel) {}
        } message: {
            Text("\(session.completedSets) Sätze in \(session.durationText).")
        }
    }

    private var summaryCard: some View {
        SolidCard {
            VStack(alignment: .leading, spacing: Theme.Spacing.tight) {
                if !session.isActive {
                    // A past session is being corrected, not performed. Saying so
                    // keeps a retroactive entry from reading like a live one.
                    Text(session.startedAt, format: .dateTime.weekday(.wide).day().month(.wide))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("sessionDate")
                }
                HStack(spacing: Theme.Spacing.tight) {
                    stat("Sätze", "\(session.completedSets)")
                    stat("Dauer", session.durationText)
                    stat("Last", "\(Int(session.totalLoad)) kg")
                }
            }
        }
    }

    /// One of three equal columns across the full width.
    ///
    /// Left-aligned in a row they huddled on the left with a third of the card
    /// empty next to them; spreading them evenly is what makes the card read as
    /// a summary rather than a truncated list.
    private func stat(_ label: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.weight(.semibold).monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    /// Only while the exercise is still untouched today — once sets exist, the
    /// current session is the better reference than last week.
    private func suggestion(for entry: LoggedExercise) -> ProgressionSuggestion? {
        guard entry.sortedSets.isEmpty, let exercise = entry.exercise else { return nil }
        guard let history = Progression.lastSets(
            for: exercise.id,
            excluding: session,
            in: allSessions
        ) else { return nil }
        return Progression.suggest(
            stepKg: exercise.progressionStepKg,
            targetReps: entry.targetReps,
            lastSets: history.sets
        )
    }

    private func delete(_ set: LoggedSet, from entry: LoggedExercise) {
        context.delete(set)
        saveReporter.perform("Satz löschen") { try context.save() }
    }

    private func finish() {
        session.endedAt = Date()
        saveReporter.perform("Training beenden") { try context.save() }
    }
}

private struct SessionExercisePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(SaveReporter.self) private var saveReporter
    @Query(sort: \Exercise.name) private var exercises: [Exercise]

    let session: WorkoutSession
    @State private var search = ""
    @State private var showingNew = false

    private var available: [Exercise] {
        let used = Set(session.sortedExercises.compactMap { $0.exercise?.id })
        return exercises.filter {
            !used.contains($0.id) && (search.isEmpty || $0.name.localizedCaseInsensitiveContains(search))
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Button("Neue Übung anlegen", systemImage: "plus.circle") {
                    showingNew = true
                }
                .glassRow()
                ForEach(Array(available.enumerated()), id: \.element.id) { index, exercise in
                    Button(exercise.name) { add(exercise) }
                        .accessibilityIdentifier("pickSession-\(exercise.name)")
                        .glassRow(.of(index, count: available.count))
                }
            }
            .glassFormBackground()
            .searchable(text: $search, prompt: "Übung suchen")
            .navigationTitle("Übung hinzufügen")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
            }
            .sheet(isPresented: $showingNew) {
                NewExerciseView(existing: exercises) { add($0) }
            }
        }
    }

    private func add(_ exercise: Exercise) {
        let entry = LoggedExercise(order: session.sortedExercises.count, exercise: exercise)
        entry.session = session
        context.insert(entry)
        saveReporter.perform("Übung hinzufügen") { try context.save() }
        dismiss()
    }
}

private struct LoggedExerciseCard: View {
    @ScaledMetric(relativeTo: .caption) private var indexWidth: CGFloat = 22

    let entry: LoggedExercise
    var suggestion: ProgressionSuggestion?
    var onAddSet: () -> Void
    var onEditSet: (LoggedSet) -> Void
    var onDeleteSet: (LoggedSet) -> Void

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: Theme.Spacing.regular) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(entry.name)
                            .font(.system(.title3, design: .serif).weight(.semibold))
                        if !entry.targetText.isEmpty {
                            Text("Ziel: \(entry.targetText)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer(minLength: Theme.Spacing.tight)
                    if let muscle = entry.exercise?.primary {
                        GlassBadge(text: muscle.displayName, tint: muscle.category.color)
                    }
                }

                if let suggestion {
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: suggestion.raisesWeight ? "arrow.up.circle.fill" : "equal.circle.fill")
                            .font(.caption)
                            .foregroundStyle(suggestion.raisesWeight ? Color.accentColor : .secondary)
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Vorschlag: \(Progression.format(suggestion.weight)) kg × \(suggestion.reps)")
                                .font(.caption.weight(.semibold))
                            Text(suggestion.rationale)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("suggestion-\(entry.name)")
                }

                if entry.sortedSets.isEmpty {
                    Text("Noch kein Satz")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(entry.sortedSets.enumerated()), id: \.element.id) { index, set in
                            if index > 0 { Divider().opacity(0.3) }
                            HStack {
                                // Tapping the set opens it for correction. A
                                // mistyped weight used to mean deleting the set and
                                // entering it again, which also lost its place in
                                // the order.
                                Button {
                                    onEditSet(set)
                                } label: {
                                    HStack {
                                        Text("\(index + 1).")
                                            .font(.caption.monospacedDigit())
                                            .foregroundStyle(.secondary)
                                            .frame(minWidth: indexWidth, alignment: .leading)
                                        Text(set.summary)
                                            .font(.subheadline.monospacedDigit())
                                        if let rir = set.rir {
                                            Text("RIR \(rir)")
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                        }
                                        Spacer(minLength: Theme.Spacing.tight)
                                    }
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                // Spoken out: VoiceOver reads the badge "RIR" as
                                // three letters, which tells nobody anything. The
                                // label goes on the button as it is — collapsing
                                // the children would turn it into a generic
                                // element that is no longer a button at all.
                                .accessibilityLabel(
                                    "Satz \(index + 1), \(set.summary)"
                                    + (set.rir.map { ", \($0) Wiederholungen in Reserve" } ?? "")
                                )
                                .accessibilityIdentifier("editSet-\(entry.name)-\(index + 1)")
                                .accessibilityHint("Zum Ändern antippen")

                                Button("Satz löschen", systemImage: "minus.circle") {
                                    onDeleteSet(set)
                                }
                                .labelStyle(.iconOnly)
                                .buttonStyle(.plain)
                                .foregroundStyle(.secondary)
                                .accessibilityIdentifier("deleteSet-\(entry.name)-\(index + 1)")
                            }
                            .padding(.vertical, 7)
                        }
                    }
                }

                Button("Satz hinzufügen", systemImage: "plus", action: onAddSet)
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier("addSet-\(entry.name)")
            }
        }
    }
}

/// Which set the editor sheet is for: a new one, or an existing one to correct.
///
/// One value rather than two pieces of state, because "add" and "edit" are the
/// same sheet and two optionals could contradict each other.
private enum SetEditorTarget: Identifiable {
    case newSet(LoggedExercise)
    case existingSet(LoggedSet, LoggedExercise)

    var entry: LoggedExercise {
        switch self {
        case .newSet(let entry): entry
        case .existingSet(_, let entry): entry
        }
    }

    var set: LoggedSet? {
        switch self {
        case .newSet: nil
        case .existingSet(let set, _): set
        }
    }

    var id: String {
        switch self {
        case .newSet(let entry): "new-\(entry.id)"
        case .existingSet(let set, _): "edit-\(set.id)"
        }
    }
}

/// Entry form for one set — adding one, or correcting one already logged.
///
/// For a **new** set the weight is suggested, not prefilled: the previous set of
/// this session, or the progression from last time. It appears as a greyed
/// placeholder, so saving without typing adopts it and typing replaces it
/// outright. Real text in the field would be edited in place instead — typing
/// "65" into a prefilled "60" produced "660".
///
/// Correcting an existing set works the same way: its weight appears as the
/// placeholder, so it is visible, saving untouched keeps it, and typing replaces
/// it whole. Putting it in as editable text was tried and is worse — the field
/// filters out characters it does not understand, backspace included, so a value
/// could be typed into but never cleared.
private struct SetEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(RestTimer.self) private var restTimer
    @Environment(SaveReporter.self) private var saveReporter
    let entry: LoggedExercise
    var existing: LoggedSet?
    let session: WorkoutSession
    var suggestion: ProgressionSuggestion?

    @State private var weight: Double?
    @State private var suggestedWeight: Double?
    @State private var reps: Int = 8
    @State private var rir: Int = 2

    private var isEditing: Bool { existing != nil }

    /// What gets stored: whatever was typed, otherwise the suggestion.
    private var effectiveWeight: Double { weight ?? suggestedWeight ?? 0 }

    /// Position of the set being corrected, counting from one.
    private var setNumber: Int {
        guard let existing, let index = entry.sortedSets.firstIndex(where: { $0.id == existing.id }) else {
            return entry.sortedSets.count + 1
        }
        return index + 1
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DecimalField(
                        label: "Gewicht",
                        unit: "kg",
                        identifier: "setWeight",
                        placeholderValue: suggestedWeight,
                        value: $weight
                    )
                    .glassRow(.first)
                    Stepper(value: $reps, in: 1...50) {
                        HStack {
                            Text("Wiederholungen")
                            Spacer()
                            Text("\(reps)")
                                .font(.body.monospacedDigit())
                        }
                    }
                    .accessibilityIdentifier("setReps")
                    .glassRow(.last)
                } header: {
                    Text(entry.name)
                } footer: {
                    if !entry.targetText.isEmpty {
                        Text("Ziel: \(entry.targetText)")
                    }
                }

                Section {
                    Picker("Reps in Reserve", selection: $rir) {
                        ForEach(0...5, id: \.self) { value in
                            Text("\(value)").tag(value)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityLabel("Reps in Reserve")
                    .accessibilityIdentifier("setRir")
                    .glassRow()
                } header: {
                    // Spelled out, not just "RIR": the abbreviation says nothing
                    // to anyone who has not met it before, and this is the screen
                    // where it is first used.
                    Text("RIR — Reps in Reserve")
                } footer: {
                    Text("Wie viele Wiederholungen du am Ende noch geschafft hättest. "
                         + "0 heißt: keine mehr, der Satz ging bis zum Muskelversagen.")
                }
            }
            .glassFormBackground()
            .navigationTitle(isEditing ? "Satz \(setNumber) ändern" : "Satz \(setNumber)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern") { save() }
                        .accessibilityIdentifier("saveSet")
                }
            }
            .onAppear(perform: prefill)
        }
    }

    private func prefill() {
        if let existing {
            // Correcting a set: its own values. The weight goes in as the
            // placeholder rather than as text, so typing replaces it outright
            // instead of being merged into it.
            suggestedWeight = existing.weight > 0 ? existing.weight : nil
            reps = existing.reps
            rir = existing.rir ?? 2
            return
        }
        // Within the session the previous set wins; for the first set of the day
        // the suggestion from last time does. Reps and RIR are prefilled for real
        // — a stepper and a segmented picker cannot be mis-edited the way a text
        // field can.
        if let last = entry.lastSet {
            suggestedWeight = last.weight > 0 ? last.weight : nil
            reps = last.reps
            rir = last.rir ?? 2
        } else if let suggestion {
            suggestedWeight = suggestion.weight > 0 ? suggestion.weight : nil
            reps = suggestion.reps
        } else {
            reps = entry.targetReps.lowerBound
        }
    }

    private func save() {
        if let existing {
            existing.weight = effectiveWeight
            existing.reps = reps
            existing.rir = rir
            saveReporter.perform("Satz ändern") { try context.save() }
            // No pause: correcting a set is not finishing one.
            dismiss()
            return
        }
        let set = LoggedSet(
            order: entry.nextOrder,
            weight: effectiveWeight,
            reps: reps,
            rir: rir,
            // A set entered afterwards belongs to the day it was performed, not to
            // the evening it was typed in.
            completedAt: session.isActive ? Date() : session.startedAt
        )
        set.loggedExercise = entry
        context.insert(set)
        saveReporter.perform("Satz sichern") { try context.save() }
        if session.isActive {
            // Start the pause the plan prescribes for this exercise — reaching for
            // the timer right after a set is exactly when you least want to fiddle.
            // Filling in last week's training is not that moment.
            restTimer.start(seconds: Double(entry.restSeconds), context: entry.name)
        }
        dismiss()
    }
}
