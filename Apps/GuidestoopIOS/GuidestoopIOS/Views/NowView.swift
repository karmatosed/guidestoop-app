import SwiftUI
import GuidestoopCore

struct NowView: View {
    @EnvironmentObject private var appEnvironment: AppEnvironment
    @EnvironmentObject private var energySettings: EnergySettings

    @State private var tasks: [Task] = []
    @State private var newTaskTitle = ""
    @State private var saveError: String?

    private var todayYmd: String {
        TaskFilters.localDateYmd()
    }

    private var taskLimit: Int {
        energySettings.todayTaskLimit
    }

    private var totalTodayCount: Int {
        TaskFilters.todayFocusCount(tasks, todayYmd: todayYmd)
    }

    private var visibleTasks: [Task] {
        TaskFilters.nowTasks(tasks, todayYmd: todayYmd, limit: taskLimit)
    }

    var body: some View {
        List {
            Section {
                Picker("Energy today", selection: energySettings.todayLevelBinding) {
                    ForEach(EnergyLevel.allCases) { level in
                        Text(level.title).tag(level)
                    }
                }
                .pickerStyle(.segmented)

                VStack(alignment: .leading, spacing: 4) {
                    Text(energySettings.todayLevel.subtitle)
                        .font(GuidestoopTypography.body)
                    Text(focusSummary)
                        .font(GuidestoopTypography.meta)
                        .foregroundStyle(totalTodayCount > taskLimit ? GuidestoopTheme.warning : GuidestoopTheme.textSecondary)
                }
            }

            Section("Focus") {
                if visibleTasks.isEmpty {
                    ContentUnavailableView {
                        Label("Nothing for today", systemImage: "sun.max")
                    } description: {
                        Text("Add a task below to start focusing.")
                            .font(GuidestoopTypography.meta)
                    }
                } else {
                    ForEach(visibleTasks) { task in
                        NavigationLink(value: task.id) {
                            TaskRowView(task: task) {
                                toggleDone(task)
                            }
                        }
                        .swipeActions(edge: .leading) {
                            Button {
                                toggleHighPriority(task)
                            } label: {
                                Label(
                                    task.highPriority ? "Remove priority" : "High priority",
                                    systemImage: task.highPriority ? "exclamationmark.circle.fill" : "exclamationmark.circle"
                                )
                            }
                            .tint(GuidestoopTheme.textPrimary)
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

            if totalTodayCount > visibleTasks.count {
                Section {
                    Text("\(totalTodayCount - visibleTasks.count) more task\(totalTodayCount - visibleTasks.count == 1 ? "" : "s") for today — raise energy or mark some done.")
                        .font(GuidestoopTypography.meta)
                        .foregroundStyle(GuidestoopTheme.textSecondary)
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(GuidestoopTheme.background)
        .navigationTitle("Now")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("g")
                    .font(GuidestoopTypography.logo)
                    .foregroundStyle(GuidestoopTheme.textPrimary)
            }
            ToolbarItem(placement: .topBarTrailing) {
                SyncToolbarButton(
                    isSyncing: appEnvironment.syncCoordinator.isSyncing,
                    outboxCount: appEnvironment.syncCoordinator.outboxCount
                ) {
                    Swift.Task { await appEnvironment.syncCoordinator.syncNow() }
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            AddTaskBar(text: $newTaskTitle) { title in
                addTask(title: title)
            }
        }
        .navigationDestination(for: String.self) { taskId in
            if let task = tasks.first(where: { $0.id == taskId }) {
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
            energySettings.refreshForNewDayIfNeeded()
            reloadTasks()
        }
        .onChange(of: appEnvironment.syncCoordinator.lastSyncedAt) { _, _ in
            reloadTasks()
        }
    }

    private var focusSummary: String {
        if totalTodayCount > taskLimit {
            return "\(visibleTasks.count) of \(taskLimit) shown · \(totalTodayCount) total for today"
        }
        if totalTodayCount == taskLimit {
            return "\(totalTodayCount) of \(taskLimit) tasks for today"
        }
        return "Up to \(taskLimit) tasks · \(totalTodayCount) for today"
    }

    private func reloadTasks() {
        tasks = (try? appEnvironment.localStore.allCachedTasks()) ?? []
    }

    private func addTask(title: String) {
        let task = TaskFactory.create(title: title, status: .focus)
        save(task)
    }

    private func toggleDone(_ task: Task) {
        var updated = task
        updated.status = task.status == .done ? .focus : .done
        updated.updated = ISO8601DateFormatter().string(from: Date())
        save(updated)
    }

    private func toggleHighPriority(_ task: Task) {
        var updated = task
        updated.highPriority.toggle()
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
            appEnvironment.syncCoordinator.noteLocalChange()
            reloadTasks()
        } catch {
            saveError = error.localizedDescription
        }
    }

    private func save(_ task: Task) {
        do {
            try appEnvironment.localStore.saveTask(task)
            appEnvironment.syncCoordinator.noteLocalChange()
            reloadTasks()
        } catch {
            saveError = error.localizedDescription
        }
    }
}
