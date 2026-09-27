import SwiftUI

/// The person behind the numbers: name, height, birthday.
///
/// Three fields rather than the reference design's eight, because these three
/// are the ones something actually reads — the height drives every FFMI, the
/// birthday gives an age, and the name puts an initial on the button. No e-mail,
/// no password, no "Ausloggen": nothing here talks to a server, so there is no
/// session to end and a logout button would be a prop.
struct ProfileView: View {
    @Binding var name: String

    @State private var heightCm = UserProfile.heightCentimetres
    @State private var birthday: Date = UserProfile.birthday ?? ProfileView.defaultBirthday
    @State private var hasBirthday = UserProfile.birthday != nil
    @State private var choosingHeight = false

    /// Far enough back that the wheel does not open on today, which would read
    /// as a newborn.
    private static var defaultBirthday: Date {
        GoalPeriod.calendar.date(from: DateComponents(year: 1995, month: 1, day: 1)) ?? Date()
    }

    var body: some View {
        List {
            Section {
                avatarHeader
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }

            Section {
                TextField("Name", text: $name)
                    .accessibilityIdentifier("profileName")
                    .glassRow(.first)

                // Whole centimetres from a wheel, not a typed decimal. A comma
                // field invited "1,8" where 183 was meant, and a tenth of a metre
                // is ten centimetres of error in every FFMI. A wheel puts the
                // neighbouring values in reach without a hundred-row list to
                // scroll through.
                Button {
                    choosingHeight = true
                } label: {
                    HStack {
                        Text("Größe")
                            .foregroundStyle(.primary)
                        Spacer(minLength: Theme.Spacing.tight)
                        Text(UserProfile.heightText(centimetres: heightCm))
                            .foregroundStyle(.secondary)
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("profileHeight")
                .accessibilityLabel("Größe")
                .accessibilityValue(UserProfile.heightText(centimetres: heightCm))
                .glassRow(.last)
            } header: {
                Text("Angaben")
            } footer: {
                Text("Die Größe geht in jeden FFMI ein.")
            }

            Section {
                Toggle("Geburtstag angeben", isOn: $hasBirthday)
                    .accessibilityIdentifier("hasBirthday")
                    .glassRow(hasBirthday ? .first : .only)

                if hasBirthday {
                    DatePicker(
                        "Geburtstag",
                        selection: $birthday,
                        in: ...Date(),
                        displayedComponents: .date
                    )
                    .accessibilityIdentifier("profileBirthday")
                    .glassRow(.middle)

                    LabeledContent("Alter", value: UserProfile.ageText(birthday: birthday) ?? "—")
                        .accessibilityIdentifier("profileAge")
                        .glassRow(.last)
                }
            } footer: {
                // Said plainly rather than implied: nothing computes with it yet,
                // and a field that pretends to matter is worse than an absent one.
                Text("Das Alter steht hier nur zur Übersicht — keine Auswertung der App "
                     + "rechnet damit.")
            }
        }
        .glassFormBackground()
        .navigationTitle("Kontodetails")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: name) { _, new in UserProfile.name = new }
        .onChange(of: heightCm) { _, new in UserProfile.heightCentimetres = new }
        .sheet(isPresented: $choosingHeight) {
            HeightPickerSheet(centimetres: $heightCm)
                .presentationDetents([.height(320)])
        }
        .onChange(of: birthday) { _, new in
            if hasBirthday { UserProfile.birthday = new }
        }
        .onChange(of: hasBirthday) { _, on in
            UserProfile.birthday = on ? birthday : nil
        }
    }

    private var avatarHeader: some View {
        VStack(spacing: Theme.Spacing.tight) {
            AccountAvatar(initials: UserProfile.initials, size: 88)
            Text(name.isEmpty ? "Ohne Namen" : name)
                .font(.system(.title2, design: .serif).weight(.semibold))
            Text(UserProfile.heightText)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.tight)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("profileHeader")
    }
}
