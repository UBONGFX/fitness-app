import SwiftUI

/// A soft, slowly shifting mesh gradient that sits behind every screen.
///
/// Liquid Glass only reads as glass when there is something behind it to refract,
/// so this is load-bearing for the design rather than decoration.
struct AppBackground: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var drift = false

    /// A cool violet-to-teal field. Deliberately narrow in hue: the saturated
    /// push/pull/legs colours belong to the data, and the backdrop must not
    /// compete with them on a screen that gets opened every day.
    ///
    /// Held far back rather than saturated. The first version was a full-strength
    /// gradient, which looked striking for a minute and then made every number on
    /// top of it harder to read — and the numbers are the reason the app exists.
    /// What remains is a tint in the near-black, enough for the glass to have
    /// something to refract.
    private var palette: [Color] {
        let base: [Color] = [
            .purple, .indigo, .blue,
            .indigo, .teal,   .blue,
            .mint,   .teal,   .indigo,
        ]
        return base.map { $0.opacity(colorScheme == .dark ? 0.34 : 0.50) }
    }

    /// How much flat background is laid over the gradient.
    ///
    /// The two modes want opposite things. Dark goes nearly opaque: close to
    /// black with the cards a shade lighter, which is what the design follows.
    /// Light must stay colourful — veiling it as heavily turned the gradient into
    /// grey, and glass over near-white renders as plain white, so the rows
    /// stopped looking like glass at all.
    private var veil: Double { colorScheme == .dark ? 0.82 : 0.24 }

    var body: some View {
        MeshGradient(
            width: 3,
            height: 3,
            points: [
                [0.0, 0.0], [0.5, 0.0], [1.0, 0.0],
                [0.0, 0.5], [drift ? 0.6 : 0.4, 0.5], [1.0, 0.5],
                [0.0, 1.0], [0.5, 1.0], [1.0, 1.0],
            ],
            colors: palette
        )
        .overlay(Color(.systemBackground).opacity(veil))
        .ignoresSafeArea()
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 14).repeatForever(autoreverses: true)) {
                drift = true
            }
        }
    }
}
