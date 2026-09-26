import SwiftUI

/// A quiet canvas that lets content and the single app accent carry the hierarchy.
struct AppBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        (colorScheme == .dark
            ? Color(red: 0.075, green: 0.081, blue: 0.09)
            : Color(red: 0.965, green: 0.969, blue: 0.968))
            .ignoresSafeArea()
    }
}
