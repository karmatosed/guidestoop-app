import SwiftUI

struct SyncStatusBadge: View {
    let isSyncing: Bool
    let outboxCount: Int
    let lastSyncedAt: Date?
    let onSync: () -> Void

    var body: some View {
        Button(action: onSync) {
            HStack(spacing: 6) {
                if isSyncing {
                    ProgressView()
                        .controlSize(.small)
                } else if outboxCount > 0 {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.caption)
                    Text("\(outboxCount)")
                        .font(.caption2.weight(.medium))
                } else {
                    Image(systemName: "checkmark.circle")
                        .font(.caption)
                        .foregroundStyle(GuidestoopTheme.accent.opacity(0.8))
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(GuidestoopTheme.surface)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        if isSyncing { return "Syncing" }
        if outboxCount > 0 { return "\(outboxCount) pending changes, tap to sync" }
        if let lastSyncedAt {
            return "Synced \(lastSyncedAt.formatted(date: .omitted, time: .shortened))"
        }
        return "Tap to sync"
    }
}
