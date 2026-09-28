import Charts
import SwiftData
import SwiftUI

/// A personal training record: goals, one exercise, and performed volume.
struct HomeView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
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
        // A primary goal stays in focus even before its first measurement.
        trends.first
    }
    private var featuredGoal: MetricGoal? {
        guard let featuredTrend else { return nil }
        return goals.first { $0.metric == featuredTrend.metric }
    }
    private var goalPoints: [MetricPoint] {
        guard let featuredTrend else { return [] }
        let all = MeasurementSeries.points(for: featuredTrend.metric, from: measurements)
        let current = all.filter { interval.contains($0.date) && $0.date <= Date() }
        guard !current.isEmpty else { return [] }
        return (all.last { $0.date < interval.start }.map { [$0] } ?? []) + current
    }
    private var hasGoalReadingInPeriod: Bool {
        guard let featuredTrend else { return false }
        return hasReadingInPeriod(for: featuredTrend.metric)
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
        let current = all.filter { interval.contains($0.date) && $0.date <= Date() }
        return (all.last { $0.date < interval.start }.map { [$0] } ?? []) + current
    }
    private func hasReadingInPeriod(for metric: BodyMetric) -> Bool {
        measurements.contains { interval.contains($0.date) && $0.date <= Date() && $0[metric] != nil }
    }
    private var performedSessions: [WorkoutSession] {
        sessions.filter { interval.contains($0.startedAt) && $0.completedSets > 0 }
    }
    private var activeSession: WorkoutSession? { sessions.first(where: \.isActive) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.regular) {
                    HStack {
                        Text(Date.now, format: .dateTime.day().month(.wide).year())
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button { showingSettings = true } label: {
                            AccountAvatar(initials: UserProfile.initials)
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
                        }
                        .accessibilityLabel("Konto und Einstellungen")
                        .accessibilityIdentifier("openSettings")
                    }
                    FieldGuidePageTitle(title: "Fortschritt")
                    if let activeSession { resumeRecord(activeSession) }
                    periodPicker
                    goalRecord
                    exerciseRecord
                    trainingRecord
                    if trends.count > 1 { otherGoalsRecord }
                }
                .padding(.horizontal, Theme.Spacing.regular)
                .padding(.top, Theme.Spacing.regular)
                .padding(.bottom, 100)
                .frame(maxWidth: 640)
                .frame(maxWidth: .infinity)
            }
            .background(AppBackground())
            .scrollEdgeEffectStyle(.soft, for: .top)
            .clearsBottomAccessory()
            .toolbar(.hidden, for: .navigationBar)
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

    private var periodRangeText: String {
        switch period {
        case .week:
            let lastDay = Calendar.current.date(byAdding: .day, value: -1, to: interval.end) ?? interval.end
            return "\(interval.start.formatted(.dateTime.day().month(.abbreviated))) – \(lastDay.formatted(.dateTime.day().month(.abbreviated)))"
        case .month: return interval.start.formatted(.dateTime.month(.wide).year())
        case .quarter:
            let lastDay = Calendar.current.date(byAdding: .day, value: -1, to: interval.end) ?? interval.end
            return "\(interval.start.formatted(.dateTime.month(.abbreviated))) – \(lastDay.formatted(.dateTime.month(.abbreviated).year()))"
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
                    VStack(alignment: .leading, spacing: 2) {
                        Text(featuredTrend?.metric.displayName ?? "Meine Ziele")
                            .font(.system(.title2, design: .serif).weight(.semibold))
                        Text(featuredGoal?.priority == .primary
                             ? "Primäres Ziel · \(periodRangeText)"
                             : periodRangeText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                if let featuredTrend, let featuredGoal {
                    goalMetrics(featuredTrend)
                    goalChart(goal: featuredGoal, points: goalPoints)
                    if hasGoalReadingInPeriod && featuredTrend.deltaText != nil {
                        Text("Seit \(goalPoints.first?.date.formatted(.dateTime.day().month(.abbreviated)) ?? "—"): \(goalChangeText(featuredTrend))")
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
        MeasurementSeries.points(for: metric, from: measurements)
            .last { $0.date <= Date() }?.date
            .formatted(.dateTime.day().month(.abbreviated).year()) ?? "—"
    }

    @ViewBuilder private func goalMetrics(_ trend: GoalTrend) -> some View {
        let change = hasGoalReadingInPeriod ? (trend.deltaText ?? "—") : "—"
        let changeIsAccent = hasGoalReadingInPeriod && trend.direction == .closer
        if dynamicTypeSize.isAccessibilitySize {
            VStack(spacing: Theme.Spacing.tight) {
                goalMetricRow("Aktuell", trend.currentText ?? "—")
                goalMetricRow(trend.hasTarget ? "Zielbereich" : "Ziel", trend.targetText)
                goalMetricRow("Veränderung", change, isAccent: changeIsAccent)
            }
        } else {
            HStack(alignment: .top, spacing: Theme.Spacing.tight) {
                metric("Aktuell", trend.currentText ?? "—")
                metric(trend.hasTarget ? "Zielbereich" : "Ziel", trend.targetText)
                metric("Veränderung", change, isAccent: changeIsAccent)
            }
        }
    }

    private func goalMetricRow(_ label: String, _ value: String, isAccent: Bool = false) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.tight) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer(minLength: 8)
            Text(value)
                .font(.headline.monospacedDigit())
                .foregroundStyle(isAccent ? Color.accentColor : Color.primary)
                .multilineTextAlignment(.trailing)
        }
        .accessibilityElement(children: .combine)
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
                VStack(alignment: .leading, spacing: 4) {
                    Chart {
                        if goal.hasTarget {
                            RuleMark(y: .value("Ziel unten", min(goal.lowerBound, goal.upperBound)))
                                .foregroundStyle(.secondary.opacity(0.5))
                                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                            if !goal.isSingleValue {
                                RuleMark(y: .value("Ziel oben", max(goal.lowerBound, goal.upperBound)))
                                    .foregroundStyle(.secondary.opacity(0.5))
                                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                            }
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
                        covering: goal.hasTarget ? [goal.lowerBound, goal.upperBound] : []
                    ) ?? 0...1)
                    .chartXScale(domain: goalXDomain(points))
                    .chartXAxis {
                        if !dynamicTypeSize.isAccessibilitySize {
                            AxisMarks(values: points.count > 6
                                      ? [points.first, points.last].compactMap { $0?.date }
                                      : points.map(\.date)) { value in
                                AxisValueLabel {
                                    if let date = value.as(Date.self) {
                                        Text(date, format: .dateTime.day(.twoDigits).month(.twoDigits))
                                            .font(.caption2)
                                    }
                                }
                            }
                        }
                    }
                    .frame(height: 132)
                    if dynamicTypeSize.isAccessibilitySize,
                       let first = points.first?.date, let last = points.last?.date {
                        HStack {
                            Text(first, format: .dateTime.day().month(.abbreviated))
                            Spacer()
                            Text(last, format: .dateTime.day().month(.abbreviated))
                        }
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    }
                }
                .accessibilityLabel("\(goal.metric.displayName) über die Zeit")
            }
        }
    }

    private func goalXDomain(_ points: [MetricPoint]) -> ClosedRange<Date> {
        guard let first = points.first?.date, let last = points.last?.date else {
            return Date.distantPast...Date.distantFuture
        }
        let span = max(last.timeIntervalSince(first), 86_400)
        let leading = max(span * 0.08, 86_400 * 3)
        let trailing = max(span * 0.18, 86_400 * 3)
        return first.addingTimeInterval(-leading)...last.addingTimeInterval(trailing)
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
                                    .font(.system(.title2, design: .serif).weight(.semibold))
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
                    VStack(alignment: .leading, spacing: Theme.Spacing.regular) {
                        Text("Übungsfortschritt")
                            .font(.system(.title2, design: .serif).weight(.semibold))
                        Text("Noch keine Sätze")
                            .font(.system(.title3, design: .serif).weight(.semibold))
                        Text("Nach deinem ersten geloggten Satz erscheint hier der Verlauf einer Übung.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Button { selectedTab = .training } label: {
                            Text("Zum Training")
                                .frame(maxWidth: .infinity)
                        }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
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
                            .font(.system(.title2, design: .serif).weight(.semibold))
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
                SectionHeader(title: "Weitere Ziele", subtitle: "Stand und Veränderung")
                ForEach(Array(trends.filter { $0.id != featuredTrend?.id }.prefix(3))) { trend in
                    VStack(alignment: .leading, spacing: Theme.Spacing.tight) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(trend.metric.displayName)
                                .font(.subheadline.weight(.semibold))
                            Spacer(minLength: Theme.Spacing.tight)
                            Text(trend.currentText ?? "—")
                                .font(.subheadline.weight(.semibold).monospacedDigit())
                            Text(trend.hasTarget ? "→ \(trend.targetText)" : "Beobachten")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        if let evaluation = trend.evaluation {
                            HStack(spacing: Theme.Spacing.tight) {
                                ProgressView(value: evaluation.progress)
                                    .tint(.accentColor)
                                Text(evaluation.progress, format: .percent.precision(.fractionLength(0)))
                                    .font(.caption2.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                        }
                        if hasReadingInPeriod(for: trend.metric), trend.deltaText != nil {
                            Text(goalChangeText(trend))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Divider()
                }
                Button("Alle \(trends.count) Ziele ansehen") { selectedTab = .body }
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
                .font(.title3.weight(.semibold).monospacedDigit())
                .foregroundStyle(isAccent ? Color.accentColor : Color.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}
