import SwiftData
import SwiftUI

struct BodyView: View {
    var isUsingFallbackStore = false
    @Environment(\.colorScheme) private var scheme

    @Environment(\.modelContext) private var context
    @Environment(SaveReporter.self) private var saveReporter
    @Query(sort: \BodyMeasurement.date, order: .reverse)
    private var measurements: [BodyMeasurement]

    @Query private var goals: [MetricGoal]

    @State private var showingForm = false
    @State private var editing: BodyMeasurement?
    @State private var chartMetric: BodyMetric = .weight
    @State private var showingGoals = false
    @State private var section = BodySection.overview

    private var goalForChart: MetricGoal? {
        goals.first { $0.metric == chartMetric }
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: Theme.Spacing.regular) {
                FieldGuidePageTitle(title: "Körper")
                    .padding(.horizontal, Theme.Spacing.regular)
                    .padding(.top, Theme.Spacing.tight)
                Group {
                    if measurements.isEmpty && goals.isEmpty {
                        emptyState
                    } else {
                        content
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .safeAreaInset(edge: .top) {
                if isUsingFallbackStore {
                    Label(
                        "Speicher nicht verfügbar — Eingaben gehen beim Beenden verloren.",
                        systemImage: "exclamationmark.triangle.fill"
                    )
                    .font(.footnote)
                    .padding(Theme.Spacing.regular)
                    .background(Theme.Palette.surface(scheme), in: .rect(cornerRadius: Theme.Radius.control))
                    .padding(.horizontal, Theme.Spacing.regular)
                }
            }
            .background(AppBackground())
            .onAppear(perform: focusPreferredGoal)
            .onChange(of: goals.map { "\($0.metricRaw):\($0.priorityRaw)" }) { _, _ in
                focusPreferredGoal()
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Messung hinzufügen", systemImage: "plus") {
                        editing = nil
                        showingForm = true
                    }
                }
            }
            .sheet(isPresented: $showingForm) {
                MeasurementFormView(existing: editing)
                    .presentationDetents([.large])
            }
            .sheet(isPresented: $showingGoals) {
                GoalsFormView()
                    .presentationDetents([.large])
            }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("Noch keine Messungen", systemImage: "ruler")
        } description: {
            Text("Einmal im Monat morgens nüchtern messen und eintragen.")
        } actions: {
            Button("Erste Messung erfassen") {
                editing = nil
                showingForm = true
            }
            .buttonStyle(.borderedProminent)

            Button("Ziele festlegen") { showingGoals = true }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("openGoals")
        }
    }

    /// Two halves of the same subject, kept apart.
    ///
    /// Where you stand and where you are going is one question; the log of every
    /// reading is another. Stacking the log under the goals meant scrolling past
    /// the answer to reach the raw data, and past the raw data to reach nothing.
    private var content: some View {
        VStack(spacing: 0) {
            Picker("Ansicht", selection: $section) {
                ForEach(BodySection.allCases) { option in
                    Text(option.displayName).tag(option)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("bodySection")
            .padding(.horizontal, Theme.Spacing.regular)
            .padding(.bottom, Theme.Spacing.tight)

            switch section {
            case .overview: overview
            case .measurements: measurementList
            }
        }
    }

    private var overview: some View {
        ScrollView {
            GlassEffectContainer(spacing: Theme.Spacing.regular) {
                VStack(spacing: Theme.Spacing.regular) {
                    GoalsCard(measurements: measurements, goals: goals) {
                        showingGoals = true
                    }

                    if measurements.isEmpty {
                        GlassCard {
                            VStack(alignment: .leading, spacing: Theme.Spacing.regular) {
                                SectionHeader(
                                    title: "Erste Messung",
                                    subtitle: "Erfasse einen Wert, um seine Entwicklung zu sehen."
                                )
                                Button("Messung erfassen", systemImage: "plus") {
                                    editing = nil
                                    showingForm = true
                                }
                                .buttonStyle(.borderedProminent)
                            }
                        }
                    } else {
                        MetricChartCard(
                            measurements: measurements,
                            goal: goalForChart,
                            metric: $chartMetric
                        )

                        ProportionsCard(measurements: measurements)

                        // A way into the log from here, so the segmented control is
                        // not the only route anyone ever finds.
                        Button {
                            section = .measurements
                        } label: {
                            GlassCard {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Alle Messungen")
                                            .font(.subheadline.weight(.medium))
                                        Text(measurementCountText)
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer(minLength: Theme.Spacing.tight)
                                    Image(systemName: "chevron.right")
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }
                                .contentShape(Rectangle())
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("openMeasurements")
                    }
                }
                .padding(Theme.Spacing.regular)
            }
        }
        .scrollEdgeEffectStyle(.soft, for: .top)
        .clearsBottomAccessory()
    }

    private var measurementCountText: String {
        let count = measurements.count
        let noun = count == 1 ? "Eintrag" : "Einträge"
        guard let latest = measurements.first else { return "\(count) \(noun)" }
        return "\(count) \(noun) · zuletzt \(latest.date.formatted(.dateTime.day().month(.abbreviated).year()))"
    }

    private var measurementList: some View {
        ScrollView {
            GlassEffectContainer(spacing: Theme.Spacing.regular) {
                VStack(spacing: Theme.Spacing.regular) {
                    if measurements.isEmpty {
                        emptyState
                    }
                    ForEach(measurements) { measurement in
                        Button {
                            editing = measurement
                            showingForm = true
                        } label: {
                            MeasurementCard(
                                measurement: measurement,
                                onEdit: {
                                    editing = measurement
                                    showingForm = true
                                },
                                onDelete: { delete(measurement) }
                            )
                        }
                        .buttonStyle(.plain)
                        // No `swipeActions` here: it only works inside a `List`,
                        // and these are cards in a ScrollView — it would compile
                        // and silently do nothing. The menu button on each card
                        // is the discoverable route instead of a hidden long press.
                        .contextMenu {
                            Button("Bearbeiten", systemImage: "pencil") {
                                editing = measurement
                                showingForm = true
                            }
                            Button("Löschen", systemImage: "trash", role: .destructive) {
                                delete(measurement)
                            }
                        }
                    }
                }
                .padding(Theme.Spacing.regular)
            }
        }
        .scrollEdgeEffectStyle(.soft, for: .top)
        .clearsBottomAccessory()
    }

    private func focusPreferredGoal() {
        let preferred = goals.min { lhs, rhs in
            if lhs.priority != rhs.priority {
                return lhs.priority.sortOrder < rhs.priority.sortOrder
            }
            let all = BodyMetric.allCases
            return (all.firstIndex(of: lhs.metric) ?? all.count)
                < (all.firstIndex(of: rhs.metric) ?? all.count)
        }
        if let preferred { chartMetric = preferred.metric }
    }

    private func delete(_ measurement: BodyMeasurement) {
        context.delete(measurement)
        saveReporter.perform("Messung löschen") { try context.save() }
    }
}

private struct MeasurementCard: View {
    let measurement: BodyMeasurement
    var onEdit: (() -> Void)?
    var onDelete: (() -> Void)?

    private var headline: [BodyMetric] { [.weight, .bodyFat, .ffmi] }
    private var circumferences: [BodyMetric] {
        measurement.filledMetrics.filter { !$0.isComposition }
    }

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: Theme.Spacing.regular) {
                HStack(alignment: .firstTextBaseline) {
                    Text(measurement.date, format: .dateTime.day().month(.wide).year())
                        .font(.system(.title3, design: .serif).weight(.semibold))
                    Spacer(minLength: Theme.Spacing.tight)
                    if !measurement.note.isEmpty {
                        Text(measurement.note)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if let onEdit, let onDelete {
                        Menu {
                            Button("Bearbeiten", systemImage: "pencil", action: onEdit)
                            Button("Löschen", systemImage: "trash", role: .destructive, action: onDelete)
                        } label: {
                            Image(systemName: "ellipsis")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
                        }
                        .accessibilityLabel("Weitere Aktionen")
                        .accessibilityIdentifier("cardMenu")
                    }
                }

                HStack(spacing: Theme.Spacing.loose) {
                    ForEach(headline) { metric in
                        if let value = measurement[metric] {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(metric.displayName)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Text(metric.formatted(value))
                                    .font(.title3.weight(.semibold).monospacedDigit())
                            }
                        }
                    }
                }

                if !circumferences.isEmpty {
                    Divider().opacity(0.4)
                    FlowRow(spacing: Theme.Spacing.tight) {
                        ForEach(circumferences) { metric in
                            if let value = measurement[metric] {
                                GlassBadge(
                                    text: "\(metric.displayName) \(metric.formatted(value))",
                                    tint: .teal
                                )
                            }
                        }
                    }
                }
            }
        }
    }
}

/// The two halves of the body screen.
nonisolated enum BodySection: String, CaseIterable, Identifiable, Sendable {
    /// Chart, goals and proportions — where you stand and where you are going.
    case overview
    /// The log: every reading, editable.
    case measurements

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .overview: "Überblick"
        case .measurements: "Messungen"
        }
    }
}
