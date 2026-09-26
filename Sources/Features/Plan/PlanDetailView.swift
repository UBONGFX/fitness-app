import SwiftData
import SwiftUI

/// One plan's week: header, volume, and a card per day.
///
/// Takes the plan as a parameter rather than reading the active one, because a
/// plan has to be **buildable before it is switched to** — otherwise setting up
/// full body would mean following an empty week while you fill it in.
struct PlanDetailView: View {
    @Environment(\.modelContext) private var context
    @Environment(SaveReporter.self) private var saveReporter
    @Query private var plans: [WorkoutPlan]
    @Query(sort: \WorkoutSession.startedAt, order: .reverse)
    private var sessions: [WorkoutSession]

    let plan: WorkoutPlan
    /// The comparison against what was actually trained only makes sense for the
    /// plan being followed; for any other it would compare this week's sessions
    /// against a week that was never in effect.
    var showsThisWeek = true

    var body: some View {
        ScrollView {
            GlassEffectContainer(spacing: Theme.Spacing.regular) {
                VStack(spacing: Theme.Spacing.regular) {
                    headerCard
                    activateButton

                    if !plan.trainingDays.isEmpty {
                        VolumeCard(rows: WeeklyVolume.rows(for: plan), comparison: comparison)
                    } else {
                        emptyPlanCard
                    }

                    // Every day is editable, rest days included: without that a
                    // day switched to "Ruhetag" could never be switched back.
                    ForEach(plan.sortedDays) { day in
                        NavigationLink {
                            PlanDayEditorView(day: day)
                        } label: {
                            DayCard(day: day, isEditable: true)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("editDay-\(day.name)")
                    }
                }
                .padding(Theme.Spacing.regular)
            }
        }
        .scrollEdgeEffectStyle(.soft, for: .top)
        .clearsBottomAccessory()
    }

    private var headerCard: some View {
        NavigationLink {
            PlanHeaderEditorView(plan: plan)
        } label: {
            GlassCard(tint: .orange) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(plan.name)
                            .font(.title2.weight(.bold))
                        if !plan.focus.isEmpty {
                            Text(plan.focus)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Text(plan.summaryText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.top, 2)
                        if plans.count > 1, plan.isActive {
                            Label("Aktiver Plan von \(plans.count)", systemImage: "checkmark.circle.fill")
                                .font(.caption2)
                                .foregroundStyle(.green)
                                .accessibilityIdentifier("activePlanBadge")
                        }
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
        .accessibilityIdentifier("editPlan")
    }

    /// Outside the header card, not inside it: the header is a `NavigationLink`,
    /// and a button nested in a link's label is never reachable — it renders, and
    /// nothing happens when you tap it.
    ///
    /// Only shown when there is more than one plan: with a single one there is
    /// nothing to switch between, and "aktiv" carries no information.
    @ViewBuilder
    private var activateButton: some View {
        if plans.count > 1, !plan.isActive {
            Button {
                activate()
            } label: {
                Label("Diesen Plan aktivieren", systemImage: "checkmark.circle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
            .accessibilityIdentifier("activateThisPlan")
        }
    }

    /// A plan that is all rest days is the normal starting state, not a fault —
    /// so it says what to do next instead of showing an empty volume card.
    private var emptyPlanCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: Theme.Spacing.tight) {
                SectionHeader(title: "Noch keine Trainingstage", subtitle: "Sieben Ruhetage")
                Text("Tippe unten auf einen Tag, gib ihm einen Namen und stelle die Art "
                     + "auf Push, Pull oder Beine. Danach kannst du Übungen ergänzen.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("emptyPlanHint")
            }
        }
    }

    /// Empty until something was logged this week — an all-zero comparison would
    /// just be noise on a fresh install.
    private var comparison: [VolumeComparison] {
        guard showsThisWeek else { return [] }
        let week = ActualVolume.week(containing: Date())
        let done = ActualVolume.sessions(in: week, from: sessions)
        guard !done.isEmpty else { return [] }
        return ActualVolume.comparison(
            plan: WeeklyVolume.rows(for: plan),
            actual: ActualVolume.rows(from: done)
        )
    }

    private func activate() {
        PlanLibrary.activate(plan, in: plans)
        saveReporter.perform("Plan aktivieren") { try context.save() }
    }
}
