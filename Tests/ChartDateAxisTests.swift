import Foundation
import Testing
@testable import FitnessApp

struct ChartDateAxisTests {
    @Test func namesOnlyTheEndsOfAMultiDayHistory() {
        let calendar = Calendar(identifier: .gregorian)
        let dates = [
            Date(timeIntervalSince1970: 1_700_000_000),
            Date(timeIntervalSince1970: 1_700_086_400),
            Date(timeIntervalSince1970: 1_700_172_800)
        ]

        #expect(ChartDateAxis.endpoints(for: dates, calendar: calendar) == [dates[0], dates[2]])
    }

    @Test func namesOneDayOnlyOnce() {
        let calendar = Calendar(identifier: .gregorian)
        let day = Date(timeIntervalSince1970: 1_700_000_000)
        let laterThatDay = day.addingTimeInterval(60 * 60)

        #expect(ChartDateAxis.endpoints(for: [day, laterThatDay], calendar: calendar) == [day])
    }
}
