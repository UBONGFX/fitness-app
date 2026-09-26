import SwiftData
import SwiftUI

/// Editing the target corridors. A goal is a corridor even when both ends are
/// equal, so the same two fields work for "80–82 kg" and for "FFMI 21,5".
struct GoalsFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(SaveReporter.self) private var saveReporter
    @Query(sort: \MetricGoal.metricRaw) private var goals: [MetricGoal]

    @State private var heightCm = UserProfile.heightCentimetres
    @State private var choosingHeight = false

    var body: some View {
        NavigationStack {
            Form {
                // The same control as in the profile, not a second shape for the
                // same value: a metre field with a comma was the thing that let
                // "1,8" stand where 183 was meant.
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

                Section {
                    Text("Von und Bis dürfen gleich sein — daraus wird ein einzelner Zielwert.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .glassRow()
                }
                ForEach(BodyMetric.allCases) { metric in
                    if let goal = goals.first(where: { $0.metric == metric }) {
                        Section(metric.displayName) {
                            DecimalField(
                                label: "Von",
                                unit: metric.unit,
                                identifier: "goal-\(metric.rawValue)-lower",
                                value: bound(goal, \.lowerBound)
                            )
                            .glassRow(.first)
                            DecimalField(
                                label: "Bis",
                                unit: metric.unit,
                                identifier: "goal-\(metric.rawValue)-upper",
                                value: bound(goal, \.upperBound)
                            )
                            .glassRow(.last)
                        }
                    }
                }
            }
            .glassFormBackground()
            .sheet(isPresented: $choosingHeight) {
                HeightPickerSheet(centimetres: $heightCm)
                    .presentationDetents([.height(320)])
            }
            .onChange(of: heightCm) { _, new in UserProfile.heightCentimetres = new }
            .navigationTitle("Ziele & Profil")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") {
                        saveReporter.perform("Ziele sichern") { try context.save() }
                        dismiss()
                    }
                }
            }
        }
    }

    /// Clearing a bound leaves the stored value untouched rather than writing 0 —
    /// a goal of "0 cm" is never what an empty field means.
    private func bound(_ goal: MetricGoal, _ keyPath: ReferenceWritableKeyPath<MetricGoal, Double>) -> Binding<Double?> {
        Binding(
            get: { goal[keyPath: keyPath] },
            set: { newValue in
                if let newValue { goal[keyPath: keyPath] = newValue }
            }
        )
    }
}
