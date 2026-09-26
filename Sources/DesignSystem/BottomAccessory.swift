import SwiftUI

extension EnvironmentValues {
    /// How much room the floating pause bar takes at the bottom of the screen.
    ///
    /// Set once by `RootView`, which is the only place that knows whether the
    /// accessory is attached. Zero when it is not.
    @Entry var bottomAccessoryHeight: CGFloat = 0
}

extension View {
    /// Keeps scrolling content clear of the floating pause bar.
    ///
    /// The bar is an overlay, not part of the layout: content scrolls underneath
    /// it and the last rows end up unreachable — a tap there hits the bar and
    /// silently does nothing, which is exactly how the history rows stopped
    /// opening. Reserving the space is the fix; hiding the bar would cost the
    /// countdown that is the point of it.
    func clearsBottomAccessory() -> some View {
        modifier(BottomAccessoryClearance())
    }
}

private struct BottomAccessoryClearance: ViewModifier {
    @Environment(\.bottomAccessoryHeight) private var height

    func body(content: Content) -> some View {
        content.safeAreaPadding(.bottom, height)
    }
}
