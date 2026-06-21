import SwiftUI
import SwiftData

private enum AppTab: String, CaseIterable, Identifiable {
    case list
    case kanban
    case day
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .list: return "List"
        case .kanban: return "Kanban"
        case .day: return "Day"
        case .settings: return "Settings"
        }
    }

    var icon: String {
        switch self {
        case .list: return "list.bullet"
        case .kanban: return "rectangle.split.3x1"
        case .day: return "calendar"
        case .settings: return "gearshape"
        }
    }
}

struct AppShellView: View {
    @EnvironmentObject private var appEnvironment: AppEnvironment
    @State private var selectedTab: AppTab = .list
    @State private var isListSearchPresented = false

    var body: some View {
        VStack(spacing: 0) {
            if conflictCount > 0 {
                ConflictBannerView(conflictCount: conflictCount)
            }

            headerBar

            tabContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            tabBar
        }
        .background(GuidestoopTheme.background)
        .foregroundStyle(GuidestoopTheme.textPrimary)
        .preferredColorScheme(.dark)
        .task {
            await appEnvironment.syncCoordinator.syncNow()
        }
    }

    private var conflictCount: Int {
        appEnvironment.syncCoordinator.conflictPaths
            .filter { !$0.hasPrefix("sync-error:") && $0.contains(".conflict.") }
            .count
    }

    private var headerBar: some View {
        HStack {
            Text("g")
                .font(.system(size: 28, weight: .light, design: .serif))
                .foregroundStyle(GuidestoopTheme.textPrimary)

            Spacer()

            SyncStatusBadge(
                isSyncing: appEnvironment.syncCoordinator.isSyncing,
                outboxCount: appEnvironment.syncCoordinator.outboxCount,
                lastSyncedAt: appEnvironment.syncCoordinator.lastSyncedAt
            ) {
                Swift.Task {
                    await appEnvironment.syncCoordinator.syncNow()
                }
            }

            Button {
                selectedTab = .list
                isListSearchPresented = true
            } label: {
                Image(systemName: "magnifyingglass")
                    .font(.body.weight(.medium))
                    .foregroundStyle(GuidestoopTheme.textSecondary)
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(GuidestoopTheme.background)
    }

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .list:
            TasksListView(isSearchPresented: $isListSearchPresented)
        case .kanban:
            ShellPlaceholderView(title: "Kanban", subtitle: "Columns: inbox → done")
        case .day:
            ShellPlaceholderView(title: "Day", subtitle: "Timeline for scheduled tasks")
        case .settings:
            ShellSettingsPlaceholder(environment: appEnvironment)
        }
    }

    private var tabBar: some View {
        HStack {
            ForEach(AppTab.allCases) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 18))
                        Text(tab.title)
                            .font(.caption2)
                    }
                    .frame(maxWidth: .infinity)
                    .foregroundStyle(selectedTab == tab ? GuidestoopTheme.accent : GuidestoopTheme.textSecondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 8)
        .padding(.bottom, 4)
        .background(GuidestoopTheme.surface)
    }
}

private struct ShellPlaceholderView: View {
    let title: String
    let subtitle: String
    var taskCount: Int?

    var body: some View {
        VStack(spacing: 12) {
            Spacer()
            Text(title)
                .font(.title2.weight(.semibold))
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(GuidestoopTheme.textSecondary)
            if let taskCount {
                Text("\(taskCount) tasks synced")
                    .font(.caption)
                    .foregroundStyle(GuidestoopTheme.textSecondary)
                    .padding(.top, 4)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct ShellSettingsPlaceholder: View {
    @ObservedObject var environment: AppEnvironment

    var body: some View {
        List {
            Section("Storage") {
                LabeledContent("Provider", value: "iCloud Drive")
                Text(environment.folderURL.path)
                    .font(.caption)
                    .foregroundStyle(GuidestoopTheme.textSecondary)
            }

            Section("Sync") {
                Button("Sync now") {
                    Swift.Task { await environment.syncCoordinator.syncNow() }
                }
                if let lastSynced = environment.syncCoordinator.lastSyncedAt {
                    LabeledContent("Last synced") {
                        Text(lastSynced.formatted(date: .abbreviated, time: .shortened))
                    }
                }
                if environment.syncCoordinator.outboxCount > 0 {
                    LabeledContent("Pending", value: "\(environment.syncCoordinator.outboxCount)")
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(GuidestoopTheme.background)
    }
}

#Preview {
    if let environment = try? AppEnvironment(
        modelContext: try! ModelContainer(
            for: CachedTask.self,
            CachedProject.self,
            CachedDeletedTask.self,
            CachedOutboxEntry.self
        ).mainContext
    ) {
        AppShellView()
            .environmentObject(environment)
    }
}
