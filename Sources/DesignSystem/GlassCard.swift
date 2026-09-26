import SwiftUI

/// A solid record surface. The existing name keeps call sites stable while
/// the app's content moves from glass to the logbook's quiet tonal layers.
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
            .padding(Theme.Spacing.loose)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.Palette.surface(colorScheme), in: .rect(cornerRadius: Theme.Radius.card))
    }
}

/// The same record surface for the workout library.
struct SolidCard<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(Theme.Spacing.loose)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.Palette.surface(colorScheme), in: .rect(cornerRadius: Theme.Radius.card))
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
