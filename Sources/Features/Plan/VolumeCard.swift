import SwiftUI

/// Weekly set volume per muscle group: direct sets solid, indirect at half
/// weight and half opacity.
///
/// The bars are deliberately monochrome. Eleven different hues carried no
/// information here — every row already names its muscle group — and only made
/// the card harder to scan. Colour stays where it distinguishes something:
/// the push/pull/legs badges in the plan.
///
/// **Deliberately not Swift Charts**, unlike the body-metric chart. Swift Charts
/// exposed no accessibility elements for its marks here — the bars and their
/// value annotations were invisible to VoiceOver and to UI tests alike, and the
/// widest annotation was clipped at the plot edge. Real views fix all three at
/// once and scale with Dynamic Type.
struct VolumeCard: View {
    enum Mode: String, CaseIterable, Identifiable {
        case plan, actual
        var id: String { rawValue }
        var title: String { self == .plan ? "Plan" : "Diese Woche" }
    }

    let rows: [VolumeRow]
    var comparison: [VolumeComparison] = []

    @State private var mode: Mode = .plan

    /// Upper end of the bar scale, with a little headroom above the longest bar.
    private var scaleMax: Double {
        max((rows.map(\.total).max() ?? 0) * 1.05, WeeklyVolume.guidelineRange.upperBound)
    }

    private var below: [VolumeRow] { WeeklyVolume.belowGuideline(rows) }

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: Theme.Spacing.regular) {
                SectionHeader(
                    title: "Wochenvolumen",
                    subtitle: "Arbeitssätze pro Woche · direkt + indirekt (Sekundär ×0,5)"
                )

                if !comparison.isEmpty {
                    Picker("Ansicht", selection: $mode) {
                        ForEach(Mode.allCases) { option in
                            Text(option.title).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("volumeMode")
                }

                if mode == .plan || comparison.isEmpty {
                    legend
                    VStack(spacing: 9) {
                        ForEach(rows) { row in
                            VolumeBarRow(row: row, scaleMax: scaleMax)
                        }
                    }
                    footnote
                } else {
                    actualSection
                }
            }
        }
    }

    private var legend: some View {
        HStack(spacing: Theme.Spacing.loose) {
            LegendSwatch(text: "direkt", opacity: 0.62)
            LegendSwatch(text: "indirekt", opacity: 0.24)
            Spacer()
        }
        .accessibilityHidden(true)
    }

    private var footnote: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Die Linie bei \(WeeklyVolume.format(WeeklyVolume.guidelineRange.lowerBound)) Sätzen ist ein allgemeiner Richtwert für Muskelaufbau, keine Vorgabe aus deinem Plan.")
            if !below.isEmpty {
                Text("Unter dem Richtwert: \(below.map(\.muscle.displayName).joined(separator: ", ")).")
                    .foregroundStyle(.orange)
            }
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
    }
}

extension VolumeCard {
    private var completion: Double { ActualVolume.overallCompletion(comparison) }

    /// Performed against planned, one row per muscle group the plan covers —
    /// including the ones at zero, which are the interesting ones.
    fileprivate var actualSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.regular) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(completion, format: .percent.precision(.fractionLength(0)))
                    .font(.title3.weight(.semibold).monospacedDigit())
                Text("des Wochen-Solls erledigt")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("weekCompletion")

            VStack(spacing: 9) {
                ForEach(comparison) { row in
                    ComparisonBarRow(row: row, scaleMax: comparisonScale)
                }
            }

            Text("Der helle Balken ist das Soll aus dem Plan, der farbige das, was du geloggt hast.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private var comparisonScale: Double {
        let highest = comparison.flatMap { [$0.planned, $0.actual] }.max() ?? 1
        return max(highest * 1.05, 1)
    }
}

private struct ComparisonBarRow: View {
    let row: VolumeComparison
    let scaleMax: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.tight) {
                Text(row.muscle.displayName)
                    .font(.caption)
                Spacer(minLength: Theme.Spacing.tight)
                Text(row.actualText)
                    .font(.caption.weight(.bold).monospacedDigit())
                    .foregroundStyle(row.actual == 0 ? Color.orange : Color.primary)
                Text("/ \(row.plannedText)")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            GeometryReader { geometry in
                let scale = geometry.size.width / scaleMax
                ZStack(alignment: .leading) {
                    Capsule().fill(.quaternary)
                    // Planned as a pale track, performed drawn on top of it.
                    Capsule()
                        .fill(Color.primary.opacity(0.18))
                        .frame(width: max(row.planned * scale, 0))
                    Capsule()
                        .fill(Color.primary.opacity(0.62))
                        .frame(width: max(row.actual * scale, 0))
                }
            }
            .frame(height: 10)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(row.muscle.displayName)
        .accessibilityValue(
            row.actual == 0
                ? "noch nichts von \(row.plannedText) geplanten Sätzen"
                : "\(row.actualText) von \(row.plannedText) geplanten Sätzen"
        )
    }
}

private struct LegendSwatch: View {
    let text: String
    let opacity: Double

    var body: some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 3)
                .fill(.secondary.opacity(opacity))
                .frame(width: 14, height: 10)
            Text(text)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

private struct VolumeBarRow: View {
    let row: VolumeRow
    let scaleMax: Double

    private var isBelowGuideline: Bool { row.total < WeeklyVolume.guidelineRange.lowerBound }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.tight) {
                Text(row.muscle.displayName)
                    .font(.caption)
                Spacer(minLength: Theme.Spacing.tight)
                Text(row.totalText)
                    .font(.caption.weight(.bold).monospacedDigit())
                    .foregroundStyle(isBelowGuideline ? Color.orange : Color.primary)
                if let breakdown = row.breakdownText {
                    Text("(\(breakdown))")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }

            GeometryReader { geometry in
                let scale = geometry.size.width / scaleMax
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.quaternary)

                    HStack(spacing: 0) {
                        Rectangle()
                            .fill(Color.primary.opacity(0.62))
                            .frame(width: max(Double(row.directSets) * scale, 0))
                        Rectangle()
                            .fill(Color.primary.opacity(0.24))
                            .frame(width: max(row.weightedIndirect * scale, 0))
                    }
                    .clipShape(Capsule())

                    // Guideline marker at the lower end of the reference band.
                    Rectangle()
                        .fill(.green.opacity(0.55))
                        .frame(width: 1.5)
                        .offset(x: WeeklyVolume.guidelineRange.lowerBound * scale)
                }
            }
            .frame(height: 10)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(row.muscle.displayName)
        .accessibilityValue(accessibilityValue)
    }

    private var accessibilityValue: String {
        var text = "\(row.totalText) Sätze pro Woche"
        if row.breakdownText != nil {
            text += ", davon \(row.directSets) direkt und \(WeeklyVolume.format(row.weightedIndirect)) indirekt"
        }
        if isBelowGuideline {
            text += ", unter dem Richtwert"
        }
        return text
    }
}
