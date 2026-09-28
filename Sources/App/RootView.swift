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

    @Environment(\.modelContext) private var context
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
    @State private var showingFinishConfirmation = false
    @AccessibilityFocusState private var finishTitleFocused: Bool

    private var showAccessory: Bool {
        restTimer.isRunning || (!activeSessions.isEmpty && selection == .training)
    }

    private var showWorkoutPlus: Bool {
        selection == .training && activeSessions.isEmpty
    }

    var body: some View {
        ZStack {
            TabView(selection: $selection) {
                Tab("Übersicht", systemImage: "square.grid.2x2", value: AppTab.home) {
                    // The overview links into the other tabs, so it needs to move the
                    // selection rather than push a second copy of those screens.
                    HomeView(selectedTab: $selection, appearance: $appearance)
                        .toolbar(.hidden, for: .tabBar)
                }
                Tab("Training", systemImage: "figure.strengthtraining.traditional", value: AppTab.training) {
                    TrainingView(
                        showingActions: $showingWorkoutActions,
                        showingFinishConfirmation: $showingFinishConfirmation
                    )
                        .toolbar(.hidden, for: .tabBar)
                }
                Tab("Körper", systemImage: "ruler", value: AppTab.body) {
                    BodyView(isUsingFallbackStore: isUsingFallbackStore)
                        .toolbar(.hidden, for: .tabBar)
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) { bottomNavigation }
            .accessibilityHidden(showingFinishConfirmation)

            if selection == .training, showingFinishConfirmation,
               let session = activeSessions.first {
                finishModalOverlay(for: session)
                    .transition(.opacity)
            }
        }
        // On the root view, not on a screen: a sheet presented from here
        // would otherwise keep the system scheme while everything behind it
        // changed.
        .preferredColorScheme(appearance.colorScheme)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: showingFinishConfirmation)
        .onChange(of: selection) { _, newValue in
            if newValue != .training { showingFinishConfirmation = false }
        }
        .onChange(of: showingFinishConfirmation) { _, isShown in
            finishTitleFocused = isShown
        }
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

    private func finishModalOverlay(for session: WorkoutSession) -> some View {
        ZStack {
            Color.black.opacity(colorScheme == .dark ? 0.62 : 0.42)
                .ignoresSafeArea()
                .onTapGesture { showingFinishConfirmation = false }

            VStack(alignment: .leading, spacing: Theme.Spacing.regular) {
                HStack(alignment: .top, spacing: Theme.Spacing.tight) {
                    Text("Training abschließen?")
                        .font(.system(.title2, design: .serif).weight(.semibold))
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityFocused($finishTitleFocused)
                    Spacer(minLength: Theme.Spacing.tight)
                    Button {
                        showingFinishConfirmation = false
                    } label: {
                        Image(systemName: "xmark")
                            .font(.footnote.weight(.semibold))
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Schließen")
                }

                Text("\(session.dayName) · \(session.completedSets == 1 ? "1 Satz" : "\(session.completedSets) Sätze") · \(session.durationText)")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Rectangle()
                    .fill(Theme.Palette.rule(colorScheme))
                    .frame(height: 1)
                    .padding(.vertical, 4)

                Text("Danach findest du die Einheit im Verlauf.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if horizontalSizeClass == .compact || dynamicTypeSize.isAccessibilitySize {
                    VStack(spacing: Theme.Spacing.tight) { finishModalActions(for: session) }
                } else {
                    HStack(spacing: Theme.Spacing.tight) { finishModalActions(for: session) }
                }
            }
            .padding(Theme.Spacing.loose)
            .frame(maxWidth: 440)
            .background(Theme.Palette.surface(colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
            .shadow(color: .black.opacity(colorScheme == .dark ? 0.42 : 0.18), radius: 30, x: 0, y: 14)
            .padding(Theme.Spacing.loose)
            .accessibilityElement(children: .contain)
            .accessibilityAction(.escape) { showingFinishConfirmation = false }
        }
    }

    @ViewBuilder
    private func finishModalActions(for session: WorkoutSession) -> some View {
        Button {
            showingFinishConfirmation = false
        } label: {
            Text("Weiter trainieren")
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.bordered)

        Button {
            finish(session)
        } label: {
            Text("Training abschließen")
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.borderedProminent)
        .accessibilityIdentifier("confirmFinishSession")
    }

    private func finish(_ session: WorkoutSession) {
        session.endedAt = Date()
        if saveReporter.perform("Training abschließen", { try context.save() }) {
            showingFinishConfirmation = false
        } else {
            session.endedAt = nil
        }
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
