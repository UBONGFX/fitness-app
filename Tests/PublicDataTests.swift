import Foundation
import Testing
@testable import FitnessApp

struct PublicDataTests {
    @Test func starterCatalogueHasDistinctGenericExercises() {
        let exercises = SeedData.sampleExercises()
        #expect(exercises.count >= 8)
        #expect(Set(exercises.map(\.name)).count == exercises.count)
    }

    @Test func standaloneWorkoutExportsWithItsPrescription() throws {
        let exercise = Exercise(name: "Rudern", primary: .back)
        let workout = PlanDay(name: "Oberkörper", category: .general)
        let item = PlanExercise(order: 0, sets: 3, reps: 8...12, exercise: exercise)
        item.day = workout
        workout.exercises = [item]

        let document = DataExport.makeDocument(
            exercises: [exercise], plans: [], workouts: [workout], sessions: [],
            measurements: [], goals: []
        )
        let decoded = try DataExport.decode(DataExport.encode(document))
        #expect(decoded.workouts?.first?.name == "Oberkörper")
        #expect(decoded.workouts?.first?.exercises.first?.sets == 3)
    }

    @Test func progressHandlesTargetsAboveAndBelowTheCurrentValue() {
        #expect(GoalProgress.evaluate(start: 70, current: 75, lower: 80, upper: 82).progress > 0)
        #expect(GoalProgress.evaluate(start: 20, current: 22, lower: 12, upper: 15).progress == 0)
    }

    @Test func futureMeasurementDoesNotCountAsCurrentProgress() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let goal = MetricGoal(metric: .weight, lowerBound: 80, upperBound: 82)
        let past = BodyMeasurement(date: now.addingTimeInterval(-86_400), weight: 75)
        let future = BodyMeasurement(date: now.addingTimeInterval(86_400), weight: 81)

        let trend = GoalTrends.trends(
            goals: [goal], measurements: [past, future], period: .month, now: now
        ).first
        #expect(trend?.current == 75)
        #expect(trend?.delta == nil)
    }

    @Test func primaryObservationAppearsFirstWithoutInventingProgress() {
        let primary = MetricGoal(metric: .ffmi, priority: .primary, hasTarget: false)
        let secondary = MetricGoal(metric: .weight, lowerBound: 80, upperBound: 82)
        let measurement = BodyMeasurement(date: Date().addingTimeInterval(-60), ffmi: 21)
        let trends = GoalTrends.trends(
            goals: [secondary, primary], measurements: [measurement], period: .month
        )

        #expect(trends.map(\.metric) == [.ffmi, .weight])
        #expect(trends.first?.current == 21)
        #expect(trends.first?.evaluation == nil)
        #expect(trends.first?.targetText == "Beobachten")
    }

    @Test func goalExportKeepsPriorityAndObservationState() throws {
        let goal = MetricGoal(metric: .ffmi, priority: .primary, hasTarget: false)
        let document = DataExport.makeDocument(
            exercises: [], plans: [], sessions: [], measurements: [], goals: [goal]
        )
        let decoded = try DataExport.decode(DataExport.encode(document))

        #expect(decoded.goals.first?.priority == GoalPriority.primary.rawValue)
        #expect(decoded.goals.first?.hasTarget == false)
    }

    @Test func olderGoalExportWithoutNewFieldsStillDecodes() throws {
        let data = Data("""
        {"id":"00000000-0000-0000-0000-000000000001","metric":"ffmi","lowerBound":21,"upperBound":21}
        """.utf8)
        let goal = try JSONDecoder().decode(ExportedGoal.self, from: data)

        #expect(goal.priority == nil)
        #expect(goal.hasTarget == nil)
    }
}
