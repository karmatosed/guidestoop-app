import Foundation
import SwiftData
import GuidestoopCore

@MainActor
final class LocalStore {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func replaceAll(
        tasks: [Task],
        projects: [Project],
        deletedTasks: [DeletedTask]
    ) throws {
        try deleteAll(CachedTask.self)
        try deleteAll(CachedProject.self)
        try deleteAll(CachedDeletedTask.self)
        try deleteAll(CachedOutboxEntry.self)

        tasks.map(CachedTask.from).forEach(modelContext.insert)
        projects.map(CachedProject.from).forEach(modelContext.insert)
        deletedTasks.map(CachedDeletedTask.from).forEach(modelContext.insert)

        try modelContext.save()
    }

    func saveTask(_ task: Task) throws {
        try upsertTask(task)

        enqueue(.save(task))
        try modelContext.save()
    }

    func deleteTask(id taskId: String, deletedTask: DeletedTask? = nil) throws {
        if let existing = try fetchCachedTask(id: taskId) {
            modelContext.delete(existing)
        }

        if let deletedTask {
            if let existingDeleted = try fetchCachedDeletedTask(id: deletedTask.id) {
                existingDeleted.title = deletedTask.title
                existingDeleted.statusRawValue = deletedTask.status.rawValue
                existingDeleted.scheduled = deletedTask.scheduled
                existingDeleted.duration = deletedTask.duration
                existingDeleted.project = deletedTask.project
                existingDeleted.tags = deletedTask.tags
                existingDeleted.created = deletedTask.created
                existingDeleted.updated = deletedTask.updated
                existingDeleted.deletedAt = deletedTask.deletedAt
                existingDeleted.body = deletedTask.body
            } else {
                modelContext.insert(CachedDeletedTask.from(deletedTask))
            }
        }

        enqueue(.delete(id: taskId, deletedTask: deletedTask))
        try modelContext.save()
    }

    func restoreTask(_ task: Task) throws {
        try upsertTask(task)

        if let deleted = try fetchCachedDeletedTask(id: task.id) {
            modelContext.delete(deleted)
        }

        enqueue(.restore(task))
        try modelContext.save()
    }

    func purgeTask(id taskId: String) throws {
        if let deleted = try fetchCachedDeletedTask(id: taskId) {
            modelContext.delete(deleted)
        }

        enqueue(.purge(id: taskId))
        try modelContext.save()
    }

    func pendingOutboxCount() throws -> Int {
        let descriptor = FetchDescriptor<CachedOutboxEntry>()
        return try modelContext.fetchCount(descriptor)
    }

    func taskCount() throws -> Int {
        let descriptor = FetchDescriptor<CachedTask>()
        return try modelContext.fetchCount(descriptor)
    }

    func snapshot() throws -> LocalSnapshot {
        let tasks = try modelContext.fetch(FetchDescriptor<CachedTask>())
            .map { $0.toTask() }
            .sorted { $0.id < $1.id }
        let projects = try modelContext.fetch(FetchDescriptor<CachedProject>())
            .map { $0.toProject() }
            .sorted { $0.id < $1.id }
        let deletedTasks = try modelContext.fetch(FetchDescriptor<CachedDeletedTask>())
            .map { $0.toDeletedTask() }
            .sorted { $0.id < $1.id }
        let outboxEntries = try modelContext.fetch(
            FetchDescriptor<CachedOutboxEntry>(
                sortBy: [SortDescriptor(\.createdAt, order: .forward)]
            )
        )
        let outbox = outboxEntries.compactMap { $0.toOperation() }
        return LocalSnapshot(tasks: tasks, deletedTasks: deletedTasks, projects: projects, outbox: outbox)
    }

    private func enqueue(_ operation: OutboxOperation) {
        modelContext.insert(CachedOutboxEntry.from(operation))
    }

    private func upsertTask(_ task: Task) throws {
        if let existing = try fetchCachedTask(id: task.id) {
            existing.title = task.title
            existing.statusRawValue = task.status.rawValue
            existing.scheduled = task.scheduled
            existing.duration = task.duration
            existing.project = task.project
            existing.tags = task.tags
            existing.created = task.created
            existing.updated = task.updated
            existing.body = task.body
            return
        }
        modelContext.insert(CachedTask.from(task))
    }

    private func deleteAll<T: PersistentModel>(_ type: T.Type) throws {
        let records = try modelContext.fetch(FetchDescriptor<T>())
        records.forEach(modelContext.delete)
    }

    private func fetchCachedTask(id: String) throws -> CachedTask? {
        let predicate = #Predicate<CachedTask> { $0.id == id }
        let descriptor = FetchDescriptor<CachedTask>(predicate: predicate)
        return try modelContext.fetch(descriptor).first
    }

    private func fetchCachedDeletedTask(id: String) throws -> CachedDeletedTask? {
        let predicate = #Predicate<CachedDeletedTask> { $0.id == id }
        let descriptor = FetchDescriptor<CachedDeletedTask>(predicate: predicate)
        return try modelContext.fetch(descriptor).first
    }
}

struct LocalSnapshot: Sendable {
    var tasks: [Task]
    var deletedTasks: [DeletedTask]
    var projects: [Project]
    var outbox: [OutboxOperation]
}
