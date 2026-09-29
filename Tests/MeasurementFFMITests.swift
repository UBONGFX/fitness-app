import SwiftData
import Testing
@testable import FitnessApp

@MainActor
struct MeasurementFFMITests {
    @Test func savingDerivesFFMIUnlessItWasEnteredManually() {
        let calculated = HealthImport.resolvedFFMI(
            entered: nil, previous: nil, weight: 80, bodyFat: 15, heightMeters: 1.8
        )
        #expect(calculated == 21.0)

        let manual = HealthImport.resolvedFFMI(
            entered: 22.5, previous: nil, weight: 80, bodyFat: 15, heightMeters: 1.8
        )
        #expect(manual == 22.5)
    }

    @Test func editingRecalculatesDerivedFFMIButKeepsManualValues() {
        let previous = BodyMeasurement(weight: 80, bodyFat: 15, ffmi: 21.0)
        let recalculated = HealthImport.resolvedFFMI(
            entered: 21.0, previous: previous, weight: 82, bodyFat: 15, heightMeters: 1.8
        )
        #expect(recalculated == 21.5)

        previous.ffmi = 22.5
        let unchangedManual = HealthImport.resolvedFFMI(
            entered: 22.5, previous: previous, weight: 82, bodyFat: 15, heightMeters: 1.8
        )
        #expect(unchangedManual == 22.5)
    }

    @Test func olderPartialMeasurementsGainOnlyMissingDerivedFFMI() throws {
        let schema = Schema([BodyMeasurement.self])
        let store = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: store)
        let context = container.mainContext
        let complete = BodyMeasurement(weight: 80, bodyFat: 15)
        let manual = BodyMeasurement(weight: 80, bodyFat: 15, ffmi: 22.5)
        let partial = BodyMeasurement(weight: 80)
        context.insert(complete)
        context.insert(manual)
        context.insert(partial)
        try context.save()

        HealthImport.fillMissingFFMI(in: context, heightMeters: 1.8)

        #expect(complete.ffmi == 21.0)
        #expect(manual.ffmi == 22.5)
        #expect(partial.ffmi == nil)

        let goal = MetricGoal(metric: .ffmi, lowerBound: 22, upperBound: 22)
        let trend = GoalTrends.trends(
            goals: [goal], measurements: [complete], period: .month
        ).first
        #expect(trend?.current == 21.0)
    }
}
