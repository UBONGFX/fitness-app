import SwiftData
import SwiftUI

/// The landing screen: progress and a shortcut to training.
///
/// Deliberately a summary and not a second place to enter data — each card links
/// into the tab that owns the thing it shows. The full week lives on the training
/// screen, where the session it leads to is started.
struct HomeView: View {
    @Query(sort: \MetricGoal.metricRaw) private var goals: [MetricGoal]
    @Query(sort: \BodyMeasurement.date) private var measurements: [BodyMeasurement]
    @Query(sort: \WorkoutSession.startedAt, order: .reverse) private var sessions: [WorkoutSession]

    @State private var period = GoalPeriod.month
    @State private var showingSettings = false

    @Binding var selectedTab: AppTab
    @Binding var appearance: AppAppearance

    private var trends: [GoalTrend] {
        GoalTrends.trends(goals: goals, measurements: measurements, period: period)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                GlassEffectContainer(spacing: Theme.Spacing.regular) {
                    VStack(spacing: Theme.Spacing.regular) {
                        goalCard
                        todayCard
                    }
                    .padding(Theme.Spacing.regular)
                }
            }
            .background(AppBackground())
            .scrollEdgeEffectStyle(.soft, for: .top)
            .clearsBottomAccessory()
            .navigationTitle("Übersicht")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingSettings = true
                    } label: {
                        AccountAvatar(initials: UserProfile.initials)
                    }
                    .accessibilityLabel("Konto und Einstellungen")
                    .accessibilityIdentifier("openSettings")
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView(appearance: $appearance)
            }
        }
    }

    // MARK: - Goals

    private var goalCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: Theme.Spacing.regular) {
                SectionHeader(title: "Meine Ziele", subtitle: "Veränderung \(period.thisPeriodText)")

                Picker("Zeitraum", selection: $period) {
                    ForEach(GoalPeriod.allCases) { one in
                        Text(one.displayName).tag(one)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("goalPeriod")

                if trends.isEmpty {
                    emptyGoals
                } else {
                    ForEach(trends) { trend in
                        GoalTrendRow(trend: trend)
                        if trend.id != trends.last?.id {
                            Divider().opacity(0.4)
                        }
                    }
                    Button("Alle Maße ansehen") { selectedTab = .body }
                        .buttonStyle(.glass)
                        .accessibilityIdentifier("openBody")
                }
            }
        }
    }

    private var emptyGoals: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.tight) {
            Text("Noch keine Ziele gesetzt.")
                .font(.subheadline)
            Text("Unter Körper legst du fest, wohin es gehen soll — hier siehst du dann, "
                 + "wie weit du \(period.thisPeriodText) gekommen bist.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Button("Ziele setzen") { selectedTab = .body }
                .buttonStyle(.glassProminent)
                .accessibilityIdentifier("openBody")
        }
    }

    // MARK: - Today

    private var todayCard: some View {
        GlassCard(tint: sessions.first(where: \.isActive)?.category.color) {
            VStack(alignment: .leading, spacing: Theme.Spacing.regular) {
                SectionHeader(title: "Heute", subtitle: Date().formatted(.dateTime.weekday(.wide).day().month(.wide)))
                if let active = sessions.first(where: \.isActive) {
                    Text(active.dayName)
                        .font(.title3.weight(.semibold))
                        .accessibilityIdentifier("todayName")
                    Text("\(active.completedSets) Sätze · \(active.durationText)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button("Training fortsetzen") { selectedTab = .training }
                        .buttonStyle(.glassProminent)
                        .accessibilityIdentifier("resumeToday")
                } else {
                    let today = sessions.filter {
                        !$0.isActive && GoalPeriod.calendar.isDateInToday($0.startedAt)
                    }
                    if today.isEmpty {
                        Text("Trainiere, wann du möchtest.")
                            .font(.subheadline)
                    } else {
                        Label("\(today.count) \(today.count == 1 ? "Workout" : "Workouts") heute abgeschlossen",
                              systemImage: "checkmark.circle.fill")
                            .font(.subheadline)
                            .foregroundStyle(.green)
                    }
                    Button("Workout starten") { selectedTab = .training }
                        .buttonStyle(.glassProminent)
                        .accessibilityIdentifier("openTraining")
                }
            }
        }
    }
}

/// One goal: where it stands, and which way it moved during the period.
private struct GoalTrendRow: View {
    let trend: GoalTrend

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(trend.metric.displayName)
                    .font(.subheadline.weight(.medium))
                Spacer(minLength: Theme.Spacing.tight)
                Text(trend.currentText ?? "—")
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                Text("Ziel \(trend.targetText)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let evaluation = trend.evaluation {
                ProgressView(value: evaluation.progress)
                    .tint(evaluation.isReached ? .green : .accentColor)
                    .accessibilityHidden(true)
            }

            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption2)
                Text(changeText)
                    .font(.caption)
            }
            .foregroundStyle(tint)
        }
        .padding(.vertical, 2)
        // Spoken as one sentence; the bar and the arrow carry no meaning alone.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(trend.metric.displayName)
        .accessibilityValue(spokenValue)
    }

    private var icon: String {
        switch trend.direction {
        case .closer: "arrow.down.right.circle.fill"
        case .further: "arrow.up.right.circle"
        case .unchanged: "equal.circle"
        case .unknown: "questionmark.circle"
        }
    }

    private var tint: Color {
        switch trend.direction {
        case .closer: .green
        case .further: .orange
        case .unchanged, .unknown: .secondary
        }
    }

    /// Says both numbers: what changed, and what that means for the goal. The raw
    /// delta alone cannot be read as good or bad without knowing which way the
    /// goal points, and "näher" alone hides how much actually moved.
    private var changeText: String {
        guard let deltaText = trend.deltaText else {
            return trend.current == nil ? "Noch nicht gemessen" : "Noch kein Vergleichswert"
        }
        if trend.evaluation?.isReached == true, trend.direction == .unchanged {
            return "\(deltaText) · im Zielkorridor"
        }
        switch trend.direction {
        case .closer: return "\(deltaText) · näher am Ziel"
        case .further: return "\(deltaText) · weiter weg"
        case .unchanged: return "\(deltaText) · unverändert"
        case .unknown: return deltaText
        }
    }

    private var spokenValue: String {
        var parts: [String] = []
        if let current = trend.currentText { parts.append(current) }
        parts.append("Ziel \(trend.targetText)")
        if let remaining = trend.evaluation?.remaining, remaining > 0 {
            parts.append("noch \(trend.metric.formatted(remaining))")
        } else if trend.evaluation?.isReached == true {
            parts.append("erreicht")
        }
        parts.append(changeText)
        return parts.joined(separator: ", ")
    }
}
