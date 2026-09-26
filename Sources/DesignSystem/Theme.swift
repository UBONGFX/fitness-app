import SwiftUI

/// Shared layout constants. Values are points; spacing scales with Dynamic Type
/// through the system fonts used on top of them, not through hardcoded sizes.
enum Theme {
    enum Spacing {
        static let tight: CGFloat = 8
        static let regular: CGFloat = 16
        static let loose: CGFloat = 20
        static let section: CGFloat = 32
    }

    enum Radius {
        static let card: CGFloat = 16
        static let control: CGFloat = 12
        static let badge: CGFloat = 8
    }

    /// The logbook uses tonal layers for depth. Its one accent comes from the
    /// adaptive AccentColor asset and is reserved for actions and progress.
    enum Palette {
        static func canvas(_ scheme: ColorScheme) -> Color {
            scheme == .dark
                ? Color(red: 0.070, green: 0.080, blue: 0.085)
                : Color(red: 0.960, green: 0.968, blue: 0.965)
        }

        static func surface(_ scheme: ColorScheme) -> Color {
            scheme == .dark
                ? Color(red: 0.125, green: 0.145, blue: 0.150)
                : Color.white
        }

        static func raised(_ scheme: ColorScheme) -> Color {
            scheme == .dark
                ? Color(red: 0.170, green: 0.190, blue: 0.195)
                : Color(red: 0.915, green: 0.935, blue: 0.927)
        }

        static func rule(_ scheme: ColorScheme) -> Color {
            scheme == .dark
                ? Color.white.opacity(0.10)
                : Color.black.opacity(0.09)
        }
    }
}
