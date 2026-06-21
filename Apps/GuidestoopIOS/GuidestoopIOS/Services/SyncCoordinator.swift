import Foundation
import GuidestoopCore
import GuidestoopStorage

@MainActor
final class SyncCoordinator: ObservableObject {
    @Published var lastSyncedAt: Date?
    @Published var isSyncing = false
    @Published var outboxCount = 0
    @Published var conflictPaths: [String] = []

    private let localStore: LocalStore
    private let folderURL: URL
    private var folderWatcher: ICloudFolderWatcher?
    private var pendingSync = false
    private var scheduledSyncTask: Swift.Task<Void, Never>?
    private var suppressWatcher = false

    init(localStore: LocalStore, folderURL: URL) {
        self.localStore = localStore
        self.folderURL = folderURL
        self.outboxCount = (try? localStore.pendingOutboxCount()) ?? 0
    }

    func startWatchingFolderIfNeeded() {
        guard folderWatcher == nil else { return }
        folderWatcher = ICloudFolderWatcher(folderURL: folderURL) { [weak self] in
            guard let self else { return }
            Swift.Task { @MainActor in
                guard !self.suppressWatcher else { return }
                await self.syncNow()
            }
        }
    }

    func noteLocalChange() {
        outboxCount = (try? localStore.pendingOutboxCount()) ?? outboxCount
        scheduleSync()
    }

    func scheduleSync() {
        scheduledSyncTask?.cancel()
        scheduledSyncTask = Swift.Task { @MainActor in
            try? await Swift.Task.sleep(nanoseconds: 1_000_000_000)
            guard !Swift.Task.isCancelled else { return }
            await syncNow()
        }
    }

    func syncNow() async {
        if isSyncing {
            pendingSync = true
            return
        }

        var iterations = 0
        repeat {
            pendingSync = false
            iterations += 1
            isSyncing = true
            suppressWatcher = true
            defer {
                isSyncing = false
                suppressWatcher = false
            }

            do {
                let snapshot = try localStore.snapshot()
                let flushedOutboxIDs = Set(snapshot.outbox.map(\.id))
                let syncResult = try await Self.runSync(
                    folderURL: folderURL,
                    snapshot: snapshot
                )

                try localStore.applySyncResult(
                    syncResult,
                    snapshot: snapshot,
                    flushedOutboxIDs: flushedOutboxIDs
                )
                conflictPaths = syncResult.conflicts
                lastSyncedAt = Date()
                outboxCount = try localStore.pendingOutboxCount()
            } catch {
                conflictPaths = ["sync-error:\(error.localizedDescription)"]
                outboxCount = (try? localStore.pendingOutboxCount()) ?? 0
                return
            }
        } while pendingSync && iterations < 3
    }

    private static func runSync(folderURL: URL, snapshot: LocalSnapshot) async throws -> SyncResult {
        let folder = folderURL
        let tasks = snapshot.tasks
        let deletedTasks = snapshot.deletedTasks
        let projects = snapshot.projects
        let outbox = snapshot.outboxOperations

        return try await Swift.Task.detached(priority: .userInitiated) {
            let adapter = DirectSyncStorageAdapter(rootURL: folder)
            try adapter.ensureFolderStructure()
            let engine = SyncEngine(adapter: adapter)
            return try engine.sync(
                localTasks: tasks,
                localDeletedTasks: deletedTasks,
                localProjects: projects,
                outbox: outbox
            )
        }.value
    }

    var taskConflictPaths: [String] {
        conflictPaths.filter { $0.contains(".conflict.") && !$0.hasPrefix("sync-error:") }
    }

    func loadConflict(at conflictPath: String) async throws -> ConflictInfo {
        guard let taskId = ConflictPathParser.taskId(fromConflictPath: conflictPath) else {
            throw StorageError.readFailed("Invalid conflict path")
        }
        let adapter = ICloudAdapter(rootURL: folderURL)
        let localRaw = try await adapter.read(path: conflictPath)
        let remoteRaw = try await adapter.read(path: SyncPaths.taskPath(id: taskId))
        return ConflictInfo(
            conflictPath: conflictPath,
            taskId: taskId,
            localTask: try TaskMarkdown.parse(localRaw),
            remoteTask: try TaskMarkdown.parse(remoteRaw)
        )
    }

    func resolveConflict(at conflictPath: String, keepLocal: Bool) async throws {
        guard let taskId = ConflictPathParser.taskId(fromConflictPath: conflictPath) else {
            throw StorageError.readFailed("Invalid conflict path")
        }
        let adapter = ICloudAdapter(rootURL: folderURL)
        if keepLocal {
            let localRaw = try await adapter.read(path: conflictPath)
            let task = try TaskMarkdown.parse(localRaw)
            var updated = task
            updated.updated = ISO8601DateFormatter().string(from: Date())
            let content = try TaskMarkdown.serialize(updated)
            try await adapter.write(path: SyncPaths.taskPath(id: taskId), content: content)
            try localStore.saveTask(updated)
        }
        try await adapter.delete(path: conflictPath)
        await syncNow()
    }
}
