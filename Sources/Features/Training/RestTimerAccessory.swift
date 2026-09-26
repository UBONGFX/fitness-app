import SwiftUI

/// The pause timer that lives above the tab bar.
///
/// It sits in `tabViewBottomAccessory` rather than inside the session screen so
/// the countdown keeps running while checking body measurements mid-workout.
struct RestTimerAccessory: View {
    @Environment(RestTimer.self) private var timer
    let hasActiveSession: Bool

    var body: some View {
        if timer.isRunning {
            runningView
        } else if hasActiveSession {
            presetsView
        }
    }

    private var runningView: some View {
        HStack(spacing: Theme.Spacing.regular) {
            Image(systemName: "timer")
                .font(.footnote)
                .foregroundStyle(.secondary)

            // Rendered from the end date, so it cannot drift while navigating.
            TimelineView(.periodic(from: .now, by: 1)) { context in
                Text(RestFormat.clock(timer.remaining(at: context.date)))
                    .font(.title3.weight(.semibold).monospacedDigit())
                    .contentTransition(.numericText())
            }
            .accessibilityIdentifier("restCountdown")

            if !timer.context.isEmpty {
                Text(timer.context)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: Theme.Spacing.tight)

            Button("+30 s") { timer.extend(by: 30) }
                .font(.caption.weight(.semibold))
                .buttonStyle(.glass)
                .accessibilityIdentifier("restExtend")

            Button("Pause abbrechen", systemImage: "xmark") { timer.stop() }
                .labelStyle(.iconOnly)
                .font(.caption)
                .buttonStyle(.glass)
                .accessibilityIdentifier("restStop")
        }
        .padding(.horizontal, Theme.Spacing.regular)
    }

    /// Four presets and nothing else.
    ///
    /// A leading "Pause" label used to share the row; with four buttons next to
    /// it there was no width left and "2 Min" broke across two lines, turning the
    /// pill into a circle and pushing the row into the tab bar. The buttons say
    /// what they are, so the label was the part to drop.
    private var presetsView: some View {
        HStack(spacing: Theme.Spacing.tight) {
            ForEach(RestTimer.presets, id: \.self) { seconds in
                Button(RestFormat.label(seconds)) {
                    timer.start(seconds: Double(seconds))
                }
                .font(.caption.weight(.medium))
                .lineLimit(1)
                // Without this the label wraps before the row shrinks.
                .fixedSize(horizontal: true, vertical: false)
                .buttonStyle(.glass)
                .accessibilityIdentifier("restPreset-\(seconds)")
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, Theme.Spacing.tight)
    }
}
