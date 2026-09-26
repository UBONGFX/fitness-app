import Foundation
import Observation
import OSLog

/// Reports failed writes instead of swallowing them.
///
/// Every call site used to be `try? context.save()`. That reads as "saving
/// cannot fail", which is not true: a full disk, a failed migration or a model
/// constraint all throw here. The old code would have lost a logged set in
/// silence, and the app would have looked perfectly fine doing it.
@Observable
@MainActor
final class SaveReporter {
    /// Set when a write failed; the root view shows it and clears it.
    private(set) var message: String?
    /// Counts failures for the tests — a message can be dismissed, this cannot.
    private(set) var failureCount = 0

    private let logger = Logger(subsystem: "com.jordiisken.fitnessapp", category: "persistence")

    init() {}

    /// Runs a write. `action` names it in the user's terms ("Satz sichern"), so
    /// the alert says what was lost rather than quoting a Core Data error alone.
    @discardableResult
    func perform(_ action: String, _ work: () throws -> Void) -> Bool {
        do {
            try work()
            return true
        } catch {
            failureCount += 1
            logger.error("\(action, privacy: .public) fehlgeschlagen: \(error)")
            message = "\(action) fehlgeschlagen. \(error.localizedDescription)"
            return false
        }
    }

    func dismiss() {
        message = nil
    }
}
