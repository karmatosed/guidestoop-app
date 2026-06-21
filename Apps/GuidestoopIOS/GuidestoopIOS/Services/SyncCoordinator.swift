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

    init(localStore: LocalStore, folderURL: URL) {
        self.localStore = localStore
        self.folderURL = folderURL
        self.outboxCount = (try? localStore.pendingOutboxCount()) ?? 0
    }

    func syncNow() async {
        guard !isSyncing else { return }
        isSyncing = true
        defer { isSyncing = false }

        do {
            let snapshot = try localStore.snapshot()
            let syncResult = try await Swift.Task.detached(priority: Swift.TaskPriority.userInitiated) { [folderURL = self.folderURL] () throws -> SyncResult in
                let adapter = SyncICloudAdapter(rootURL: folderURL)
                try adapter.ensureFolderStructure()
                let engine = SyncEngine(adapter: adapter)
                return try engine.sync(
                    localTasks: snapshot.tasks,
                    localDeletedTasks: snapshot.deletedTasks,
                    localProjects: snapshot.projects,
                    outbox: snapshot.outbox
                )
            }.value

            try localStore.replaceAll(
                tasks: syncResult.tasks,
                projects: syncResult.projects,
                deletedTasks: syncResult.deletedTasks
            )
            conflictPaths = syncResult.conflicts
            lastSyncedAt = Date()
            outboxCount = try localStore.pendingOutboxCount()
        } catch {
            conflictPaths = ["sync-error:\(error.localizedDescription)"]
            outboxCount = (try? localStore.pendingOutboxCount()) ?? 0
        }
    }
}

private final class SyncICloudAdapter: SyncStorageAdapter, @unchecked Sendable {
    private let adapter: ICloudAdapter

    init(rootURL: URL) {
        self.adapter = ICloudAdapter(rootURL: rootURL)
    }

    func ensureFolderStructure() throws {
        try runBlocking {
            try await self.adapter.ensureFolderStructure()
        }
    }

    func listFiles() throws -> [SyncRemoteFile] {
        let files = try runBlocking {
            try await self.adapter.listFiles()
        }
        return files.map { file in
            SyncRemoteFile(path: file.path, content: file.content)
        }
    }

    func write(path: String, content: String) throws {
        try runBlocking {
            try await self.adapter.write(path: path, content: content)
        }
    }

    func delete(path: String) throws {
        try runBlocking {
            try await self.adapter.delete(path: path)
        }
    }

    private func runBlocking<T: Sendable>(_ operation: @escaping @Sendable () async throws -> T) throws -> T {
        let semaphore = DispatchSemaphore(value: 0)
        var result: Result<T, Error>?

        Swift.Task.detached(priority: Swift.TaskPriority.userInitiated) {
            defer { semaphore.signal() }
            do {
                result = .success(try await operation())
            } catch {
                result = .failure(error)
            }
        }

        semaphore.wait()
        guard let result else {
            throw StorageError.readFailed("No result returned from storage operation")
        }
        return try result.get()
    }
}
