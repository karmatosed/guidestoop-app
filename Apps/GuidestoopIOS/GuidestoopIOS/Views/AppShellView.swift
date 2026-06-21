import SwiftUI
import GuidestoopCore

private enum AppTab: String, CaseIterable, Identifiable {
    case now
    case list
    case day
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .now: return "Now"
        case .list: return "List"
        case .day: return "Day"
        case .settings: return "Settings"
        }
    }

    var icon: String {
        switch self {
        case .now: return "sun.max"
        case .list: return "list.bullet"
        case .day: return "calendar"
        case .settings: return "gearshape"
        }
    }
}

struct AppShellView: View {
    @EnvironmentObject private var appEnvironment: AppEnvironment

    @State private var selectedTab: AppTab = .now
    @State private var listFilterTab: TaskListTab = .all
    @State private var showConflicts = false

    var body: some View {
        TabView(selection: $selectedTab) {
            LazyTabContent(tab: AppTab.now, selectedTab: selectedTab) {
                NavigationStack {
                    NowView()
                }
            }
            .tabItem {
                Label(AppTab.now.title, systemImage: AppTab.now.icon)
            }
            .tag(AppTab.now)

            LazyTabContent(tab: AppTab.list, selectedTab: selectedTab) {
                NavigationStack {
                    TasksListView(selectedTab: $listFilterTab)
                }
            }
            .tabItem {
                Label(AppTab.list.title, systemImage: AppTab.list.icon)
            }
            .tag(AppTab.list)

            LazyTabContent(tab: AppTab.day, selectedTab: selectedTab) {
                NavigationStack {
                    DayTimelineView()
                        .navigationTitle("Day")
                        .navigationBarTitleDisplayMode(.large)
                }
            }
            .tabItem {
                Label(AppTab.day.title, systemImage: AppTab.day.icon)
            }
            .tag(AppTab.day)

            LazyTabContent(tab: AppTab.settings, selectedTab: selectedTab) {
                NavigationStack {
                    SettingsView(onOpenTrash: openTrash)
                        .navigationTitle("Settings")
                        .navigationBarTitleDisplayMode(.large)
                }
            }
            .tabItem {
                Label(AppTab.settings.title, systemImage: AppTab.settings.icon)
            }
            .tag(AppTab.settings)
        }
        .tint(GuidestoopTheme.textPrimary)
        .background(GuidestoopTheme.background)
        .safeAreaInset(edge: .top, spacing: 0) {
            if conflictCount > 0 {
                ConflictBannerView(conflictCount: conflictCount) {
                    showConflicts = true
                }
            }
        }
        .task {
            await Swift.Task.yield()
            appEnvironment.syncCoordinator.startWatchingFolderIfNeeded()
            // Defer first sync so the UI is interactive before reading iCloud files.
            try? await Swift.Task.sleep(nanoseconds: 2_000_000_000)
            appEnvironment.syncCoordinator.scheduleSync()
        }
        .sheet(isPresented: $showConflicts) {
            ConflictsListView()
                .environmentObject(appEnvironment)
        }
    }

    private var conflictCount: Int {
        appEnvironment.syncCoordinator.taskConflictPaths.count
    }

    private func openTrash() {
        selectedTab = .list
        listFilterTab = .trash
    }
}
