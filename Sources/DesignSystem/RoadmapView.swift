import SwiftUI

/// Placeholder for a pillar that is scheduled but not built yet.
///
/// It states what is coming rather than showing invented data — an empty screen
/// that lies about having content is worse than one that is honest.
struct RoadmapView: View {
    let title: String
    let subtitle: String
    let icon: String
    let tint: Color
    let steps: [String]

    var body: some View {
        NavigationStack {
            ScrollView {
                GlassEffectContainer(spacing: Theme.Spacing.regular) {
                    VStack(spacing: Theme.Spacing.regular) {
                        GlassCard(tint: tint) {
                            VStack(alignment: .leading, spacing: Theme.Spacing.tight) {
                                Image(systemName: icon)
                                    .font(.largeTitle)
                                    .foregroundStyle(tint)
                                Text(subtitle)
                                    .font(.headline)
                                Text("Noch nicht gebaut — steht als Nächstes im Backlog.")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        GlassCard {
                            VStack(alignment: .leading, spacing: Theme.Spacing.regular) {
                                SectionHeader(title: "Geplant")
                                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                                    HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.regular) {
                                        Text("\(index + 1)")
                                            .font(.caption.monospacedDigit().weight(.bold))
                                            .foregroundStyle(tint)
                                            .frame(minWidth: 18, alignment: .trailing)
                                        Text(step)
                                            .font(.subheadline)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                }
                            }
                        }
                    }
                    .padding(Theme.Spacing.regular)
                }
            }
            .scrollEdgeEffectStyle(.soft, for: .top)
            .clearsBottomAccessory()
            .background(AppBackground())
            .navigationTitle(title)
        }
    }
}
