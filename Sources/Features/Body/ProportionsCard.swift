import SwiftUI

/// Current body ratios against their target and the classical ideal band.
struct ProportionsCard: View {
    let measurements: [BodyMeasurement]

    private struct Row: Identifiable {
        let id: String
        let proportion: BodyProportion
        let value: Double
        let date: Date
    }

    private var rows: [Row] {
        BodyProportion.allCases.compactMap { proportion in
            guard let latest = proportion.latestValue(from: measurements) else { return nil }
            return Row(
                id: proportion.rawValue,
                proportion: proportion,
                value: latest.value,
                date: latest.date
            )
        }
    }

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: Theme.Spacing.loose) {
                SectionHeader(
                    title: "Proportionen",
                    subtitle: rows.isEmpty
                        ? "Noch keine vollständige Messung"
                        : "Ist · Ziel · Ideal"
                )
                ForEach(rows) { row in
                    ProportionRow(proportion: row.proportion, value: row.value)
                }
            }
        }
    }
}

private struct ProportionRow: View {
    let proportion: BodyProportion
    let value: Double

    private var reachedIdeal: Bool { value >= proportion.ideal.lowerBound }
    private var reachedTarget: Bool { value >= proportion.target }

    private var tint: Color {
        if reachedIdeal { return .green }
        return reachedTarget ? .teal : .orange
    }

    /// Scale spanning from the target down-shifted a little to just past the
    /// ideal, so the marker has somewhere meaningful to sit in both directions.
    private var scale: ClosedRange<Double> {
        let high = max(proportion.ideal.upperBound, value)
        let low = min(proportion.target * 0.92, value)
        return low...max(high, low + 0.01)
    }

    private func position(_ point: Double, in width: CGFloat) -> CGFloat {
        let span = scale.upperBound - scale.lowerBound
        guard span > 0 else { return 0 }
        return width * CGFloat((point - scale.lowerBound) / span)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(proportion.displayName)
                        .font(.subheadline)
                    if let subtitle = proportion.subtitle {
                        Text(subtitle)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: Theme.Spacing.tight)
                Text(BodyProportion.format(value))
                    .font(.title3.weight(.semibold).monospacedDigit())
                    .foregroundStyle(tint)
            }

            GeometryReader { geometry in
                let width = geometry.size.width
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.quaternary)
                        .frame(height: 6)

                    // Ideal band
                    Capsule()
                        .fill(.green.opacity(0.35))
                        .frame(
                            width: max(
                                position(proportion.ideal.upperBound, in: width)
                                    - position(proportion.ideal.lowerBound, in: width),
                                3
                            ),
                            height: 6
                        )
                        .offset(x: position(proportion.ideal.lowerBound, in: width))

                    // Target tick
                    Rectangle()
                        .fill(.secondary)
                        .frame(width: 2, height: 12)
                        .offset(x: position(proportion.target, in: width) - 1)

                    // Current value
                    Circle()
                        .fill(tint)
                        .frame(width: 11, height: 11)
                        .offset(x: position(value, in: width) - 5.5)
                }
                .frame(height: 12)
            }
            .frame(height: 12)

            HStack {
                Text("Ziel \(BodyProportion.format(proportion.target))")
                Spacer()
                Text("Ideal \(proportion.idealText)")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(proportion.displayName), aktuell \(BodyProportion.format(value)), "
            + "Ziel \(BodyProportion.format(proportion.target)), Ideal \(proportion.idealText)"
        )
    }
}
