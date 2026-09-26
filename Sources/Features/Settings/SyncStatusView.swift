import SwiftUI

/// Where the data actually is.
///
/// Says "Nicht aktiv" rather than borrowing the reference design's green
/// "Verbunden": nothing is syncing, and a status screen that reports a cloud
/// which does not exist is worse than no status screen at all — it is exactly
/// the screen someone checks before trusting their history to it.
struct SyncStatusView: View {
    let state: SyncState

    var body: some View {
        List {
            Section {
                LabeledContent("Status") {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(state.isHealthy ? Color.green : Color.secondary)
                            .frame(width: 8, height: 8)
                        Text(state.title)
                    }
                }
                .accessibilityIdentifier("syncStatus")
                .accessibilityLabel("Status")
                .accessibilityValue(state.title)
                .glassRow(lastSync == nil ? .only : .first)

                if let lastSync {
                    LabeledContent("Letzte Synchronisation", value: lastSync)
                        .accessibilityIdentifier("lastSync")
                        .glassRow(.last)
                }
            } footer: {
                Text(SyncStatus.explanation(for: state))
            }

            if !state.isHealthy {
                Section {
                    Text(SyncStatus.fallbackAdvice)
                        .font(.footnote)
                        .accessibilityIdentifier("syncFallback")
                        .glassRow()
                } header: {
                    Text("Sicherung")
                }
            }
        }
        .glassFormBackground()
        .navigationTitle("iCloud-Sync")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var lastSync: String? { SyncStatus.lastSyncText(state) }
}
