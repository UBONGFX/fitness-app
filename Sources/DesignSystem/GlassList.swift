import SwiftUI

/// Where a row sits in its grouped record.
enum GlassRowPosition {
    case only, first, middle, last

    static func of(_ index: Int, count: Int) -> GlassRowPosition {
        if count <= 1 { return .only }
        if index == 0 { return .first }
        if index == count - 1 { return .last }
        return .middle
    }

    var roundsTop: Bool { self == .only || self == .first }
    var roundsBottom: Bool { self == .only || self == .last }
    /// The last row of a group closes it; a separator there would cut the card.
    var showsSeparator: Bool { !roundsBottom }
}

extension View {
    /// Puts a `List` or `Form` on the app canvas.
    ///
    /// Rows sit flush against each other so a section reads as **one** card with
    /// separators, the way a grouped list does — separate capsules per row were
    /// tried and made a plan day look like a loose pile rather than a list.
    func glassFormBackground() -> some View {
        scrollContentBackground(.hidden)
            .listRowSpacing(0)
            .background(AppBackground())
    }
}

extension View {
    /// A solid record surface behind a list row.
    ///
    /// Must sit on a row or on a `Section` — applying it to the whole `List` or
    /// `Form` does nothing at all, the rows simply stay white.
    ///
    /// The position decides which corners are rounded, so a run of rows closes
    /// into a single card top and bottom instead of each one being its own pill.
    func glassRow(
        _ position: GlassRowPosition = .only,
        cornerRadius: CGFloat = Theme.Radius.control
    ) -> some View {
        listRowBackground(SolidRowBackground(position: position, cornerRadius: cornerRadius))
        .listRowSeparator(position.showsSeparator ? .visible : .hidden)
    }
}

private struct SolidRowBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    let position: GlassRowPosition
    let cornerRadius: CGFloat

    var body: some View {
        UnevenRoundedRectangle(
            topLeadingRadius: position.roundsTop ? cornerRadius : 0,
            bottomLeadingRadius: position.roundsBottom ? cornerRadius : 0,
            bottomTrailingRadius: position.roundsBottom ? cornerRadius : 0,
            topTrailingRadius: position.roundsTop ? cornerRadius : 0
        )
        .fill(Theme.Palette.surface(colorScheme))
    }
}
