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

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

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
    @State private var showingWorkoutActions = false

    private var showAccessory: Bool {
        restTimer.isRunning || (!activeSessions.isEmpty && selection == .training)
    }

    private var showWorkoutPlus: Bool {
        selection == .training && activeSessions.isEmpty
    }

    var body: some View {
        TabView(selection: $selection) {
            Tab("Übersicht", systemImage: "square.grid.2x2", value: AppTab.home) {
                // The overview links into the other tabs, so it needs to move the
                // selection rather than push a second copy of those screens.
                HomeView(selectedTab: $selection, appearance: $appearance)
                    .toolbar(.hidden, for: .tabBar)
            }
            Tab("Training", systemImage: "figure.strengthtraining.traditional", value: AppTab.training) {
                TrainingView(showingActions: $showingWorkoutActions)
                    .toolbar(.hidden, for: .tabBar)
            }
            Tab("Körper", systemImage: "ruler", value: AppTab.body) {
                BodyView(isUsingFallbackStore: isUsingFallbackStore)
                    .toolbar(.hidden, for: .tabBar)
            }
        }
        // On the whole tab view, not on a screen: a sheet presented from here
        // would otherwise keep the system scheme while everything behind it
        // changed.
        .preferredColorScheme(appearance.colorScheme)
        .safeAreaInset(edge: .bottom, spacing: 0) { bottomNavigation }
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

    private var bottomNavigation: some View {
        GlassEffectContainer(spacing: Theme.Spacing.tight) {
            VStack(spacing: Theme.Spacing.tight) {
                if showAccessory {
                    RestTimerAccessory(hasActiveSession: !activeSessions.isEmpty)
                        .padding(.vertical, Theme.Spacing.tight)
                        .glassEffect(in: .capsule)
                }

                HStack(spacing: Theme.Spacing.tight) {
                    HStack(spacing: 0) {
                        tabButton(.home, title: "Übersicht", symbol: "square.grid.2x2")
                        tabButton(.training, title: "Training", symbol: "figure.strengthtraining.traditional")
                        tabButton(.body, title: "Körper", symbol: "ruler")
                    }
                    .padding(4)
                    .frame(maxWidth: showWorkoutPlus ? 300 : 340)
                    .glassEffect(in: .capsule)

                    if showWorkoutPlus {
                        Button {
                            showingWorkoutActions = true
                        } label: {
                            Image(systemName: "plus")
                                .font(.title3.weight(.semibold))
                                .frame(width: 56, height: 56)
                        }
                        .buttonStyle(.glass)
                        .buttonBorderShape(.circle)
                        .tint(.accentColor)
                        .accessibilityLabel("Workout hinzufügen")
                        .accessibilityIdentifier("workoutPlus")
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, Theme.Spacing.regular)
        .padding(.top, Theme.Spacing.tight)
        .padding(.bottom, 4)
    }

    private func tabButton(_ tab: AppTab, title: String, symbol: String) -> some View {
        Button {
            selection = tab
        } label: {
            VStack(spacing: 3) {
                Image(systemName: symbol)
                    .font(.system(size: 19, weight: .medium))
                if !dynamicTypeSize.isAccessibilitySize {
                    Text(title)
                        .font(.caption2.weight(.medium))
                        .lineLimit(1)
                }
            }
            .foregroundStyle(selection == tab ? Color.accentColor : Color.primary)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background {
                if selection == tab {
                    Capsule().fill(Theme.Palette.raised(colorScheme).opacity(0.75))
                }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(selection == tab ? .isSelected : [])
    }
}

#Preview {
    RootView()
}
