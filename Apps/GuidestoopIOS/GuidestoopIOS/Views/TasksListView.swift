import SwiftUI
import SwiftData
import GuidestoopCore

struct TasksListView: View {
    @EnvironmentObject private var appEnvironment: AppEnvironment
    @Binding var isSearchPresented: Bool

    @Query(sort: \CachedTask.updated, order: .reverse) private var cachedTasks: [CachedTask]
    @Query(sort: \CachedDeletedTask.deletedAt, order: .reverse) private var cachedDeletedTasks: [CachedDeletedTask]

    @State private var selectedTab: TaskListTab = .all
    @State private var searchQuery = ""
    @State private var selectedTag: String?
    @State private var selectedTask: Task?
    @State private var saveError: String?

    init(isSearchPresented: Binding<Bool> = .constant(false)) {
        _isSearchPresented = isSearchPresented
    }

    private var allTasks: [Task] {
        cachedTasks.map { $0.toTask() }
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
        VStack(spacing: 0) {
            tabPicker

            if selectedTab != .trash, !availableTags.isEmpty {
                tagScroller
            }

            if selectedTab == .trash {
                trashList
            } else {
                taskList
            }
        }
        .searchable(text: $searchQuery, isPresented: $isSearchPresented, prompt: "Search tasks")
        .sheet(item: $selectedTask) { task in
            TaskDetailView(task: task)
        }
        .alert("Could not save", isPresented: Binding(
            get: { saveError != nil },
            set: { if !$0 { saveError = nil } }
        )) {
            Button("OK", role: .cancel) { saveError = nil }
        } message: {
            Text(saveError ?? "")
        }
    }

    private var tabPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(TaskListTab.allCases, id: \.self) { tab in
                    Button {
                        selectedTab = tab
                        if tab == .trash {
                            selectedTag = nil
                        }
                    } label: {
                        Text(tab.title)
                            .font(.subheadline.weight(selectedTab == tab ? .semibold : .regular))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(selectedTab == tab ? GuidestoopTheme.surface : Color.clear)
                            .foregroundStyle(selectedTab == tab ? GuidestoopTheme.textPrimary : GuidestoopTheme.textSecondary)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
    }

    private var tagScroller: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                TagChipView(tag: "All tags", isSelected: selectedTag == nil) {
                    selectedTag = nil
                }
                ForEach(availableTags, id: \.self) { tag in
                    TagChipView(tag: tag, isSelected: selectedTag == tag) {
                        selectedTag = selectedTag == tag ? nil : tag
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
    }

    private var taskList: some View {
        List {
            Section {
                QuickAddField { title in
                    addTask(title: title)
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }

            Section {
                if visibleTasks.isEmpty {
                    Text(emptyMessage)
                        .font(.subheadline)
                        .foregroundStyle(GuidestoopTheme.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .listRowBackground(Color.clear)
                } else {
                    ForEach(visibleTasks) { task in
                        TaskRowView(task: task) {
                            toggleDone(task)
                        }
                        .listRowBackground(Color.clear)
                        .listRowSeparatorTint(GuidestoopTheme.dashedBorder)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedTask = task
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
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(GuidestoopTheme.background)
    }

    private var trashList: some View {
        List {
            if cachedDeletedTasks.isEmpty {
                Text("Trash is empty")
                    .font(.subheadline)
                    .foregroundStyle(GuidestoopTheme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .listRowBackground(Color.clear)
            } else {
                ForEach(cachedDeletedTasks, id: \.id) { cached in
                    let deleted = cached.toDeletedTask()
                    DeletedTaskRowView(
                        deletedTask: deleted,
                        daysUntilPurge: TrashLogic.daysUntilPurge(deletedAt: deleted.deletedAt)
                    )
                    .listRowBackground(Color.clear)
                    .listRowSeparatorTint(GuidestoopTheme.dashedBorder)
                    .swipeActions(edge: .leading) {
                        Button {
                            restoreFromTrash(deleted)
                        } label: {
                            Label("Restore", systemImage: "arrow.uturn.backward")
                        }
                        .tint(GuidestoopTheme.accent)
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
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(GuidestoopTheme.background)
    }

    private var emptyMessage: String {
        if !searchQuery.isEmpty || selectedTag != nil {
            return "No tasks match your filters"
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

    private func addTask(title: String) {
        let task = TaskFactory.create(title: title)
        save(task)
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
            created: task.created,
            updated: task.updated,
            deletedAt: now,
            body: task.body
        )
        do {
            try appEnvironment.localStore.deleteTask(id: task.id, deletedTask: deleted)
            Swift.Task { await appEnvironment.syncCoordinator.syncNow() }
        } catch {
            saveError = error.localizedDescription
        }
    }

    private func restoreFromTrash(_ deleted: DeletedTask) {
        do {
            try appEnvironment.localStore.restoreTask(deleted.asTask)
            Swift.Task { await appEnvironment.syncCoordinator.syncNow() }
        } catch {
            saveError = error.localizedDescription
        }
    }

    private func purgeFromTrash(_ id: String) {
        do {
            try appEnvironment.localStore.purgeTask(id: id)
            Swift.Task { await appEnvironment.syncCoordinator.syncNow() }
        } catch {
            saveError = error.localizedDescription
        }
    }

    private func save(_ task: Task) {
        do {
            try appEnvironment.localStore.saveTask(task)
            Swift.Task { await appEnvironment.syncCoordinator.syncNow() }
        } catch {
            saveError = error.localizedDescription
        }
    }
}
