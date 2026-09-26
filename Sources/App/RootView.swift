import SwiftData
import SwiftUI

enum AppTab: String, CaseIterable {
    case home, training, body

    /// Lets screenshot runs open a specific tab: `simctl launch … -startTab training`.
    /// Without the argument the app always starts on the overview.
    static var launchDefault: AppTab {
        guard let raw = UserDefaults.standard.string(forKey: "startTab"),
              let tab = AppTab(rawValue: raw)
        else { return .home }
        return tab
    }
}

struct RootView: View {
    var isUsingFallbackStore = false

    @Query(filter: #Predicate<WorkoutSession> { $0.endedAt == nil })
    private var activeSessions: [WorkoutSession]

    @State private var selection = AppTab.launchDefault
    // A real notification scheduler asks iOS for permission on the first pause,
    // and that system dialog blocks every later tap in a UI test.
    @State private var restTimer = RestTimer(
        notifications: AppConfig.isUITesting
            ? RecordingRestNotifications()
            : LocalRestNotifications()
    )
    @State private var saveReporter = SaveReporter()
    @State private var appearance = UserProfile.appearance

    /// The accessory is only attached when it has something to show. Returning an
    /// empty view from `tabViewBottomAccessory` is not enough on iOS 27 — the
    /// container still renders as an empty capsule covering the content below.
    private var showAccessory: Bool {
        // A running countdown follows you everywhere — that is the point of it
        // living above the tab bar. The preset buttons do not: they are a
        // training control, and on the overview or the body screen they were
        // just a row of numbers with nothing to start. An unfinished session
        // made them permanent furniture.
        restTimer.isRunning || (!activeSessions.isEmpty && selection == .training)
    }

    var body: some View {
        TabView(selection: $selection) {
            Tab("Übersicht", systemImage: "square.grid.2x2", value: AppTab.home) {
                // The overview links into the other tabs, so it needs to move the
                // selection rather than push a second copy of those screens.
                HomeView(selectedTab: $selection, appearance: $appearance)
            }
            Tab("Training", systemImage: "figure.strengthtraining.traditional", value: AppTab.training) {
                TrainingView()
            }
            Tab("Körper", systemImage: "ruler", value: AppTab.body) {
                BodyView(isUsingFallbackStore: isUsingFallbackStore)
            }
        }
        // On the whole tab view, not on a screen: a sheet presented from here
        // would otherwise keep the system scheme while everything behind it
        // changed.
        .preferredColorScheme(appearance.colorScheme)
        .tabBarMinimizeBehavior(.onScrollDown)
        .restAccessory(showAccessory, hasActiveSession: !activeSessions.isEmpty)
        // The accessory floats over the content instead of taking part in the
        // layout, so every scrolling screen has to reserve the room itself.
        .environment(\.bottomAccessoryHeight, showAccessory ? 60 : 0)
        .environment(restTimer)
        .environment(saveReporter)
        // A failed write used to vanish silently; now it surfaces here.
        .alert(
            "Speichern fehlgeschlagen",
            isPresented: Binding(
                get: { saveReporter.message != nil },
                set: { if !$0 { saveReporter.dismiss() } }
            )
        ) {
            Button("OK") { saveReporter.dismiss() }
        } message: {
            Text(saveReporter.message ?? "")
        }
        // Fires once per finished pause — the whole point of a gym timer is that
        // you notice it without looking at the screen.
        .sensoryFeedback(.success, trigger: restTimer.completions)
    }
}

private extension View {
    /// Attaches the pause timer accessory, or nothing at all.
    @ViewBuilder
    func restAccessory(_ isShown: Bool, hasActiveSession: Bool) -> some View {
        if isShown {
            tabViewBottomAccessory {
                RestTimerAccessory(hasActiveSession: hasActiveSession)
            }
        } else {
            self
        }
    }
}

#Preview {
    RootView()
}
