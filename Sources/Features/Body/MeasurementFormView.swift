import SwiftData
import SwiftUI

struct MeasurementFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(SaveReporter.self) private var saveReporter

    /// `nil` creates a new measurement; an existing one is edited in place.
    var existing: BodyMeasurement?

    @State private var date = Date()
    @State private var note = ""
    @State private var values: [BodyMetric: Double] = [:]

    private var suggestedFFMI: Double? {
        HealthImport.derivedFFMI(
            weight: values[.weight],
            bodyFat: values[.bodyFat],
            heightMeters: UserProfile.heightMeters
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("Datum", selection: $date, in: ...Date(), displayedComponents: .date)
                        .glassRow(.first)
                    TextField("Notiz", text: $note)
                        .glassRow(.last)
                }

                Section("Körperwerte") {
                    let composition = BodyMetric.allCases.filter(\.isComposition)
                    let showsSuggestion = suggestedFFMI != nil && values[.ffmi] == nil
                    ForEach(Array(composition.enumerated()), id: \.element.id) { index, metric in
                        DecimalField(metric: metric, value: binding(for: metric))
                            .glassRow(
                                showsSuggestion
                                    ? (index == 0 ? .first : .middle)
                                    : .of(index, count: composition.count)
                            )
                    }
                    if let suggestedFFMI, values[.ffmi] == nil {
                        Label(
                            "FFMI wird berechnet: \(suggestedFFMI, format: .number.precision(.fractionLength(1)))",
                            systemImage: "function"
                        )
                        .font(.footnote)
                        .glassRow(.last)
                    }
                }

                Section("Maße") {
                    let sizes = BodyMetric.allCases.filter { !$0.isComposition }
                    ForEach(Array(sizes.enumerated()), id: \.element.id) { index, metric in
                        DecimalField(metric: metric, value: binding(for: metric))
                            .glassRow(.of(index, count: sizes.count))
                    }
                }
            }
            .glassFormBackground()
            .navigationTitle(existing == nil ? "Neue Messung" : "Messung bearbeiten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern") { save() }
                        .disabled(values.isEmpty)
                }
            }
            .onAppear(perform: load)
        }
    }

    private func binding(for metric: BodyMetric) -> Binding<Double?> {
        Binding(
            get: { values[metric] },
            set: { newValue in
                if let newValue {
                    values[metric] = newValue
                } else {
                    values.removeValue(forKey: metric)
                }
            }
        )
    }

    private func load() {
        guard let existing else { return }
        date = existing.date
        note = existing.note
        for metric in BodyMetric.allCases {
            values[metric] = existing[metric]
        }
    }

    private func save() {
        let measurement = existing ?? BodyMeasurement()
        let ffmi = HealthImport.resolvedFFMI(
            entered: values[.ffmi],
            previous: existing,
            weight: values[.weight],
            bodyFat: values[.bodyFat],
            heightMeters: UserProfile.heightMeters
        )
        measurement.date = date
        measurement.note = note
        for metric in BodyMetric.allCases {
            measurement[metric] = metric == .ffmi ? ffmi : values[metric]
        }
        if existing == nil {
            context.insert(measurement)
        }
        saveReporter.perform("Messung sichern") { try context.save() }
        dismiss()
    }
}
