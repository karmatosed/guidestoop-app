import Foundation
import GuidestoopCore

@MainActor
final class LocalStore: ObservableObject {
    private let cacheURL: URL
    private var cache: LocalCacheFile

    init(cacheURL: URL? = nil) throws {
        let directory = URL.applicationSupportDirectory
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        self.cacheURL = cacheURL ?? directory.appending(path: "guidestoop-local-cache.json")
        self.cache = try Self.load(from: self.cacheURL)
    }

    func allCachedTasks() throws -> [Task] {
        cache.tasks
    }

    func allCachedDeletedTasks() throws -> [DeletedTask] {
        cache.deletedTasks
    }

    func replaceAll(
        tasks: [Task],
        projects: [Project],
        deletedTasks: [DeletedTask]
    ) throws {
        try applySyncResult(
            SyncResult(
                tasks: tasks,
                deletedTasks: deletedTasks,
                projects: projects,
                conflicts: [],
                purgedFromTrash: 0
            ),
            snapshot: LocalSnapshot(tasks: tasks, deletedTasks: deletedTasks, projects: projects, outbox: [])
        )
    }

    func applySyncResult(_ result: SyncResult, snapshot: LocalSnapshot, flushedOutboxIDs: Set<String> = []) throws {
        var next = cache
        let mergedTasks = mergeTasks(from: result, snapshot: snapshot, existing: next.tasks)
        let syncedTaskIds = Set(mergedTasks.map(\.id))
        let syncedDeletedIds = Set(result.deletedTasks.map(\.id))
        let syncedProjectIds = Set(result.projects.map(\.id))
        let snapshotTaskIds = Set(snapshot.tasks.map(\.id))
        let pendingTaskIds = Set(next.outbox.compactMap(\.taskId))
        let preservedTaskIds = syncedTaskIds.union(pendingTaskIds).union(snapshotTaskIds)

        next.tasks = mergedTasks.filter { preservedTaskIds.contains($0.id) }

        var deletedByID = Dictionary(uniqueKeysWithValues: next.deletedTasks.map { ($0.id, $0) })
        for deleted in result.deletedTasks {
            deletedByID[deleted.id] = deleted
        }
        next.deletedTasks = deletedByID.values.filter { syncedDeletedIds.contains($0.id) || pendingTaskIds.contains($0.id) }

        var projectsByID = Dictionary(uniqueKeysWithValues: next.projects.map { ($0.id, $0) })
        for project in result.projects {
            projectsByID[project.id] = project
        }
        next.projects = projectsByID.values.filter { syncedProjectIds.contains($0.id) }

        if !flushedOutboxIDs.isEmpty {
            next.outbox.removeAll { flushedOutboxIDs.contains($0.id) }
        }

        try persist(next)
    }

    private func mergeTasks(from result: SyncResult, snapshot: LocalSnapshot, existing: [Task]) -> [Task] {
        var byID = Dictionary(uniqueKeysWithValues: result.tasks.map { ($0.id, $0) })
        for task in snapshot.tasks where byID[task.id] == nil {
            byID[task.id] = task
        }
        for task in existing where byID[task.id] == nil {
            byID[task.id] = task
        }
        return byID.values.sorted { $0.id < $1.id }
    }

    func saveTask(_ task: Task) throws {
        var next = cache
        if let index = next.tasks.firstIndex(where: { $0.id == task.id }) {
            next.tasks[index] = task
        } else {
            next.tasks.append(task)
        }
        replaceOutbox(for: task.id, in: &next, with: .save(task))
        try persist(next)
    }

    func deleteTask(id taskId: String, deletedTask: DeletedTask? = nil) throws {
        var next = cache
        next.tasks.removeAll { $0.id == taskId }
        if let deletedTask {
            if let index = next.deletedTasks.firstIndex(where: { $0.id == deletedTask.id }) {
                next.deletedTasks[index] = deletedTask
            } else {
                next.deletedTasks.append(deletedTask)
            }
        }
        replaceOutbox(for: taskId, in: &next, with: .delete(id: taskId, deletedTask: deletedTask))
        try persist(next)
    }

    func restoreTask(_ task: Task) throws {
        var next = cache
        if let index = next.tasks.firstIndex(where: { $0.id == task.id }) {
            next.tasks[index] = task
        } else {
            next.tasks.append(task)
        }
        next.deletedTasks.removeAll { $0.id == task.id }
        replaceOutbox(for: task.id, in: &next, with: .restore(task))
        try persist(next)
    }

    func purgeTask(id taskId: String) throws {
        var next = cache
        next.deletedTasks.removeAll { $0.id == taskId }
        replaceOutbox(for: taskId, in: &next, with: .purge(id: taskId))
        try persist(next)
    }

    func pendingOutboxCount() throws -> Int {
        cache.outbox.count
    }

    func taskCount() throws -> Int {
        cache.tasks.count
    }

    func snapshot() throws -> LocalSnapshot {
        LocalSnapshot(
            tasks: cache.tasks.sorted { $0.id < $1.id },
            deletedTasks: cache.deletedTasks.sorted { $0.id < $1.id },
            projects: cache.projects.sorted { $0.id < $1.id },
            outbox: cache.outbox.map { OutboxSnapshotEntry(from: $0) }
        )
    }

    private func replaceOutbox(for taskId: String, in cache: inout LocalCacheFile, with operation: OutboxOperation) {
        cache.outbox.removeAll { $0.taskId == taskId }
        cache.outbox.append(CodableOutboxEntry(id: UUID().uuidString.lowercased(), operation: operation))
    }

    private func persist(_ next: LocalCacheFile) throws {
        cache = next
        let data = try JSONEncoder().encode(next)
        try data.write(to: cacheURL, options: .atomic)
    }

    private static func load(from url: URL) throws -> LocalCacheFile {
        let fm = FileManager.default
        guard fm.fileExists(atPath: url.path) else {
            return LocalCacheFile()
        }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(LocalCacheFile.self, from: data)
        } catch {
            let backup = url.deletingLastPathComponent()
                .appending(path: "guidestoop-local-cache.corrupt-\(Int(Date().timeIntervalSince1970)).json")
            try? fm.moveItem(at: url, to: backup)
            return LocalCacheFile()
        }
    }
}

struct OutboxSnapshotEntry: Sendable, Identifiable {
    var id: String
    var operation: OutboxOperation

    init(id: String, operation: OutboxOperation) {
        self.id = id
        self.operation = operation
    }

    fileprivate init(from codable: CodableOutboxEntry) {
        id = codable.id
        operation = codable.toOperation()
    }
}

struct LocalSnapshot: Sendable {
    var tasks: [Task]
    var deletedTasks: [DeletedTask]
    var projects: [Project]
    var outbox: [OutboxSnapshotEntry]

    var outboxOperations: [OutboxOperation] {
        outbox.map(\.operation)
    }
}

private struct LocalCacheFile: Codable {
    var tasks: [Task] = []
    var deletedTasks: [DeletedTask] = []
    var projects: [Project] = []
    var outbox: [CodableOutboxEntry] = []
}

private struct CodableOutboxEntry: Codable {
    var id: String
    var op: OutboxOp
    var taskId: String?
    var deletedTask: DeletedTask?

    init(id: String, operation: OutboxOperation) {
        self.id = id
        op = operation.op
        taskId = operation.taskId ?? operation.task?.id
        deletedTask = operation.deletedTask
    }

    func toOperation() -> OutboxOperation {
        OutboxOperation(op: op, task: nil, deletedTask: deletedTask, taskId: taskId)
    }
}
