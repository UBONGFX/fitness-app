import Foundation

/// Keeps time axes readable when a history contains many nearby entries.
///
/// A chart still plots every record. The axis only names the first and last
/// visible day, which anchors the time span without turning the labels into
/// overlapping text.
nonisolated enum ChartDateAxis {
    static func endpoints(for dates: [Date], calendar: Calendar = .current) -> [Date] {
        guard let first = dates.min(), let last = dates.max() else { return [] }
        return calendar.isDate(first, inSameDayAs: last) ? [first] : [first, last]
    }
}
