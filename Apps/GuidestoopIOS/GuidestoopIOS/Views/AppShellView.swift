import SwiftUI
import SwiftData
import GuidestoopCore

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
    @AppStorage("guidestoop.appearance") private var appearanceRaw = AppearancePreference.system.rawValue

    @State private var selectedTab: AppTab = .list
    @State private var listFilterTab: TaskListTab = .all
    @State private var isListSearchPresented = false
    @State private var showConflicts = false

    private var appearance: AppearancePreference {
        AppearancePreference(rawValue: appearanceRaw) ?? .system
    }

    var body: some View {
        VStack(spacing: 0) {
            if conflictCount > 0 {
                ConflictBannerView(conflictCount: conflictCount) {
                    showConflicts = true
                }
            }

            headerBar

            tabContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            tabBar
        }
        .background(GuidestoopTheme.background)
        .foregroundStyle(GuidestoopTheme.textPrimary)
        .preferredColorScheme(appearance.colorScheme)
        .task {
            await appEnvironment.syncCoordinator.syncNow()
        }
        .sheet(isPresented: $showConflicts) {
            ConflictsListView()
                .environmentObject(appEnvironment)
        }
    }

    private var conflictCount: Int {
        appEnvironment.syncCoordinator.taskConflictPaths.count
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
            TasksListView(
                isSearchPresented: $isListSearchPresented,
                selectedTab: $listFilterTab
            )
        case .kanban:
            KanbanView()
        case .day:
            DayTimelineView()
        case .settings:
            SettingsView(onOpenTrash: openTrash)
        }
    }

    private func openTrash() {
        selectedTab = .list
        listFilterTab = .trash
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
