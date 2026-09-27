import SwiftUI

/// An open record on the Field Guide canvas. The existing name preserves
/// call sites while the visual system moves away from a stack of cards.
struct GlassCard<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme

    var tint: Color?
    @ViewBuilder var content: Content

    init(tint: Color? = nil, @ViewBuilder content: () -> Content) {
        self.tint = tint
        self.content = content()
    }

    var body: some View {
        content
            .padding(.vertical, Theme.Spacing.regular)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(alignment: .top) {
                (tint ?? Theme.Palette.rule(colorScheme)).frame(height: 1)
            }
    }
}

/// The same ruled treatment for workouts, history, and active sets.
struct SolidCard<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(.vertical, Theme.Spacing.regular)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(alignment: .top) {
                Theme.Palette.rule(colorScheme).frame(height: 1)
            }
    }
}

/// Small neutral label for muscle groups, categories and set counts.
struct GlassBadge: View {
    @Environment(\.colorScheme) private var colorScheme
    let text: String
    var tint: Color = .secondary

    var body: some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Theme.Palette.raised(colorScheme), in: .rect(cornerRadius: Theme.Radius.badge))
    }
}
