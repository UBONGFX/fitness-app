import SwiftUI

/// The week selector that sits above the page, not inside a card.
///
/// It steers the whole screen rather than one card, so it must not look like it
/// belongs to any single one of them.
struct WeekSwitcher: View {
    let week: DateInterval
    var onPrevious: () -> Void
    var onNext: () -> Void
    var onToday: () -> Void

    var body: some View {
        HStack(spacing: Theme.Spacing.tight) {
            Button(action: onPrevious) {
                Image(systemName: "chevron.left")
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.glass)
            .accessibilityLabel("Vorherige Woche")
            .accessibilityIdentifier("previousWeek")

            VStack(spacing: 1) {
                Text(WeekOverview.title(for: week))
                    .font(.headline)
                    .accessibilityIdentifier("weekTitle")
                if !WeekOverview.isCurrent(week) {
                    Button("Zu dieser Woche", action: onToday)
                        .font(.caption)
                        .accessibilityIdentifier("thisWeek")
                }
            }
            .frame(maxWidth: .infinity)

            Button(action: onNext) {
                Image(systemName: "chevron.right")
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.glass)
            .accessibilityLabel("Nächste Woche")
            .accessibilityIdentifier("nextWeek")
        }
    }
}

/// The seven days of one week: what the plan asked for, and what happened.
///
/// Rows are tappable so a day can be opened — to look at what was logged, or to
/// correct it afterwards.
struct WeekStripCard: View {
    let rows: [WeekDayRow]
    var onOpen: (WeekDayRow) -> Void

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: Theme.Spacing.regular) {
                ForEach(rows) { row in
                    Button {
                        onOpen(row)
                    } label: {
                        WeekDayRowView(row: row)
                    }
                    .buttonStyle(.plain)
                    .disabled(!isOpenable(row))
                    .accessibilityIdentifier("weekDay-\(row.weekday)")
                }
                Text(WeekOverview.summary(rows))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("weekSummary")
            }
        }
    }

    /// Days with something to show, plus past training days that can still be
    /// filled in. A future day has nothing to open and must not look tappable.
    private func isOpenable(_ row: WeekDayRow) -> Bool {
        if !row.sessions.isEmpty { return true }
        return row.status == .missed || row.status == .today
    }
}

/// One day of the week strip.
struct WeekDayRowView: View {
    /// Fixed widths around text must grow with the text, or "Mo" wraps to "M"
    /// over "o" at accessibility sizes.
    @ScaledMetric(relativeTo: .caption) private var labelWidth: CGFloat = 26

    let row: WeekDayRow

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.tight) {
            Text(shortLabel)
                .font(.caption.weight(.semibold))
                .frame(width: labelWidth, alignment: .leading)
                .foregroundStyle(isToday ? Color.accentColor : .secondary)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.subheadline.weight(isToday ? .semibold : .regular))
                if let detail {
                    Text(detail)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: Theme.Spacing.tight)

            Text(statusText)
                .font(.caption.monospacedDigit())
                .foregroundStyle(statusTint)
        }
        .padding(.vertical, 3)
        // A Spacer is not hit-testable; without this only the glyphs would open
        // the day.
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(weekdayName), \(title)")
        .accessibilityValue(spokenStatus)
    }

    private var isToday: Bool { GoalPeriod.calendar.isDateInToday(row.date) }

    private var shortLabel: String {
        ["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"][max(0, min(row.weekday - 1, 6))]
    }

    private var weekdayName: String {
        ["Montag", "Dienstag", "Mittwoch", "Donnerstag", "Freitag", "Samstag", "Sonntag"][
            max(0, min(row.weekday - 1, 6))
        ]
    }

    /// The plan's name, unless something else was actually trained — in which case
    /// the name of what happened is the honest headline.
    private var title: String {
        if row.isSwapped, let performed = row.performedName { return performed }
        return row.planDay?.name ?? row.performedName ?? "Kein Plantag"
    }

    private var detail: String? {
        if row.isSwapped, let planned = row.planDay?.name {
            return "statt \(planned) · \(row.plannedSets) Sätze geplant"
        }
        guard row.plannedSets > 0 else { return nil }
        return "\(row.plannedSets) Sätze geplant"
    }

    private var statusText: String {
        switch row.status {
        case .done: "✓ \(row.completedSets)"
        case .rest: "—"
        case .missed: "ausgelassen"
        case .today: "heute"
        case .upcoming: "offen"
        }
    }

    private var statusTint: Color {
        switch row.status {
        case .done: .green
        case .missed: .orange
        case .today: .accentColor
        case .rest, .upcoming: .secondary
        }
    }

    private var spokenStatus: String {
        switch row.status {
        case .done: "trainiert, \(row.completedSets) Sätze"
        case .rest: "Ruhetag"
        case .missed: "ausgelassen"
        case .today: "heute, noch nicht trainiert"
        case .upcoming: "steht noch an"
        }
    }
}
