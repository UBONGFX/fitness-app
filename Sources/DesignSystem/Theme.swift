import SwiftUI

/// Shared layout constants. Values are points; spacing scales with Dynamic Type
/// through the system fonts used on top of them, not through hardcoded sizes.
enum Theme {
    enum Spacing {
        static let tight: CGFloat = 8
        static let regular: CGFloat = 14
        static let loose: CGFloat = 20
        static let section: CGFloat = 28
    }

    enum Radius {
        static let card: CGFloat = 22
        static let control: CGFloat = 14
        static let badge: CGFloat = 10
    }
}
