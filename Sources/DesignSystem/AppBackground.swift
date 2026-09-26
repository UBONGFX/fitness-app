import SwiftUI

/// Quiet logbook canvas behind solid records and native navigation chrome.
struct AppBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Theme.Palette.canvas(colorScheme).ignoresSafeArea()
    }
}
