import SwiftUI

/// Shared measurements for the open, ruled Field Guide interface.
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

    /// Warm paper and olive ink form the canvas. The adaptive clay accent is
    /// reserved for actions and progress.
    enum Palette {
        static func canvas(_ scheme: ColorScheme) -> Color {
            scheme == .dark
                ? Color(red: 0.085, green: 0.105, blue: 0.095)
                : Color(red: 0.953, green: 0.949, blue: 0.920)
        }

        static func surface(_ scheme: ColorScheme) -> Color {
            scheme == .dark
                ? Color(red: 0.135, green: 0.155, blue: 0.140)
                : Color(red: 0.985, green: 0.981, blue: 0.955)
        }

        static func raised(_ scheme: ColorScheme) -> Color {
            scheme == .dark
                ? Color(red: 0.195, green: 0.220, blue: 0.200)
                : Color(red: 0.890, green: 0.895, blue: 0.860)
        }

        static func rule(_ scheme: ColorScheme) -> Color {
            scheme == .dark
                ? Color(red: 0.80, green: 0.83, blue: 0.77).opacity(0.24)
                : Color(red: 0.15, green: 0.21, blue: 0.18).opacity(0.32)
        }
    }
}
