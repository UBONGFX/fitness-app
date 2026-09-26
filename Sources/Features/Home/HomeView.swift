import Charts
import SwiftData
import SwiftUI

/// A personal training record: goals, one exercise, and performed volume.
struct HomeView: View {
    @Query(sort: \MetricGoal.metricRaw) private var goals: [MetricGoal]
    @Query(sort: \BodyMeasurement.date) private var measurements: [BodyMeasurement]
    @Query(sort: \WorkoutSession.startedAt, order: .reverse) private var sessions: [WorkoutSession]

    @State private var period = GoalPeriod.month
    @State private var showingSettings = false

    @Binding var selectedTab: AppTab
    @Binding var appearance: AppAppearance

    private var interval: DateInterval { period.interval(containing: Date()) }
    private var trends: [GoalTrend] {
        GoalTrends.trends(goals: goals, measurements: measurements, period: period)
    }
    private var featuredTrend: GoalTrend? {
        trends.first { $0.current != nil } ?? trends.first
    }
    private var featuredGoal: MetricGoal? {
        guard let featuredTrend else { return nil }
        return goals.first { $0.metric == featuredTrend.metric }
    }
    private var goalPoints: [MetricPoint] {
        guard let featuredTrend else { return [] }
        let all = MeasurementSeries.points(for: featuredTrend.metric, from: measurements)
        let current = all.filter { $0.date >= interval.start }
        guard !current.isEmpty else { return [] }
        return (all.last { $0.date < interval.start }.map { [$0] } ?? []) + current
    }
    private var hasGoalReadingInPeriod: Bool {
        guard let featuredTrend else { return false }
        return measurements.contains {
            interval.contains($0.date) && $0[featuredTrend.metric] != nil
        }
    }
    private var featuredExercise: Exercise? {
        SessionHistory.finished(sessions)
            .flatMap(\.sortedExercises)
            .first { !$0.sortedSets.isEmpty && $0.exercise != nil }?
            .exercise
    }
    private var exerciseEntries: [ExerciseHistoryEntry] {
        guard let featuredExercise else { return [] }
        return SessionHistory.entries(for: featuredExercise.id, in: sessions)
    }
    private var exercisePoints: [ExercisePoint] {
        let all = ExerciseProgress.points(from: exerciseEntries)
        let current = all.filter { $0.date >= interval.start }
        return (all.last { $0.date < interval.start }.map { [$0] } ?? []) + current
    }
    private var performedSessions: [WorkoutSession] {
        sessions.filter { interval.contains($0.startedAt) && $0.completedSets > 0 }
    }
    private var activeSession: WorkoutSession? { sessions.first(where: \.isActive) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.regular) {
                    if let activeSession { resumeRecord(activeSession) }
                    periodPicker
                    HStack {
                        Text(periodLabel)
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Text(interval.start, format: .dateTime.day().month(.abbreviated))
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, Theme.Spacing.tight)
                    goalRecord
                    exerciseRecord
                    trainingRecord
                    if trends.count > 1 { otherGoalsRecord }
                }
                .padding(.horizontal, Theme.Spacing.regular)
                .padding(.top, Theme.Spacing.tight)
                .padding(.bottom, 100)
            }
            .background(AppBackground())
            .scrollEdgeEffectStyle(.soft, for: .top)
            .clearsBottomAccessory()
            .navigationTitle("Fortschritt")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showingSettings = true } label: {
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

    private var periodPicker: some View {
        Picker("Zeitraum", selection: $period) {
            ForEach(GoalPeriod.allCases) { option in
                Text(option.displayName).tag(option)
            }
        }
        .pickerStyle(.segmented)
        .accessibilityIdentifier("goalPeriod")
    }

    private var periodLabel: String {
        switch period {
        case .week: "DIESE WOCHE"
        case .month: "DIESER MONAT"
        case .quarter: "DIESES QUARTAL"
        }
    }

    private func resumeRecord(_ session: WorkoutSession) -> some View {
        Button { selectedTab = .training } label: {
            GlassCard {
                HStack(spacing: Theme.Spacing.regular) {
                    Image(systemName: "play.fill")
                        .font(.headline)
                        .foregroundStyle(.tint)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Training fortsetzen")
                            .font(.headline)
                        Text("\(session.dayName) · \(session.completedSets) Sätze")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("resumeToday")
    }

    private var goalRecord: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: Theme.Spacing.regular) {
                HStack {
                    Text(featuredTrend?.metric.displayName ?? "Meine Ziele")
                        .font(.title3.weight(.bold))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                if let featuredTrend, let featuredGoal {
                    HStack(alignment: .top, spacing: Theme.Spacing.tight) {
                        metric("Aktuell", featuredTrend.currentText ?? "—", isAccent: true)
                        metric("Zielbereich", featuredTrend.targetText)
                        metric("Veränderung", hasGoalReadingInPeriod ? (featuredTrend.deltaText ?? "—") : "—",
                               isAccent: hasGoalReadingInPeriod && featuredTrend.direction == .closer)
                    }
                    goalChart(goal: featuredGoal, points: goalPoints)
                    if hasGoalReadingInPeriod && featuredTrend.deltaText != nil {
                        Text(goalChangeText(featuredTrend))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else if !hasGoalReadingInPeriod {
                        Text("Keine Messung in diesem Zeitraum · letzter Wert vom \(latestGoalDate(featuredTrend.metric))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text("Lege unter Körper ein Ziel fest. Hier siehst du dann deine Veränderung im gewählten Zeitraum.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Button("Ziele setzen") { selectedTab = .body }
                        .buttonStyle(.borderedProminent)
                }
            }
            .contentShape(Rectangle())
        }
        .onTapGesture { if featuredTrend != nil { selectedTab = .body } }
        .accessibilityIdentifier("openBody")
    }

    private func latestGoalDate(_ metric: BodyMetric) -> String {
        MeasurementSeries.points(for: metric, from: measurements).last?.date
            .formatted(.dateTime.day().month(.abbreviated).year()) ?? "—"
    }

    private func goalChart(goal: MetricGoal, points: [MetricPoint]) -> some View {
        Group {
            if points.count < 2 {
                Text(points.isEmpty
                     ? "Noch keine Messung für dieses Ziel"
                     : "Noch kein Verlauf in diesem Zeitraum")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 36, alignment: .leading)
            } else {
                Chart {
                    RuleMark(y: .value("Ziel unten", min(goal.lowerBound, goal.upperBound)))
                        .foregroundStyle(.secondary.opacity(0.5))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    if !goal.isSingleValue {
                        RuleMark(y: .value("Ziel oben", max(goal.lowerBound, goal.upperBound)))
                            .foregroundStyle(.secondary.opacity(0.5))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    }
                    ForEach(points) { point in
                        LineMark(x: .value("Datum", point.date), y: .value("Wert", point.value))
                            .foregroundStyle(Color.accentColor)
                            .lineStyle(StrokeStyle(lineWidth: 2))
                        PointMark(x: .value("Datum", point.date), y: .value("Wert", point.value))
                            .foregroundStyle(Color.accentColor)
                    }
                }
                .chartYScale(domain: MeasurementSeries.range(
                    for: points,
                    covering: [goal.lowerBound, goal.upperBound]
                ) ?? 0...1)
                .frame(height: 132)
                .accessibilityLabel("\(goal.metric.displayName) über die Zeit")
            }
        }
    }

    private func goalChangeText(_ trend: GoalTrend) -> String {
        guard let delta = trend.deltaText else { return "Noch kein Vergleichswert in diesem Zeitraum" }
        switch trend.direction {
        case .closer: return "\(delta) · näher am Ziel"
        case .further: return "\(delta) · weiter vom Ziel entfernt"
        case .unchanged: return "\(delta) · unverändert"
        case .unknown: return delta
        }
    }

    private var exerciseRecord: some View {
        Group {
            if let featuredExercise {
                NavigationLink {
                    ExerciseProgressView(
                        exerciseName: featuredExercise.name,
                        exerciseID: featuredExercise.id,
                        sessions: sessions
                    )
                } label: {
                    GlassCard {
                        VStack(alignment: .leading, spacing: Theme.Spacing.regular) {
                            HStack {
                                Text(featuredExercise.name)
                                    .font(.title3.weight(.bold))
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.tertiary)
                            }
                            HStack(alignment: .top) {
                                metric("Letzter Top-Satz", exerciseEntries.first?.setsAtWorkingWeight.first?.summary ?? "—", isAccent: true)
                                Spacer(minLength: 8)
                                metric("Seit dem ersten Eintrag", exerciseChangeText)
                            }
                            if exercisePoints.count > 1 {
                                exerciseChart
                            } else {
                                Text("Mit der nächsten Einheit entsteht ein Verlauf.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .buttonStyle(.plain)
            } else {
                GlassCard {
                    VStack(alignment: .leading, spacing: Theme.Spacing.tight) {
                        Text("Übungsfortschritt")
                            .font(.title3.weight(.bold))
                        Text("Logge Sätze, um Arbeitsgewicht und Bestwerte über die Zeit zu sehen.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Button("Workout starten") { selectedTab = .training }
                            .buttonStyle(.borderedProminent)
                            .accessibilityIdentifier("openTraining")
                    }
                }
            }
        }
    }

    private var exerciseChangeText: String {
        guard let delta = ExerciseProgress.weightChange(ExerciseProgress.points(from: exerciseEntries)) else { return "—" }
        return ExerciseProgress.signed(delta)
    }

    private var exerciseChart: some View {
        Chart(exercisePoints) { point in
            LineMark(x: .value("Datum", point.date), y: .value("Gewicht", point.workingWeight))
                .foregroundStyle(Color.accentColor)
                .lineStyle(StrokeStyle(lineWidth: 2))
            PointMark(x: .value("Datum", point.date), y: .value("Gewicht", point.workingWeight))
                .foregroundStyle(Color.accentColor)
        }
        .chartYScale(domain: ExerciseProgress.range(of: exercisePoints.map(\.workingWeight)) ?? 0...1)
        .frame(height: 132)
        .accessibilityLabel("Arbeitsgewicht über die Zeit")
    }

    private var trainingRecord: some View {
        Button { selectedTab = .training } label: {
            GlassCard {
                VStack(alignment: .leading, spacing: Theme.Spacing.regular) {
                    HStack {
                        Text("Training")
                            .font(.title3.weight(.bold))
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                    HStack(alignment: .top, spacing: Theme.Spacing.loose) {
                        metric("Einheiten", "\(performedSessions.count)")
                        Rectangle()
                            .fill(.quaternary)
                            .frame(width: 1, height: 54)
                        metric("Gesamtvolumen", "\(Int(performedSessions.reduce(0) { $0 + $1.totalLoad }).formatted()) kg")
                    }
                    Text(period.thisPeriodText.capitalized)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("openTraining")
    }

    private var otherGoalsRecord: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: Theme.Spacing.regular) {
                SectionHeader(title: "Weitere Ziele", subtitle: "Werte und Abstand zum Ziel")
                ForEach(trends.filter { $0.id != featuredTrend?.id }) { trend in
                    HStack {
                        Text(trend.metric.displayName)
                            .font(.subheadline)
                        Spacer()
                        Text(trend.currentText ?? "—")
                            .font(.subheadline.weight(.semibold).monospacedDigit())
                        Text("/ \(trend.targetText)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Divider()
                }
                Button("Alle Ziele ansehen") { selectedTab = .body }
                    .buttonStyle(.bordered)
            }
        }
    }

    private func metric(_ label: String, _ value: String, isAccent: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline.monospacedDigit())
                .foregroundStyle(isAccent ? Color.accentColor : Color.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}
