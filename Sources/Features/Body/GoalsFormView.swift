import SwiftData
import SwiftUI

/// A metric without a saved `MetricGoal` has no target. Each target can be a
/// single value or a corridor, without asking for values the user does not track.
struct GoalsFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(SaveReporter.self) private var saveReporter
    @Query(sort: \MetricGoal.metricRaw) private var goals: [MetricGoal]

    @State private var drafts: [BodyMetric: GoalDraft] = [:]
    @State private var loaded = false
    @State private var heightCm = UserProfile.heightCentimetres
    @State private var choosingHeight = false

    private var hasIncompleteGoal: Bool {
        drafts.values.contains { $0.isEnabled && $0.target == nil }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Wähle nur die Werte, die du verfolgen möchtest. Ein Wert reicht; mit zwei Werten legst du einen Bereich fest.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .glassRow()
                }

                ForEach(BodyMetric.allCases) { metric in
                    Section(metric.displayName) {
                        Toggle("Als Ziel verfolgen", isOn: enabledBinding(for: metric))
                            .accessibilityIdentifier("goal-\(metric.rawValue)-enabled")
                            .glassRow(drafts[metric]?.isEnabled == true ? .first : .only)

                        if drafts[metric]?.isEnabled == true {
                            DecimalField(
                                label: "Wert oder Von",
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
                            .glassRow(.last)
                        }
                    }
                }

                Section("Körpergröße") {
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
            .glassFormBackground()
            .sheet(isPresented: $choosingHeight) {
                HeightPickerSheet(centimetres: $heightCm)
                    .presentationDetents([.height(320)])
            }
            .onAppear(perform: load)
            .navigationTitle("Ziele bearbeiten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern", action: save)
                        .disabled(!loaded || hasIncompleteGoal)
                        .accessibilityIdentifier("saveGoals")
                }
            }
        }
    }

    private func load() {
        guard !loaded else { return }
        for metric in BodyMetric.allCases {
            if let goal = goals.first(where: { $0.metric == metric }) {
                drafts[metric] = GoalDraft(
                    isEnabled: true,
                    lower: goal.lowerBound,
                    upper: goal.isSingleValue ? nil : goal.upperBound
                )
            } else {
                drafts[metric] = GoalDraft()
            }
        }
        loaded = true
    }

    private func enabledBinding(for metric: BodyMetric) -> Binding<Bool> {
        Binding(
            get: { drafts[metric]?.isEnabled ?? false },
            set: { isEnabled in
                var draft = drafts[metric] ?? GoalDraft()
                draft.isEnabled = isEnabled
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
        guard !hasIncompleteGoal else { return }
        let saved = saveReporter.perform("Ziele sichern") {
            for metric in BodyMetric.allCases {
                let existing = goals.filter { $0.metric == metric }
                guard let target = drafts[metric]?.target else {
                    existing.forEach(context.delete)
                    continue
                }
                if let goal = existing.first {
                    goal.lowerBound = target.lower
                    goal.upperBound = target.upper
                    existing.dropFirst().forEach(context.delete)
                } else {
                    context.insert(MetricGoal(metric: metric, lowerBound: target.lower, upperBound: target.upper))
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

    var target: (lower: Double, upper: Double)? {
        guard isEnabled else { return nil }
        let values = [lower, upper].compactMap { $0 }
        guard !values.isEmpty, values.allSatisfy({ $0.isFinite && $0 > 0 }) else { return nil }
        return (values.min()!, values.max()!)
    }
}
