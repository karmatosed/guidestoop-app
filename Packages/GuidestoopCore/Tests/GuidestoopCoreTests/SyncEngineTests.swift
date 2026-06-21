import XCTest
@testable import GuidestoopCore

final class SyncEngineTests: XCTestCase {
    func testFlushOutboxWritesPendingSave() throws {
        let task = makeTask(id: "task-1", title: "Draft", updated: "2026-06-21T08:00:00Z")
        let adapter = InMemoryStorageAdapter()
        let engine = SyncEngine(adapter: adapter)

        _ = try engine.sync(
            localTasks: [task],
            localDeletedTasks: [],
            localProjects: [],
            outbox: [.save(task)]
        )

        XCTAssertEqual(adapter.files[SyncPaths.taskPath(id: task.id)], try TaskMarkdown.serialize(task))
    }

    func testRemoteNewerDifferentCreatesConflictFile() throws {
        let local = makeTask(id: "task-2", title: "Local edit", updated: "2026-06-21T08:00:00Z")
        let remote = makeTask(id: "task-2", title: "Remote edit", updated: "2026-06-21T09:00:00Z")
        let path = SyncPaths.taskPath(id: remote.id)
        let adapter = InMemoryStorageAdapter(
            files: [path: try TaskMarkdown.serialize(remote)],
            modifiedAt: [path: Date(timeIntervalSince1970: 1_710_000_000)]
        )
        let engine = SyncEngine(adapter: adapter)

        let result = try engine.sync(
            localTasks: [local],
            localDeletedTasks: [],
            localProjects: [],
            outbox: []
        )

        XCTAssertEqual(result.tasks, [remote])
        XCTAssertEqual(result.conflicts.count, 1)
        XCTAssertTrue(result.conflicts[0].contains(".conflict."))
        XCTAssertEqual(adapter.files[result.conflicts[0]], try TaskMarkdown.serialize(local))
    }

    func testExpiredTrashPurged() throws {
        let expired = DeletedTask(
            id: "task-3",
            title: "Expired",
            status: .done,
            created: "2026-01-01T10:00:00.000Z",
            updated: "2026-01-01T10:00:00.000Z",
            deletedAt: "2026-01-01T10:00:00.000Z"
        )
        let path = SyncPaths.deletedTaskPath(id: expired.id)
        let adapter = InMemoryStorageAdapter(
            files: [path: try TaskMarkdown.serializeDeleted(expired.asTask, deletedAt: expired.deletedAt)],
            modifiedAt: [path: Date(timeIntervalSince1970: 1_700_000_000)]
        )
        let engine = SyncEngine(adapter: adapter, now: Date(timeIntervalSince1970: 1_770_451_200))

        let result = try engine.sync(
            localTasks: [],
            localDeletedTasks: [],
            localProjects: [],
            outbox: []
        )

        XCTAssertEqual(result.deletedTasks, [])
        XCTAssertNil(adapter.files[path])
        XCTAssertEqual(result.purgedFromTrash, 1)
    }

    func testMergeReplacesLocalListWithRemote() throws {
        let local = makeTask(id: "task-4", title: "Local", updated: "2026-06-21T08:00:00Z")
        let remote = makeTask(id: "task-4", title: "Remote", updated: "2026-06-21T10:00:00Z")
        let path = SyncPaths.taskPath(id: remote.id)
        let adapter = InMemoryStorageAdapter(
            files: [path: try TaskMarkdown.serialize(remote)],
            modifiedAt: [path: Date(timeIntervalSince1970: 1_710_000_000)]
        )
        let engine = SyncEngine(adapter: adapter)

        let result = try engine.sync(
            localTasks: [local],
            localDeletedTasks: [],
            localProjects: [],
            outbox: []
        )

        XCTAssertEqual(result.tasks, [remote])
    }

    func testIncrementalSyncSkipsUnchangedFiles() throws {
        let unchangedDate = Date(timeIntervalSince1970: 1_700_000_000)
        let changedDate = Date(timeIntervalSince1970: 1_800_000_000)
        var files: [String: String] = [:]
        var modifiedAt: [String: Date] = [:]
        var manifest: [String: FileManifestEntry] = [:]
        var localTasks: [Task] = []

        for index in 0..<100 {
            let id = String(format: "task-%03d", index)
            let task = makeTask(id: id, title: "Task \(index)", updated: "2026-06-21T08:00:00Z")
            let path = SyncPaths.taskPath(id: id)
            files[path] = try TaskMarkdown.serialize(task)
            localTasks.append(task)
            let modDate = index < 3 ? changedDate : unchangedDate
            modifiedAt[path] = modDate
            manifest[path] = FileManifestEntry(
                updated: task.updated,
                modifiedAt: SyncEngine.formatManifestDate(unchangedDate)
            )
        }

        let adapter = InMemoryStorageAdapter(
            files: files,
            modifiedAt: modifiedAt,
            meta: SyncMeta(files: manifest)
        )
        let engine = SyncEngine(adapter: adapter)

        let result = try engine.sync(
            localTasks: localTasks,
            localDeletedTasks: [],
            localProjects: [],
            outbox: []
        )

        XCTAssertEqual(result.tasks.count, 100)
        XCTAssertEqual(result.filesRead, 3)
        XCTAssertEqual(adapter.readCount, 3)
    }

    func testLocalOnlyTaskPushedToRemote() throws {
        let local = makeTask(id: "new-task", title: "Only local", updated: "2026-06-21T08:00:00Z")
        let adapter = InMemoryStorageAdapter(meta: SyncMeta())
        let engine = SyncEngine(adapter: adapter)

        let result = try engine.sync(
            localTasks: [local],
            localDeletedTasks: [],
            localProjects: [],
            outbox: []
        )

        XCTAssertEqual(result.tasks, [local])
        XCTAssertNotNil(adapter.files[SyncPaths.taskPath(id: local.id)])
    }

    private func makeTask(id: String, title: String, updated: String) -> Task {
        Task(
            id: id,
            title: title,
            status: .inbox,
            created: "2026-06-21T07:00:00Z",
            updated: updated
        )
    }
}

private final class InMemoryStorageAdapter: SyncStorageAdapter, @unchecked Sendable {
    var files: [String: String]
    var modifiedAt: [String: Date]
    var meta: SyncMeta
    var readCount = 0

    init(
        files: [String: String] = [:],
        modifiedAt: [String: Date] = [:],
        meta: SyncMeta = SyncMeta()
    ) {
        self.files = files
        self.modifiedAt = modifiedAt
        self.meta = meta
        for path in files.keys where modifiedAt[path] == nil {
            self.modifiedAt[path] = Date(timeIntervalSince1970: 1_710_000_000)
        }
    }

    func ensureFolderStructure() throws {}

    func listFileMetadata() throws -> [SyncFileMetadata] {
        files.keys.sorted().map { path in
            SyncFileMetadata(path: path, modifiedAt: modifiedAt[path], size: files[path]?.utf8.count)
        }
    }

    func read(path: String) throws -> String {
        readCount += 1
        guard let content = files[path] else {
            throw TaskMarkdownError.missingFrontmatter
        }
        return content
    }

    func write(path: String, content: String) throws {
        files[path] = content
        modifiedAt[path] = Date()
    }

    func delete(path: String) throws {
        files[path] = nil
        modifiedAt[path] = nil
    }

    func readMeta() throws -> SyncMeta {
        meta
    }

    func writeMeta(_ meta: SyncMeta) throws {
        self.meta = meta
    }
}
