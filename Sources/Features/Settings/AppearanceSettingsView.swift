import SwiftUI

/// Light, dark, or follow the iPhone.
///
/// Worth its own setting because the app is used in two very different places:
/// a bright kitchen in the morning and a dim gym in the evening, and iOS does
/// not always switch between them at the moment you would want it to.
struct AppearanceSettingsView: View {
    @Binding var appearance: AppAppearance

    var body: some View {
        List {
            Section {
                ForEach(Array(AppAppearance.allCases.enumerated()), id: \.element.id) { index, option in
                    Button {
                        appearance = option
                    } label: {
                        HStack(spacing: Theme.Spacing.regular) {
                            Image(systemName: option.symbol)
                                .frame(width: 24)
                                .foregroundStyle(.secondary)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(option.displayName)
                                Text(option.detail)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer(minLength: Theme.Spacing.tight)
                            if appearance == option {
                                Image(systemName: "checkmark")
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(.tint)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("appearance-\(option.rawValue)")
                    .accessibilityLabel(option.displayName)
                    .accessibilityValue(appearance == option ? "ausgewählt" : "")
                    .glassRow(.of(index, count: AppAppearance.allCases.count))
                }
            } footer: {
                Text("Gilt nur für diese App. Die Einstellung des iPhones bleibt unberührt.")
            }
        }
        .glassFormBackground()
        .navigationTitle("Erscheinungsbild")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: appearance) { _, new in UserProfile.appearance = new }
    }
}
