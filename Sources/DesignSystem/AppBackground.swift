import SwiftUI

/// Matte Field Guide canvas behind ruled content and native controls.
struct AppBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Theme.Palette.canvas(colorScheme).ignoresSafeArea()
    }
}
