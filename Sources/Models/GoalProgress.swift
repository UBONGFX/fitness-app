import Foundation

nonisolated struct GoalEvaluation: Equatable, Sendable {
    /// 0 = still at the starting value (or moved away from the goal), 1 = inside the corridor.
    let progress: Double
    let isReached: Bool
    /// Distance still to cover to reach the nearest corridor edge; `nil` once inside.
    let remaining: Double?
}

/// Progress from a starting measurement towards a goal corridor.
///
/// Direction is derived, never configured: body fat and belly are goals to move
/// *down* to, chest and shoulders goals to move *up* to, and the waist corridor
/// already contains its own starting value. Asking each goal for its direction
/// would just be a second place to get it wrong.
nonisolated enum GoalProgress {
    static func evaluate(start: Double, current: Double, lower: Double, upper: Double) -> GoalEvaluation {
        let low = min(lower, upper)
        let high = max(lower, upper)

        if current >= low, current <= high {
            return GoalEvaluation(progress: 1, isReached: true, remaining: nil)
        }

        // Outside the corridor: measure against the edge that is actually nearest,
        // which is the one the next kilo or centimetre has to close.
        let bound = current < low ? low : high
        let distanceNow = abs(current - bound)
        let distanceAtStart = abs(start - bound)

        guard distanceAtStart > 1e-9 else {
            // The start already sat on the edge, so any drift away is zero progress.
            return GoalEvaluation(progress: 0, isReached: false, remaining: distanceNow)
        }

        let ratio = 1 - distanceNow / distanceAtStart
        return GoalEvaluation(
            progress: min(max(ratio, 0), 1),
            isReached: false,
            remaining: distanceNow
        )
    }
}
