import Charts
import SwiftUI

/// One exercise across every session it appeared in: what it does over time, not
/// just what it did last Tuesday.
///
/// The screen it replaced showed the same sets the session detail already showed,
/// one screen deeper — a page that repeats its own parent is worse than no page.
struct ExerciseProgressView: View {
    @ScaledMetric(relativeTo: .caption) private var indexWidth: CGFloat = 22
    private let bottomNavigationClearance: CGFloat = 100

    let exerciseName: String
    let exerciseID: UUID?
    let sessions: [WorkoutSession]
    @State private var selectedPoint: ExercisePoint?

    /// Newest first, the order the session list reads in.
    private var entries: [ExerciseHistoryEntry] {
        guard let exerciseID else { return [] }
        return SessionHistory.entries(for: exerciseID, in: sessions)
    }

    /// Oldest first, the order a chart needs.
    private var points: [ExercisePoint] { ExerciseProgress.points(from: entries) }

    var body: some View {
        ScrollView {
            GlassEffectContainer(spacing: Theme.Spacing.regular) {
                VStack(spacing: Theme.Spacing.regular) {
                    if entries.isEmpty {
                        GlassCard {
                            Text("Diese Übung wurde noch nicht geloggt.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        headlineCard
                        if points.count > 1 { chartCard }
                        recordsCard
                        ForEach(entries) { entry in
                            sessionCard(entry)
                        }
                    }
                }
                .padding(Theme.Spacing.regular)
                // This detail is pushed above RootView's floating navigation.
                // `clearsBottomAccessory()` only accounts for the optional timer.
                .padding(.bottom, bottomNavigationClearance)
            }
        }
        .scrollEdgeEffectStyle(.soft, for: .top)
        .clearsBottomAccessory()
        .background(AppBackground())
        .navigationTitle(exerciseName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
    }

    // MARK: - Headline

    private var headlineCard: some View {
        SolidCard {
            VStack(alignment: .leading, spacing: Theme.Spacing.regular) {
                HStack(spacing: Theme.Spacing.tight) {
                    stat(
                        "Arbeitsgewicht",
                        Progression.format(points.last?.workingWeight ?? 0) + " kg",
                        change: ExerciseProgress.weightChange(points).map { ExerciseProgress.signed($0) }
                    )
                    stat(
                        "Volumen",
                        "\(Int(points.last?.volume ?? 0)) kg",
                        change: ExerciseProgress.volumeChange(points).map {
                            ExerciseProgress.signed($0, unit: "")
                        }
                    )
                    stat(
                        "1RM geschätzt",
                        points.last?.estimatedOneRepMax.map { Progression.format($0) + " kg" } ?? "—",
                        change: nil
                    )
                }
                Text("\(entries.count) \(entries.count == 1 ? "Einheit" : "Einheiten") · "
                     + "Veränderung seit der ersten")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityIdentifier("weightTrend")
    }

    private func stat(_ label: String, _ value: String, change: String?) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(value)
                .font(.title3.weight(.semibold).monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            // Only after a second session: with one, there is nothing to compare
            // against and a "+0" would read as a measured result.
            Text(change ?? " ")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(tint(for: change))
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private func tint(for change: String?) -> Color {
        guard change != nil else { return .clear }
        return .accentColor
    }

    // MARK: - Chart

    private var chartCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: Theme.Spacing.tight) {
                SectionHeader(title: "Verlauf", subtitle: "Arbeitsgewicht je Einheit")
                selectionReadout
                chart
                    .frame(height: 170)
                    // Swift Charts annotations never reach the accessibility tree,
                    // so the whole chart carries one spoken summary instead.
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Verlauf des Arbeitsgewichts")
                    .accessibilityValue(spokenChart)
                    .accessibilityIdentifier("progressChart")
            }
        }
    }

    private var selectionReadout: some View {
        Text(selectedPoint.map {
            "\($0.date.formatted(.dateTime.day().month(.abbreviated).year())) · \(Progression.format($0.workingWeight)) kg"
        } ?? "Im Verlauf streichen, um eine Einheit zu sehen")
            .font(.caption.monospacedDigit())
            .foregroundStyle(selectedPoint == nil ? .secondary : .primary)
            .accessibilityIdentifier("progressChartSelection")
    }

    private var chart: some View {
        Chart {
            ForEach(points) { point in
                LineMark(
                    x: .value("Datum", point.date),
                    y: .value("Gewicht", point.workingWeight)
                )
                .interpolationMethod(.linear)
                .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                .foregroundStyle(.tint)

                PointMark(
                    x: .value("Datum", point.date),
                    y: .value("Gewicht", point.workingWeight)
                )
                .symbolSize(60)
                .foregroundStyle(.tint)
            }

            if let selectedPoint {
                RuleMark(x: .value("Auswahl", selectedPoint.date))
                    .foregroundStyle(.secondary.opacity(0.65))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                PointMark(
                    x: .value("Auswahl", selectedPoint.date),
                    y: .value("Gewicht", selectedPoint.workingWeight)
                )
                .symbolSize(110)
                .foregroundStyle(.tint)
            }
        }
        .chartYScale(domain: ExerciseProgress.range(of: points.map(\.workingWeight)) ?? 0...1)
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine().foregroundStyle(.secondary.opacity(0.25))
                AxisValueLabel {
                    if let number = value.as(Double.self) {
                        Text(number, format: .number.precision(.fractionLength(0...1)))
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: ChartDateAxis.endpoints(for: points.map(\.date))) { value in
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        Text(date, format: .dateTime.day().month(.abbreviated))
                            .font(.caption2)
                    }
                }
            }
        }
        .chartOverlay { proxy in
            GeometryReader { geometry in
                Rectangle()
                    .fill(.clear)
                    .contentShape(Rectangle())
                    .gesture(DragGesture(minimumDistance: 0).onChanged { gesture in
                        guard let plotFrame = proxy.plotFrame else { return }
                        let plotArea = geometry[plotFrame]
                        let x = gesture.location.x - plotArea.origin.x
                        guard x >= 0, x <= plotArea.width,
                              let date: Date = proxy.value(atX: x)
                        else { return }
                        selectedPoint = ExerciseProgress.nearest(to: date, in: points)
                    })
            }
        }
    }

    private var spokenChart: String {
        let parts = points.map { point in
            "\(point.date.formatted(.dateTime.day().month(.abbreviated))): "
            + "\(Progression.format(point.workingWeight)) Kilo"
        }
        return parts.joined(separator: ", ")
    }

    // MARK: - Records

    private var recordsCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: Theme.Spacing.tight) {
                SectionHeader(title: "Bestwerte", subtitle: "Seit du diese Übung loggst")

                if let heaviest = ExerciseProgress.heaviestSet(in: entries) {
                    record(
                        "Schwerster Satz",
                        heaviest.set.summary,
                        date: heaviest.date,
                        identifier: "recordHeaviest"
                    )
                }
                if let best = ExerciseProgress.bestVolume(points) {
                    record(
                        "Meistes Volumen",
                        "\(Int(best.volume)) kg · \(best.sets) Sätze",
                        date: best.date,
                        identifier: "recordVolume"
                    )
                }
                if let best = ExerciseProgress.bestOneRepMax(points), let value = best.estimatedOneRepMax {
                    record(
                        "Bestes geschätztes 1RM",
                        "\(Progression.format(value)) kg",
                        date: best.date,
                        identifier: "recordOneRM"
                    )
                }

                // Named as an estimate, because it is one: no single rep at that
                // weight was ever performed.
                Text("1RM nach Epley: Gewicht × (1 + Wdh. ÷ 30). Eine Schätzung, "
                     + "kein gemessener Wert — sie steigt auch, wenn du bei gleichem "
                     + "Gewicht mehr Wiederholungen schaffst.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func record(_ label: String, _ value: String, date: Date, identifier: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer(minLength: Theme.Spacing.tight)
            Text(value)
                .font(.subheadline.weight(.medium).monospacedDigit())
            Text(date, format: .dateTime.day().month(.abbreviated))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(identifier)
    }

    // MARK: - Sessions

    /// A compact training record: the date orients the scan, the volume gives
    /// context, and the individual sets remain available without competing with
    /// either one.
    private func sessionCard(_ entry: ExerciseHistoryEntry) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: Theme.Spacing.tight) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.date, format: .dateTime.weekday(.abbreviated).day().month(.abbreviated).year())
                            .font(.headline)
                        Text(entry.sessionName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: Theme.Spacing.tight)
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(Int(entry.sets.reduce(0) { $0 + $1.load })) kg")
                            .font(.subheadline.weight(.semibold).monospacedDigit())
                        Text("Volumen")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                VStack(spacing: 0) {
                    ForEach(Array(entry.sets.enumerated()), id: \.element.id) { index, set in
                        if index > 0 { Divider().opacity(0.3) }
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
                            Spacer()
                        }
                        .padding(.vertical, 6)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(
                            "Satz \(index + 1), \(set.summary)"
                            + (set.rir.map { ", \($0) Wiederholungen in Reserve" } ?? "")
                        )
                    }
                }
            }
        }
        .accessibilityIdentifier("progressSession-\(entry.sessionName)")
    }
}
