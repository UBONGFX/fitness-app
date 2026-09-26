import SwiftData
import SwiftUI

/// Recent finished sessions, shown on the training start screen.
struct HistoryCard: View {
    let sessions: [WorkoutSession]

    private var recent: [WorkoutSession] {
        Array(SessionHistory.finished(sessions).prefix(5))
    }

    var body: some View {
        if !recent.isEmpty {
            SolidCard {
                VStack(alignment: .leading, spacing: Theme.Spacing.regular) {
                    HStack(alignment: .firstTextBaseline) {
                        SectionHeader(
                            title: "Letzte Einheiten",
                            subtitle: "\(SessionHistory.finished(sessions).count) Einheiten"
                        )
                        NavigationLink("Alle") {
                            AllSessionsView(sessions: sessions)
                        }
                        .font(.caption)
                        .accessibilityIdentifier("allSessions")
                    }
                    ForEach(recent) { session in
                        NavigationLink {
                            SessionDetailView(session: session)
                        } label: {
                            SessionRow(session: session)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("session-\(session.dayName)")
                    }
                }
            }
        }
    }
}

private struct SessionRow: View {
    let session: WorkoutSession

    var body: some View {
        HStack(spacing: Theme.Spacing.regular) {
            Circle()
                .fill(Color.accentColor)
                .frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 1) {
                Text(session.dayName)
                    .font(.subheadline)
                Text(session.startedAt, format: .dateTime.day().month(.abbreviated).year())
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: Theme.Spacing.tight)
            Text("\(session.completedSets) Sätze")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

struct AllSessionsView: View {
    let sessions: [WorkoutSession]

    private var finished: [WorkoutSession] { SessionHistory.finished(sessions) }

    var body: some View {
        ScrollView {
            GlassEffectContainer(spacing: Theme.Spacing.regular) {
                VStack(spacing: Theme.Spacing.regular) {
                    GlassCard {
                        HStack(spacing: Theme.Spacing.section) {
                            stat("Einheiten", "\(finished.count)")
                            stat("Sätze", "\(finished.reduce(0) { $0 + $1.completedSets })")
                            stat("Last", "\(Int(SessionHistory.totalLoad(finished))) kg")
                            Spacer()
                        }
                    }
                    ForEach(finished) { session in
                        NavigationLink {
                            SessionDetailView(session: session)
                        } label: {
                            GlassCard { SessionRow(session: session) }
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("allSession-\(session.dayName)")
                    }
                }
                .padding(Theme.Spacing.regular)
            }
        }
        .scrollEdgeEffectStyle(.soft, for: .top)
        .clearsBottomAccessory()
        .background(AppBackground())
        .navigationTitle("Alle Einheiten")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption2).foregroundStyle(.secondary)
            Text(value).font(.title3.weight(.semibold).monospacedDigit())
        }
        .accessibilityElement(children: .combine)
    }
}

/// What was actually done in one past session.
struct SessionDetailView: View {
    @ScaledMetric(relativeTo: .caption) private var indexWidth: CGFloat = 22

    @Environment(\.modelContext) private var context
    @Query(sort: \WorkoutSession.startedAt, order: .reverse)
    private var allSessions: [WorkoutSession]
    let session: WorkoutSession

    /// Exercises that were only opened but never performed are left out — they
    /// say nothing about the session.
    private var performed: [LoggedExercise] {
        session.sortedExercises.filter { !$0.sortedSets.isEmpty }
    }

    var body: some View {
        ScrollView {
            GlassEffectContainer(spacing: Theme.Spacing.regular) {
                VStack(spacing: Theme.Spacing.regular) {
                    GlassCard(tint: session.category.color) {
                        VStack(alignment: .leading, spacing: Theme.Spacing.tight) {
                            Text(session.startedAt, format: .dateTime.weekday(.wide).day().month(.wide).year())
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                            HStack(spacing: Theme.Spacing.tight) {
                                stat("Sätze", "\(session.completedSets)")
                                stat("Dauer", session.durationText)
                                stat("Last", "\(Int(session.totalLoad)) kg")
                            }
                        }
                    }

                    ForEach(performed) { entry in
                        NavigationLink {
                            ExerciseProgressView(
                                exerciseName: entry.name,
                                exerciseID: entry.exercise?.id,
                                sessions: allSessions
                            )
                        } label: {
                            GlassCard {
                                VStack(alignment: .leading, spacing: Theme.Spacing.tight) {
                                    HStack {
                                        Text(entry.name)
                                            .font(.headline)
                                        Spacer(minLength: Theme.Spacing.tight)
                                        Image(systemName: "chevron.right")
                                            .font(.caption2)
                                            .foregroundStyle(.tertiary)
                                    }
                                    ForEach(Array(entry.sortedSets.enumerated()), id: \.element.id) { index, set in
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
                                    }
                                }
                                .contentShape(Rectangle())
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("detail-\(entry.name)")
                    }
                }
                .padding(Theme.Spacing.regular)
            }
        }
        .scrollEdgeEffectStyle(.soft, for: .top)
        .clearsBottomAccessory()
        .background(AppBackground())
        .navigationTitle(session.dayName)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption2).foregroundStyle(.secondary)
            Text(value).font(.title3.weight(.semibold).monospacedDigit())
        }
        .accessibilityElement(children: .combine)
    }
}
