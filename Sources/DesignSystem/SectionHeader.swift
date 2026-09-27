import SwiftUI

struct FieldGuidePageTitle: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(.largeTitle, design: .serif).weight(.bold))
            .tracking(-0.5)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityAddTraits(.isHeader)
    }
}

struct SectionHeader: View {
    let title: String
    var subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(.title3, design: .serif).weight(.semibold))
            if let subtitle {
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}
