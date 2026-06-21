import SwiftUI
import SwiftData
import GuidestoopCore

private let kanbanColumns: [TaskStatus] = [.inbox, .blocked, .focus, .scheduled, .done]

struct KanbanView: View {
    @EnvironmentObject private var appEnvironment: AppEnvironment
    @Query(sort: \CachedTask.updated, order: .reverse) private var cachedTasks: [CachedTask]

    @State private var saveError: String?

    private var allTasks: [Task] {
        cachedTasks.map { $0.toTask() }
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 12) {
                ForEach(kanbanColumns, id: \.self) { status in
                    KanbanColumnView(
                        status: status,
                        tasks: allTasks.filter { $0.status == status },
                        onAdd: { title in addTask(title: title, status: status) },
                        onDropTaskId: { taskId in
                            moveTask(id: taskId, to: status)
                            return true
                        }
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(GuidestoopTheme.background)
        .alert("Could not save", isPresented: Binding(
            get: { saveError != nil },
            set: { if !$0 { saveError = nil } }
        )) {
            Button("OK", role: .cancel) { saveError = nil }
        } message: {
            Text(saveError ?? "")
        }
    }

    private func addTask(title: String, status: TaskStatus) {
        let task = TaskFactory.create(title: title, status: status)
        save(task)
    }

    private func moveTask(id: String, to status: TaskStatus) {
        guard var task = allTasks.first(where: { $0.id == id }) else { return }
        guard task.status != status else { return }
        task.status = status
        task.updated = ISO8601DateFormatter().string(from: Date())
        save(task)
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

private struct KanbanColumnView: View {
    let status: TaskStatus
    let tasks: [Task]
    let onAdd: (String) -> Void
    let onDropTaskId: (String) -> Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(status.rawValue.capitalized)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(GuidestoopTheme.textPrimary)

            Text("\(tasks.count)")
                .font(.caption)
                .foregroundStyle(GuidestoopTheme.textSecondary)

            QuickAddField(placeholder: "Add…") { title in
                onAdd(title)
            }

            ScrollView {
                VStack(spacing: 8) {
                    ForEach(tasks) { task in
                        KanbanCardView(task: task)
                            .draggable(task.id)
                    }
                }
            }
        }
        .frame(width: 220)
        .padding(12)
        .background(GuidestoopTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .dropDestination(for: String.self) { items, _ in
            guard let taskId = items.first else { return false }
            return onDropTaskId(taskId)
        }
    }
}

private struct KanbanCardView: View {
    let task: Task

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(task.title)
                .font(.subheadline)
                .foregroundStyle(GuidestoopTheme.textPrimary)
                .lineLimit(3)

            if let project = task.project, !project.isEmpty {
                Text(project)
                    .font(.caption2)
                    .foregroundStyle(GuidestoopTheme.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(GuidestoopTheme.background)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(GuidestoopTheme.dashedBorder, lineWidth: 1)
        }
    }
}
