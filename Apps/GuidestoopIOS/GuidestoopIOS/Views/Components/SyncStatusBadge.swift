import SwiftUI

struct SyncToolbarButton: View {
    let isSyncing: Bool
    let outboxCount: Int
    let onSync: () -> Void

    var body: some View {
        Group {
            if outboxCount > 0, !isSyncing {
                syncButton.badge(outboxCount)
            } else {
                syncButton
            }
        }
    }

    @ViewBuilder
    private var syncButton: some View {
        if isSyncing {
            ProgressView()
                .controlSize(.small)
                .accessibilityLabel("Syncing")
        } else {
            Button(action: onSync) {
                Label("Sync", systemImage: syncSymbol)
            }
            .labelStyle(.iconOnly)
            .accessibilityLabel(accessibilityLabel)
        }
    }

    private var syncSymbol: String {
        if outboxCount > 0 {
            return "icloud.and.arrow.up"
        }
        return "checkmark.icloud"
    }

    private var accessibilityLabel: String {
        if outboxCount > 0 { return "\(outboxCount) pending changes, sync now" }
        return "Synced, tap to refresh"
    }
}
