import SwiftUI
import UserNotifications

/// Whether iOS will deliver a notification at all.
///
/// Kept apart from the app's own switch: the two can disagree, and a screen that
/// showed only one of them would leave "An" standing while nothing ever arrives.
nonisolated enum NotificationAuthorisation: Equatable, Sendable {
    case unknown
    case notAsked
    case allowed
    case denied

    var isAllowed: Bool { self == .allowed }

    var shortText: String {
        switch self {
        case .unknown: "—"
        case .notAsked: "Noch nicht erlaubt"
        case .allowed: "Erlaubt"
        case .denied: "In iOS gesperrt"
        }
    }

    var explanation: String {
        switch self {
        case .unknown:
            "Der Status wird geprüft."
        case .notAsked:
            "iOS fragt beim nächsten Trainingsstart nach der Erlaubnis."
        case .allowed:
            "iOS darf Mitteilungen dieser App anzeigen."
        case .denied:
            "iOS blockiert Mitteilungen dieser App. Das lässt sich nur in den "
                + "iPhone-Einstellungen unter Mitteilungen ändern."
        }
    }

    @MainActor
    static func current(center: UNUserNotificationCenter = .current()) async -> NotificationAuthorisation {
        // Not asked under UI testing: the system prompt blocks every later tap,
        // and one of them once stalled a whole test run for seventeen minutes.
        guard !AppConfig.isUITesting else { return .allowed }
        switch await center.notificationSettings().authorizationStatus {
        case .notDetermined: return .notAsked
        case .denied: return .denied
        case .authorized, .provisional, .ephemeral: return .allowed
        @unknown default: return .unknown
        }
    }
}

/// The pause-timer notification: whether the app sends one, and whether iOS
/// would let it through.
struct NotificationSettingsView: View {
    @Binding var status: NotificationAuthorisation
    /// Held by the settings screen rather than read from `UserDefaults` here: a
    /// static read is invisible to SwiftUI, so the list behind this one went on
    /// showing "An" after the switch had been turned off.
    @Binding var wantsRestNotifications: Bool

    var body: some View {
        List {
            Section {
                Toggle("Pausenende melden", isOn: $wantsRestNotifications)
                    .accessibilityIdentifier("restNotificationsToggle")
                    .glassRow()
            } header: {
                Text("Pausentimer")
            } footer: {
                Text("Wenn die Pause abgelaufen ist, meldet sich die App — auch bei "
                     + "gesperrtem Bildschirm. Im Studio ist das meistens der einzige "
                     + "Weg, der dich erreicht.")
            }

            Section {
                LabeledContent("iOS-Erlaubnis", value: status.shortText)
                    .accessibilityIdentifier("notificationPermission")
                    .glassRow(status == .denied ? .first : .only)

                if status == .denied {
                    Button("iPhone-Einstellungen öffnen") { openSystemSettings() }
                        .accessibilityIdentifier("openSystemSettings")
                        .glassRow(.last)
                }
            } footer: {
                Text(status.explanation)
            }

            if wantsRestNotifications, status == .denied {
                Section {
                    Label(
                        "Der Schalter oben steht auf An, aber iOS lässt nichts durch.",
                        systemImage: "exclamationmark.triangle"
                    )
                    .font(.footnote)
                    .foregroundStyle(.orange)
                    .accessibilityIdentifier("notificationConflict")
                    .glassRow()
                }
            }
        }
        .glassFormBackground()
        .navigationTitle("Benachrichtigungen")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: wantsRestNotifications) { _, new in
            UserProfile.wantsRestNotifications = new
        }
        .task {
            status = await NotificationAuthorisation.current()
        }
    }

    private func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}
