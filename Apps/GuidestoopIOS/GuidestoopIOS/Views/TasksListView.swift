import SwiftUI
import GuidestoopCore

private extension TaskListTab {
    var systemImage: String {
        switch self {
        case .all: return "square.grid.2x2"
        case .inbox: return "tray"
        case .blocked: return "hand.raised"
        case .today: return "sun.max"
        case .done: return "checkmark.circle"
        case .trash: return "trash"
        }
    }
}

struct TasksListView: View {
    @EnvironmentObject private var appEnvironment: AppEnvironment
    @Binding var selectedTab: TaskListTab

    @State private var tasks: [Task] = []
    @State private var deletedTasks: [DeletedTask] = []

    @State private var searchQuery = ""
    @State private var selectedTag: String?
    @State private var saveError: String?

    init(selectedTab: Binding<TaskListTab> = .constant(.all)) {
        _selectedTab = selectedTab
    }

    private var allTasks: [Task] {
        tasks
    }

    private var visibleTasks: [Task] {
        let todayYmd = TaskFilters.localDateYmd()
        var tasks = TaskFilters.filterByTab(allTasks, tab: selectedTab, todayYmd: todayYmd)
        tasks = TaskFilters.filterBySearch(tasks, query: searchQuery)
        tasks = TaskFilters.filterByTag(tasks, tag: selectedTag)
        return tasks.sorted { $0.updated > $1.updated }
    }

    private var availableTags: [String] {
        TaskFilters.allTags(allTasks)
    }

    var body: some View {
        Group {
            if selectedTab == .trash {
                trashList
            } else {
                taskList
            }
        }
        .background(GuidestoopTheme.background)
        .navigationTitle("Tasks")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("g")
                    .font(GuidestoopTypography.logo)
                    .foregroundStyle(GuidestoopTheme.textPrimary)
            }
            ToolbarItem(placement: .topBarLeading) {
                filterMenu
            }
            ToolbarItemGroup(placement: .topBarTrailing) {
                if selectedTab != .trash, !availableTags.isEmpty {
                    tagMenu
                }
                SyncToolbarButton(
                    isSyncing: appEnvironment.syncCoordinator.isSyncing,
                    outboxCount: appEnvironment.syncCoordinator.outboxCount
                ) {
                    Swift.Task { await appEnvironment.syncCoordinator.syncNow() }
                }
            }
        }
        .searchable(text: $searchQuery, prompt: "Search tasks")
        .navigationDestination(for: String.self) { taskId in
            if let task = allTasks.first(where: { $0.id == taskId }) {
                TaskDetailView(task: task)
                    .environmentObject(appEnvironment)
            }
        }
        .alert("Could not save", isPresented: Binding(
            get: { saveError != nil },
            set: { if !$0 { saveError = nil } }
        )) {
            Button("OK", role: .cancel) { saveError = nil }
        } message: {
            Text(saveError ?? "")
        }
        .task {
            reloadTasks()
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-TestAddTask") {
                runAddTaskSelfTest()
            }
            #endif
        }
        .onChange(of: appEnvironment.syncCoordinator.lastSyncedAt) { _, _ in
            reloadTasks()
        }
        .onChange(of: selectedTab) { _, tab in
            if tab == .trash {
                selectedTag = nil
            }
        }
    }

    #if DEBUG
    private func runAddTaskSelfTest() {
        let task = TaskFactory.create(title: "Self-test task")
        do {
            try appEnvironment.localStore.saveTask(task)
            reloadTasks()
            let storeCount = try appEnvironment.localStore.taskCount()
            let queryCount = tasks.count
            let pass = storeCount == 1 && queryCount == 1 && tasks.first?.title == "Self-test task"
            if pass {
                print("ADD_TASK_TEST_PASS storeCount=\(storeCount) queryCount=\(queryCount)")
            } else {
                print("ADD_TASK_TEST_FAIL storeCount=\(storeCount) queryCount=\(queryCount)")
            }
        } catch {
            print("ADD_TASK_TEST_FAIL \(error.localizedDescription)")
        }
    }
    #endif

    private func reloadTasks() {
        let store = appEnvironment.localStore
        tasks = (try? store.allCachedTasks()) ?? []
        deletedTasks = (try? store.allCachedDeletedTasks()) ?? []
    }

    private var filterMenu: some View {
        Menu {
            Picker("Filter", selection: $selectedTab) {
                ForEach(TaskListTab.allCases, id: \.self) { tab in
                    Label(tab.title, systemImage: tab.systemImage).tag(tab)
                }
            }
        } label: {
            Label(selectedTab.title, systemImage: selectedTab.systemImage)
                .font(GuidestoopTypography.meta)
        }
    }

    private var tagMenu: some View {
        Menu {
            Picker("Tag", selection: $selectedTag) {
                Text("All tags").tag(String?.none)
                ForEach(availableTags, id: \.self) { tag in
                    Text(tag).tag(Optional(tag))
                }
            }
        } label: {
            Label(selectedTag ?? "Tags", systemImage: "tag")
                .font(GuidestoopTypography.meta)
        }
    }

    private var taskList: some View {
        List {
            if visibleTasks.isEmpty {
                ContentUnavailableView {
                    Label(emptyMessage, systemImage: "tray")
                } description: {
                    Text("Add tasks from the Now tab.")
                        .font(GuidestoopTypography.meta)
                }
            } else {
                ForEach(visibleTasks) { task in
                    NavigationLink(value: task.id) {
                        TaskRowView(task: task) {
                            toggleDone(task)
                        }
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            moveToTrash(task)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
    }

    private var trashList: some View {
        List {
            if deletedTasks.isEmpty {
                ContentUnavailableView {
                    Label("Trash is empty", systemImage: "trash")
                }
            } else {
                ForEach(deletedTasks, id: \.id) { deleted in
                    DeletedTaskRowView(
                        deletedTask: deleted,
                        daysUntilPurge: TrashLogic.daysUntilPurge(deletedAt: deleted.deletedAt)
                    )
                    .swipeActions(edge: .leading) {
                        Button {
                            restoreFromTrash(deleted)
                        } label: {
                            Label("Restore", systemImage: "arrow.uturn.backward")
                        }
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            purgeFromTrash(deleted.id)
                        } label: {
                            Label("Delete forever", systemImage: "trash")
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
    }

    private var emptyMessage: String {
        if !searchQuery.isEmpty || selectedTag != nil {
            return "No matching tasks"
        }
        switch selectedTab {
        case .all: return "No tasks yet"
        case .inbox: return "Inbox is clear"
        case .blocked: return "Nothing blocked"
        case .today: return "Nothing for today"
        case .done: return "No completed tasks"
        case .trash: return "Trash is empty"
        }
    }

    private func toggleDone(_ task: Task) {
        var updated = task
        updated.status = task.status == .done ? .inbox : .done
        updated.updated = ISO8601DateFormatter().string(from: Date())
        save(updated)
    }

    private func moveToTrash(_ task: Task) {
        let now = ISO8601DateFormatter().string(from: Date())
        let deleted = DeletedTask(
            id: task.id,
            title: task.title,
            status: task.status,
            scheduled: task.scheduled,
            duration: task.duration,
            project: task.project,
            tags: task.tags,
            highPriority: task.highPriority,
            created: task.created,
            updated: task.updated,
            deletedAt: now,
            body: task.body
        )
        do {
            try appEnvironment.localStore.deleteTask(id: task.id, deletedTask: deleted)
            reloadTasks()
            appEnvironment.syncCoordinator.noteLocalChange()
        } catch {
            saveError = error.localizedDescription
        }
    }

    private func restoreFromTrash(_ deleted: DeletedTask) {
        do {
            try appEnvironment.localStore.restoreTask(deleted.asTask)
            reloadTasks()
            appEnvironment.syncCoordinator.noteLocalChange()
        } catch {
            saveError = error.localizedDescription
        }
    }

    private func purgeFromTrash(_ id: String) {
        do {
            try appEnvironment.localStore.purgeTask(id: id)
            reloadTasks()
            appEnvironment.syncCoordinator.noteLocalChange()
        } catch {
            saveError = error.localizedDescription
        }
    }

    private func save(_ task: Task) {
        do {
            try appEnvironment.localStore.saveTask(task)
            reloadTasks()
            appEnvironment.syncCoordinator.noteLocalChange()
        } catch {
            saveError = error.localizedDescription
        }
    }
}
