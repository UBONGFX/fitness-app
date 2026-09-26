import Foundation
import Observation

/// Countdown between sets.
///
/// State is a single `endsAt` date rather than a ticking counter: the view
/// renders the remaining time from it, so the countdown stays correct across
/// navigation, backgrounding and redraws instead of drifting with a timer.
@Observable
@MainActor
final class RestTimer {
    /// Presets from `gym_tracker.html`, plus one minute for short isolation rests.
    nonisolated static let presets: [Int] = [60, 90, 120, 180]

    private(set) var endsAt: Date?
    private(set) var startedFrom: TimeInterval = 90
    /// Label of whatever started the pause, shown in the accessory.
    private(set) var context: String = ""
    /// Increments on each completed pause; drives the haptic.
    private(set) var completions: Int = 0

    private var task: Task<Void, Never>?
    private let notifications: RestNotificationScheduling

    init(notifications: RestNotificationScheduling = LocalRestNotifications()) {
        self.notifications = notifications
    }

    var isRunning: Bool { endsAt != nil }

    /// Asks for notification permission at a calm moment — when a session
    /// starts, not the instant a set is saved and the first pause begins.
    func prepareNotifications() {
        Task { await notifications.requestAuthorizationIfNeeded() }
    }

    func start(seconds: TimeInterval, context: String = "") {
        startedFrom = seconds
        self.context = context
        endsAt = Date().addingTimeInterval(seconds)
        scheduleCompletion(in: seconds)
        // Haptics only fire in the foreground. In the gym the screen is usually
        // off by the time the pause ends, so a local notification is the only
        // thing that actually reaches the user — unless it was switched off in
        // the settings, which is checked here rather than in the scheduler so
        // that cancelling still works either way.
        if UserProfile.wantsRestNotifications {
            notifications.schedule(in: seconds, context: context)
        } else {
            notifications.cancel()
        }
    }

    /// Extends a running pause; does nothing when idle, so a stray tap cannot
    /// start a pause nobody asked for.
    func extend(by seconds: TimeInterval) {
        guard let current = endsAt else { return }
        let new = max(current.addingTimeInterval(seconds), Date())
        endsAt = new
        scheduleCompletion(in: new.timeIntervalSinceNow)
        if UserProfile.wantsRestNotifications {
            notifications.schedule(in: new.timeIntervalSinceNow, context: context)
        }
    }

    func stop() {
        task?.cancel()
        task = nil
        endsAt = nil
        context = ""
        notifications.cancel()
    }

    func remaining(at now: Date = Date()) -> TimeInterval {
        guard let endsAt else { return 0 }
        return max(endsAt.timeIntervalSince(now), 0)
    }

    private func scheduleCompletion(in seconds: TimeInterval) {
        task?.cancel()
        guard seconds > 0 else {
            complete()
            return
        }
        task = Task { [weak self] in
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled else { return }
            self?.complete()
        }
    }

    private func complete() {
        endsAt = nil
        context = ""
        completions += 1
        // The pause ended with the app in front; the pending alert would only
        // arrive as a duplicate of the haptic.
        notifications.cancel()
    }
}

/// Formatting and preset selection, kept separate so they are testable without
/// the timer's clock.
nonisolated enum RestFormat {
    /// "1:30" — minutes and seconds, seconds always two digits.
    static func clock(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded(.up))
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    /// "90 Sek" / "3 Min" for the rest-time controls.
    static func label(_ seconds: Int) -> String {
        seconds % 60 == 0 && seconds >= 120 ? "\(seconds / 60) Min" : "\(seconds) Sek"
    }
}
