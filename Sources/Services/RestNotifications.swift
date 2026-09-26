import Foundation
import UserNotifications

/// Scheduling the "pause is over" alert.
///
/// Behind a protocol so the timer's scheduling logic can be tested without
/// touching the notification centre, which is unavailable in unit tests.
protocol RestNotificationScheduling: AnyObject, Sendable {
    /// Called on the first pause; the system prompt appears only once.
    func requestAuthorizationIfNeeded() async
    func schedule(in seconds: TimeInterval, context: String)
    func cancel()
}

/// Local notifications — no entitlement and no developer team required, unlike
/// HealthKit and CloudKit. This works on an unsigned simulator build too.
final class LocalRestNotifications: RestNotificationScheduling, @unchecked Sendable {
    static let identifier = "rest-timer-finished"

    private let center: UNUserNotificationCenter
    private var didRequestAuthorization = false

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    func requestAuthorizationIfNeeded() async {
        guard !didRequestAuthorization else { return }
        didRequestAuthorization = true
        _ = try? await center.requestAuthorization(options: [.alert, .sound])
    }

    func schedule(in seconds: TimeInterval, context: String) {
        cancel()
        guard seconds > 0 else { return }

        let content = UNMutableNotificationContent()
        content.title = "Pause vorbei"
        content.body = context.isEmpty ? "Weiter geht's." : "Nächster Satz: \(context)"
        content.sound = .default
        content.interruptionLevel = .timeSensitive

        let request = UNNotificationRequest(
            identifier: Self.identifier,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: false)
        )
        center.add(request)
    }

    func cancel() {
        center.removePendingNotificationRequests(withIdentifiers: [Self.identifier])
        center.removeDeliveredNotifications(withIdentifiers: [Self.identifier])
    }
}

/// Records calls instead of scheduling anything. Used by the tests.
final class RecordingRestNotifications: RestNotificationScheduling, @unchecked Sendable {
    struct Scheduled: Equatable {
        let seconds: TimeInterval
        let context: String
    }

    private(set) var scheduled: [Scheduled] = []
    private(set) var cancelCount = 0
    private(set) var authorizationRequests = 0

    func requestAuthorizationIfNeeded() async {
        authorizationRequests += 1
    }

    func schedule(in seconds: TimeInterval, context: String) {
        scheduled.append(Scheduled(seconds: seconds, context: context))
    }

    func cancel() {
        cancelCount += 1
    }
}
