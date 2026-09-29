import SwiftData
import SwiftUI

@main
struct FitnessApp: App {
    let container: ModelContainer

    /// True when the on-disk store could not be opened and the app fell back to
    /// memory. Data entered in this state is lost on quit, so the UI must say so
    /// rather than pretend everything is fine.
    let isUsingFallbackStore: Bool

    init() {
        let schema = Schema([
            BodyMeasurement.self, MetricGoal.self,
            Exercise.self, WorkoutPlan.self, PlanDay.self, PlanExercise.self,
            WorkoutSession.self, LoggedExercise.self, LoggedSet.self,
        ])
        // CloudKit stays off until a developer team is configured; the models are
        // already written to its rules so switching it on is a configuration change.
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: AppConfig.cloudKitSyncEnabled ? .automatic : .none
        )

        // UI tests must not inherit state from each other. With this flag the app
        // runs on a fresh in-memory store seeded from scratch on every launch.
        if ProcessInfo.processInfo.arguments.contains("-uiTesting") {
            // The store is rebuilt per launch, but `UserDefaults` survive it —
            // a name typed by one test was still there for the next.
            UserProfile.reset()
            let memory = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            container = try! ModelContainer(for: schema, configurations: memory)
            isUsingFallbackStore = false
            // `-emptyStore` skips the seed so the empty states are reachable at
            // all. Deleting everything through the UI first would test the
            // deletion, not the empty screen.
            if !ProcessInfo.processInfo.arguments.contains("-emptyStore") {
                SeedData.seed(container.mainContext)
                WorkoutLibrary.importExistingPlansIfNeeded(container.mainContext, inMemoryStore: true)
            }
        } else if let persistent = try? ModelContainer(for: schema, configurations: configuration) {
            container = persistent
            isUsingFallbackStore = false
            SeedData.seedIfNeeded(persistent.mainContext)
            WorkoutLibrary.importExistingPlansIfNeeded(persistent.mainContext)
            HealthImport.fillMissingFFMI(in: persistent.mainContext, heightMeters: UserProfile.heightMeters)
        } else {
            // A corrupt store or a failed migration must not make the app
            // unlaunchable — start in memory and let the user see the warning.
            let memory = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            container = try! ModelContainer(for: schema, configurations: memory)
            isUsingFallbackStore = true
            SeedData.seedIfNeeded(container.mainContext)
            WorkoutLibrary.importExistingPlansIfNeeded(container.mainContext)
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView(isUsingFallbackStore: isUsingFallbackStore)
                // The UI is German-only, so dates must not fall back to English
                // month names just because the device language is set otherwise.
                .environment(\.locale, Locale(identifier: "de_DE"))
        }
        .modelContainer(container)
    }
}
