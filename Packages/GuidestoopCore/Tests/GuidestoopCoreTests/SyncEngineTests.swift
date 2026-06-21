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
        let adapter = InMemoryStorageAdapter(
            files: [SyncPaths.taskPath(id: remote.id): try TaskMarkdown.serialize(remote)]
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
        let adapter = InMemoryStorageAdapter(
            files: [SyncPaths.deletedTaskPath(id: expired.id): try TaskMarkdown.serializeDeleted(expired.asTask, deletedAt: expired.deletedAt)]
        )
        let engine = SyncEngine(adapter: adapter, now: Date(timeIntervalSince1970: 1_770_451_200)) // 2026-02-01

        let result = try engine.sync(
            localTasks: [],
            localDeletedTasks: [],
            localProjects: [],
            outbox: []
        )

        XCTAssertEqual(result.deletedTasks, [])
        XCTAssertNil(adapter.files[SyncPaths.deletedTaskPath(id: expired.id)])
        XCTAssertEqual(result.purgedFromTrash, 1)
    }

    func testMergeReplacesLocalListWithRemote() throws {
        let local = makeTask(id: "task-4", title: "Local", updated: "2026-06-21T08:00:00Z")
        let remote = makeTask(id: "task-4", title: "Remote", updated: "2026-06-21T10:00:00Z")
        let adapter = InMemoryStorageAdapter(
            files: [SyncPaths.taskPath(id: remote.id): try TaskMarkdown.serialize(remote)]
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

    init(files: [String: String] = [:]) {
        self.files = files
    }

    func listFiles() throws -> [SyncRemoteFile] {
        files.map { SyncRemoteFile(path: $0.key, content: $0.value) }
    }

    func write(path: String, content: String) throws {
        files[path] = content
    }

    func delete(path: String) throws {
        files[path] = nil
    }
}
