import SwiftUI

/// The height, chosen on a wheel.
///
/// A wheel rather than a list of a hundred rows: the value you want is almost
/// always within a few centimetres of the one already set, and a wheel puts
/// those neighbours directly under your thumb. It also removes the last way to
/// enter a wrong height — there is nothing to type.
struct HeightPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var centimetres: Int

    /// Edited on a copy so closing without saving really changes nothing.
    @State private var draft: Int = 0

    var body: some View {
        NavigationStack {
            VStack(spacing: Theme.Spacing.loose) {
                Picker("Größe", selection: $draft) {
                    ForEach(UserProfile.centimetreRange, id: \.self) { value in
                        Text(UserProfile.heightText(centimetres: value))
                            .tag(value)
                    }
                }
                .pickerStyle(.wheel)
                .accessibilityIdentifier("heightWheel")

                Button {
                    centimetres = draft
                    dismiss()
                } label: {
                    Text("Speichern")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("saveHeight")
            }
            .padding(Theme.Spacing.regular)
            .background(AppBackground())
            .navigationTitle("Größe auswählen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                        .accessibilityIdentifier("cancelHeight")
                }
            }
            .onAppear { draft = centimetres }
        }
    }
}
