import SwiftData
import Testing
@testable import FitnessApp

@MainActor
struct WorkoutLibraryTests {
    @Test func legacyDayBecomesAnIndependentTemplate() throws {
        let schema = Schema([WorkoutPlan.self, PlanDay.self, PlanExercise.self, Exercise.self])
        let store = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: store)
        let context = container.mainContext

        let exercise = Exercise(name: "Rudern", primary: .back)
        let plan = WorkoutPlan(name: "Beispiel")
        let day = PlanDay(weekday: 3, name: "Oberkörper", category: .general)
        let item = PlanExercise(order: 0, sets: 3, reps: 8...12, exercise: exercise)
        item.day = day
        day.exercises = [item]
        day.plan = plan
        plan.days = [day]
        context.insert(exercise)
        context.insert(plan)
        try context.save()

        WorkoutLibrary.importExistingPlansIfNeeded(context, inMemoryStore: true)

        let days = try context.fetch(FetchDescriptor<PlanDay>())
        let template = try #require(WorkoutLibrary.templates(in: days).first)
        #expect(template.plan == nil)
        #expect(template.id != day.id)
        #expect(template.sortedExercises.first?.exercise?.id == exercise.id)
        #expect(plan.sortedDays.count == 1)

        let session = WorkoutLibrary.makeSession(from: template)
        #expect(session.dayName == "Oberkörper")
        #expect(session.sortedExercises.first?.targetText == "3 × 8–12")
    }
}
