import SwiftData
import SwiftUI

/// Only selected metrics are listed. A selected metric may be observed without a
/// target, or given one value or a corridor later.
struct GoalsFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(SaveReporter.self) private var saveReporter
    @Query(sort: \MetricGoal.metricRaw) private var goals: [MetricGoal]

    @State private var drafts: [BodyMetric: GoalDraft] = [:]
    @State private var loaded = false
    @State private var expandedMetric: BodyMetric?
    @State private var heightCm = UserProfile.heightCentimetres
    @State private var choosingHeight = false

    private var hasInvalidValue: Bool {
        drafts.values.contains { $0.isEnabled && $0.hasInvalidValue }
    }

    private var availableMetrics: [BodyMetric] {
        BodyMetric.allCases.filter { drafts[$0]?.isEnabled != true }
    }

    private func selectedMetrics(for priority: GoalPriority) -> [BodyMetric] {
        BodyMetric.allCases.filter {
            drafts[$0]?.isEnabled == true && drafts[$0]?.priority == priority
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Wähle, was dir wichtig ist. Ein Zielwert ist optional; primäre Ziele erscheinen im Fortschritt zuerst.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .glassRow()
                }

                Section {
                    Menu {
                        ForEach(availableMetrics) { metric in
                            Button(metric.displayName) { add(metric) }
                                .accessibilityIdentifier("addGoal-\(metric.rawValue)")
                        }
                    } label: {
                        Label("Ziel hinzufügen", systemImage: "plus")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .disabled(availableMetrics.isEmpty)
                    .accessibilityIdentifier("addGoal")
                    .glassRow()
                }

                let primaryMetrics = selectedMetrics(for: .primary)
                if primaryMetrics.isEmpty {
                    Section("Primäre Ziele") {
                        Text("Noch kein primäres Ziel")
                            .foregroundStyle(.secondary)
                            .glassRow()
                    }
                } else {
                    goalSections(primaryMetrics, title: "Primäre Ziele")
                }

                let secondaryMetrics = selectedMetrics(for: .secondary)
                if !secondaryMetrics.isEmpty {
                    goalSections(secondaryMetrics, title: "Sekundäre Ziele")
                }

                if drafts[.ffmi]?.isEnabled == true {
                    Section("Für den FFMI") {
                        Button {
                            choosingHeight = true
                        } label: {
                            HStack {
                                Text("Größe")
                                    .foregroundStyle(.primary)
                                Spacer(minLength: Theme.Spacing.tight)
                                Text(UserProfile.heightText(centimetres: heightCm))
                                    .foregroundStyle(.secondary)
                                Image(systemName: "chevron.right")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("bodyHeight")
                        .accessibilityLabel("Größe")
                        .accessibilityValue(UserProfile.heightText(centimetres: heightCm))
                        .glassRow(.first)

                        Text("Wird für den FFMI gebraucht.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .glassRow(.last)
                    }
                }
            }
            .glassFormBackground()
            .listSectionSpacing(.compact)
            .sheet(isPresented: $choosingHeight) {
                HeightPickerSheet(centimetres: $heightCm)
                    .presentationDetents([.height(320)])
            }
            .onAppear(perform: load)
            .navigationTitle("Ziele")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern", action: save)
                        .disabled(!loaded || hasInvalidValue)
                        .accessibilityIdentifier("saveGoals")
                }
            }
        }
    }

    @ViewBuilder
    private func goalSections(_ metrics: [BodyMetric], title: String) -> some View {
        ForEach(Array(metrics.enumerated()), id: \.element) { index, metric in
            Section {
                goalRows(for: metric)
            } header: {
                if index == 0 { Text(title) }
            }
        }
    }

    @ViewBuilder
    private func goalRows(for metric: BodyMetric) -> some View {
        let expanded = expandedMetric == metric
        Button {
            expandedMetric = expanded ? nil : metric
        } label: {
            HStack(spacing: Theme.Spacing.regular) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(metric.displayName)
                        .foregroundStyle(.primary)
                    Text(targetText(for: metric))
                        .font(.caption)
                        .foregroundStyle(drafts[metric]?.hasInvalidValue == true ? Color.red : Color.secondary)
                }
                Spacer(minLength: Theme.Spacing.tight)
                Image(systemName: expanded ? "chevron.up" : "chevron.down")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("editGoal-\(metric.rawValue)")
        .glassRow(expanded ? .first : .only)

        if expanded {
            Picker("Priorität", selection: priorityBinding(for: metric)) {
                ForEach(GoalPriority.allCases, id: \.self) { priority in
                    Text(priority.displayName).tag(priority)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("goal-\(metric.rawValue)-priority")
            .glassRow(.middle)

            DecimalField(
                label: "Zielwert oder Von",
                unit: metric.unit,
                identifier: "goal-\(metric.rawValue)-lower",
                value: valueBinding(for: metric, \.lower)
            )
            .glassRow(.middle)

            DecimalField(
                label: "Bis (optional)",
                unit: metric.unit,
                identifier: "goal-\(metric.rawValue)-upper",
                value: valueBinding(for: metric, \.upper)
            )
            .glassRow(.middle)

            Button("Ziel entfernen", systemImage: "trash", role: .destructive) {
                var draft = drafts[metric] ?? GoalDraft()
                draft.isEnabled = false
                drafts[metric] = draft
                expandedMetric = nil
            }
            .accessibilityIdentifier("removeGoal-\(metric.rawValue)")
            .glassRow(.last)
        }
    }

    private func targetText(for metric: BodyMetric) -> String {
        guard let draft = drafts[metric] else { return "Beobachten · ohne Zielwert" }
        if draft.hasInvalidValue { return "Wert muss größer als 0 sein" }
        guard let target = draft.target else { return "Beobachten · ohne Zielwert" }
        if target.lower == target.upper { return metric.formatted(target.lower) }
        let lower = target.lower.formatted(.number.precision(.fractionLength(0...1)))
        let upper = target.upper.formatted(.number.precision(.fractionLength(0...1)))
        return metric.unit.isEmpty ? "\(lower)–\(upper)" : "\(lower)–\(upper) \(metric.unit)"
    }

    private func add(_ metric: BodyMetric) {
        var draft = drafts[metric] ?? GoalDraft()
        draft.isEnabled = true
        if selectedMetrics(for: .primary).isEmpty {
            draft.priority = .primary
        }
        drafts[metric] = draft
        expandedMetric = metric
    }

    private func load() {
        guard !loaded else { return }
        for metric in BodyMetric.allCases {
            if let goal = goals.first(where: { $0.metric == metric }) {
                drafts[metric] = GoalDraft(
                    isEnabled: true,
                    lower: goal.hasTarget ? goal.lowerBound : nil,
                    upper: goal.hasTarget && !goal.isSingleValue ? goal.upperBound : nil,
                    priority: goal.priority
                )
            } else {
                drafts[metric] = GoalDraft()
            }
        }
        loaded = true
    }

    private func priorityBinding(for metric: BodyMetric) -> Binding<GoalPriority> {
        Binding(
            get: { drafts[metric]?.priority ?? .secondary },
            set: { priority in
                var draft = drafts[metric] ?? GoalDraft()
                draft.priority = priority
                drafts[metric] = draft
            }
        )
    }

    private func valueBinding(
        for metric: BodyMetric,
        _ keyPath: WritableKeyPath<GoalDraft, Double?>
    ) -> Binding<Double?> {
        Binding(
            get: { drafts[metric]?[keyPath: keyPath] },
            set: { value in
                var draft = drafts[metric] ?? GoalDraft()
                draft[keyPath: keyPath] = value
                drafts[metric] = draft
            }
        )
    }

    private func save() {
        guard !hasInvalidValue else { return }
        let saved = saveReporter.perform("Ziele sichern") {
            for metric in BodyMetric.allCases {
                let existing = goals.filter { $0.metric == metric }
                guard let draft = drafts[metric], draft.isEnabled else {
                    existing.forEach(context.delete)
                    continue
                }
                let target = draft.target
                if let goal = existing.first {
                    goal.lowerBound = target?.lower ?? 0
                    goal.upperBound = target?.upper ?? 0
                    goal.hasTarget = target != nil
                    goal.priority = draft.priority
                    existing.dropFirst().forEach(context.delete)
                } else {
                    context.insert(MetricGoal(
                        metric: metric,
                        lowerBound: target?.lower ?? 0,
                        upperBound: target?.upper ?? 0,
                        priority: draft.priority,
                        hasTarget: target != nil
                    ))
                }
            }
            try context.save()
        }
        if saved {
            UserProfile.heightCentimetres = heightCm
            dismiss()
        }
    }
}

struct GoalDraft {
    var isEnabled = false
    var lower: Double?
    var upper: Double?
    var priority: GoalPriority = .secondary

    var hasInvalidValue: Bool {
        [lower, upper].compactMap { $0 }.contains { !$0.isFinite || $0 <= 0 }
    }

    var target: (lower: Double, upper: Double)? {
        guard isEnabled else { return nil }
        let values = [lower, upper].compactMap { $0 }
        guard !values.isEmpty, values.allSatisfy({ $0.isFinite && $0 > 0 }) else { return nil }
        return (values.min()!, values.max()!)
    }
}
