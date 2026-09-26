import SwiftUI

/// A content card rendered with the real Liquid Glass material.
///
/// Wrap groups of adjacent cards in a `GlassEffectContainer` so their effects
/// blend instead of fighting each other.
struct GlassCard<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme

    var tint: Color?
    @ViewBuilder var content: Content

    init(tint: Color? = nil, @ViewBuilder content: () -> Content) {
        self.tint = tint
        self.content = content()
    }

    /// Lighter in the dark.
    ///
    /// The same 12% that reads as a hint of colour on a bright backdrop turns
    /// muddy over near-black — an orange card came out brown. Colour here is
    /// only ever a category marker, so it loses nothing by being quieter.
    private var tintStrength: Double { colorScheme == .dark ? 0.07 : 0.12 }

    var body: some View {
        content
            .padding(Theme.Spacing.loose)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassEffect(
                tint.map { Glass.regular.tint($0.opacity(tintStrength)) } ?? .regular,
                in: .rect(cornerRadius: Theme.Radius.card)
            )
    }
}

/// A small pill used for muscle groups, categories and set counts.
struct GlassBadge: View {
    let text: String
    var tint: Color = .secondary

    var body: some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .glassEffect(Glass.regular.tint(tint.opacity(0.22)), in: .capsule)
    }
}
