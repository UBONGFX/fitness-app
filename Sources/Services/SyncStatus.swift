import Foundation

/// What the sync screen is allowed to claim.
///
/// The reference design shows "Verbunden" with a timestamp. This app cannot say
/// that truthfully: CloudKit needs an entitlement that a free Personal Team does
/// not grant, so nothing is syncing anywhere. Reporting a green "connected"
/// would be the single most misleading thing in the app — someone would trust
/// their training history to a cloud that does not exist.
///
/// So the state is derived from what is actually configured, and the wording
/// says where the data really is.
nonisolated enum SyncState: Equatable, Sendable {
    /// The entitlement is missing; everything lives on this device only.
    case unavailable
    /// Configured and syncing.
    case active(lastSync: Date?)
    /// Configured, but iCloud itself is not usable right now.
    case signedOut

    var title: String {
        switch self {
        case .unavailable: "Nicht aktiv"
        case .active: "Verbunden"
        case .signedOut: "Nicht angemeldet"
        }
    }

    var isHealthy: Bool {
        if case .active = self { return true }
        return false
    }
}

nonisolated enum SyncStatus {
    /// What this build can actually do. A separate entry point from
    /// `current(cloudKitEnabled:)` so the tests can drive both states without the
    /// flag reaching into them.
    @MainActor
    static var configured: SyncState { current(cloudKitEnabled: AppConfig.cloudKitSyncEnabled) }

    /// The single source of truth for the screen.
    ///
    /// Derived from the build flag rather than from a probe: without the
    /// entitlement there is no CloudKit container to ask, and a failed probe
    /// would report a network problem instead of a missing capability.
    static func current(cloudKitEnabled: Bool, lastSync: Date? = nil) -> SyncState {
        guard cloudKitEnabled else { return .unavailable }
        return .active(lastSync: lastSync)
    }

    /// Plain language, no jargon, and no promise that is not kept.
    static func explanation(for state: SyncState) -> String {
        switch state {
        case .unavailable:
            "Deine Daten liegen ausschließlich auf diesem iPhone. "
                + "Für die iCloud-Synchronisation braucht die App eine Berechtigung, "
                + "die nur ein kostenpflichtiges Apple-Developer-Programm vergibt."
        case .active(let lastSync):
            if let lastSync {
                "Zuletzt synchronisiert am \(lastSync.formatted(date: .abbreviated, time: .shortened))."
            } else {
                "Verbunden. Die erste Synchronisation läuft, sobald Daten anfallen."
            }
        case .signedOut:
            "Melde dich in den iPhone-Einstellungen bei iCloud an, "
                + "damit die App synchronisieren kann."
        }
    }

    /// What to do instead, while there is no sync.
    ///
    /// Not a consolation prize: the JSON export is a complete backup and the only
    /// thing standing between the user and a lost training history.
    static var fallbackAdvice: String {
        "Bis dahin ist der JSON-Export deine Sicherung — er enthält alles: Pläne, "
            + "Trainings, Messungen und Ziele."
    }

    static func lastSyncText(_ state: SyncState) -> String? {
        guard case .active(let lastSync) = state, let lastSync else { return nil }
        return lastSync.formatted(date: .numeric, time: .shortened)
    }
}
