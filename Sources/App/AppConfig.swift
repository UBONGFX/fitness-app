import Foundation

/// Feature flags for capabilities that depend on device entitlements.
enum AppConfig {
    /// True while a UI test drives the app. Used to keep system permission
    /// dialogs out of the way — one of them blocked a whole test run for
    /// seventeen minutes before it timed out.
    static var isUITesting: Bool {
        ProcessInfo.processInfo.arguments.contains("-uiTesting")
    }

    /// Requires the CloudKit entitlement and a paid developer program membership.
    static let cloudKitSyncEnabled = false

    /// The HealthKit entitlement is in place. Authorization
    /// still fails on a simulator build made with `CODE_SIGNING_ALLOWED=NO`,
    /// because stripping the signature strips the entitlement with it — the UI
    /// reports that rather than crashing.
    static let healthKitEnabled = true
}
