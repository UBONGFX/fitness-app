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
}
