import SwiftData
import SwiftUI

/// Profile, appearance, notifications and user-managed data.
///
/// Reached from the account button rather than from a tab. A tab is for
/// something you visit during a workout; settings are something you visit twice
/// a year, and it was taking a fifth of the tab bar.
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @Query private var measurements: [BodyMeasurement]
    @Query private var sessions: [WorkoutSession]
    @State private var name = UserProfile.name
    @State private var notificationStatus: NotificationAuthorisation = .unknown
    @State private var wantsNotifications = UserProfile.wantsRestNotifications
    @Binding var appearance: AppAppearance

    var body: some View {
        NavigationStack {
            List {
                Section {
                    FieldGuidePageTitle(title: "Einstellungen")
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
                Section {
                    NavigationLink {
                        ProfileView(name: $name)
                    } label: {
                        profileRow
                    }
                    .accessibilityIdentifier("openProfile")
                    .glassRow()
                }

                Section {
                    row(
                        "Erscheinungsbild",
                        systemImage: appearance.symbol,
                        detail: appearance.displayName,
                        identifier: "openAppearance"
                    ) {
                        AppearanceSettingsView(appearance: $appearance)
                    }
                    .glassRow(.first)

                    row(
                        "Benachrichtigungen",
                        systemImage: "bell.badge",
                        detail: notificationDetail,
                        identifier: "openNotifications"
                    ) {
                        NotificationSettingsView(
                            status: $notificationStatus,
                            wantsRestNotifications: $wantsNotifications
                        )
                    }
                    .glassRow(.middle)

                    row(
                        "Daten",
                        systemImage: "square.and.arrow.up",
                        detail: dataDetail,
                        identifier: "openData"
                    ) {
                        DataView()
                    }
                    .glassRow(.last)
                } header: {
                    Text("Allgemein")
                } footer: {
                    Text("Deine Daten bleiben auf diesem Gerät. Export und Import findest du unter „Daten“.")
                }
            }
            .glassFormBackground()
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fertig") { dismiss() }
                        .accessibilityIdentifier("closeSettings")
                }
            }
            .task {
                notificationStatus = await NotificationAuthorisation.current()
            }
        }
    }

    private var profileRow: some View {
        HStack(spacing: Theme.Spacing.regular) {
            AccountAvatar(initials: UserProfile.initials, size: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text(name.isEmpty ? "Dein Profil" : name)
                    .font(.headline)
                Text(profileDetail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: Theme.Spacing.tight)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }

    private var profileDetail: String {
        var parts = [UserProfile.heightText]
        if let age = UserProfile.ageText(birthday: UserProfile.birthday) {
            parts.append(age)
        }
        return parts.joined(separator: " · ")
    }

    private var notificationDetail: String {
        guard wantsNotifications else { return "Aus" }
        return notificationStatus.isAllowed ? "An" : notificationStatus.shortText
    }

    private var dataDetail: String {
        "\(sessions.count) Trainings · \(measurements.count) Messungen"
    }

    private func row<Destination: View>(
        _ title: String,
        systemImage: String,
        detail: String,
        identifier: String,
        @ViewBuilder destination: @escaping () -> Destination
    ) -> some View {
        NavigationLink {
            destination()
        } label: {
            HStack(spacing: Theme.Spacing.regular) {
                Image(systemName: systemImage)
                    .font(.footnote)
                    .foregroundStyle(.tint)
                    .frame(width: 28, height: 28)
                Text(title)
                Spacer(minLength: Theme.Spacing.tight)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityIdentifier(identifier)
    }
}

/// The circle with the initials, used in the toolbar and at the top of settings.
struct AccountAvatar: View {
    let initials: String
    var size: CGFloat = 30

    var body: some View {
        Circle()
            .fill(.tint.opacity(0.22))
            .overlay {
                if initials.isEmpty {
                    // A placeholder letter would look like somebody else's account.
                    Image(systemName: "person.fill")
                        .font(.system(size: size * 0.45))
                        .foregroundStyle(.tint)
                } else {
                    Text(initials)
                        .font(.system(size: size * 0.42, weight: .semibold))
                        .foregroundStyle(.tint)
                }
            }
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}
