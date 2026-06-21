import Foundation
import Yams

public protocol SyncStorageAdapter: Sendable {
    func ensureFolderStructure() throws
    func listFileMetadata() throws -> [SyncFileMetadata]
    func read(path: String) throws -> String
    func write(path: String, content: String) throws
    func delete(path: String) throws
    func readMeta() throws -> SyncMeta
    func writeMeta(_ meta: SyncMeta) throws
}

public struct SyncResult: Equatable, Sendable {
    public var tasks: [Task]
    public var deletedTasks: [DeletedTask]
    public var projects: [Project]
    public var conflicts: [String]
    public var purgedFromTrash: Int
    public var filesRead: Int

    public init(
        tasks: [Task],
        deletedTasks: [DeletedTask],
        projects: [Project],
        conflicts: [String],
        purgedFromTrash: Int,
        filesRead: Int = 0
    ) {
        self.tasks = tasks
        self.deletedTasks = deletedTasks
        self.projects = projects
        self.conflicts = conflicts
        self.purgedFromTrash = purgedFromTrash
        self.filesRead = filesRead
    }
}

public enum SyncPaths {
    public static let tasksDir = "/tasks/"
    public static let deletedDir = "/tasks/deleted/"
    public static let projectsDir = "/projects/"
    public static let metaFile = "/_meta/guidestoop.json"

    public static func taskPath(id: String) -> String {
        "\(tasksDir)\(id).md"
    }

    public static func deletedTaskPath(id: String) -> String {
        "\(deletedDir)\(id).md"
    }

    public static func projectPath(id: String) -> String {
        let slug = id.replacingOccurrences(of: "^proj-", with: "", options: .regularExpression)
        return "\(projectsDir)\(slug).md"
    }

    public static func conflictPath(id: String, updated: String) -> String {
        "\(tasksDir)\(MergeLogic.conflictFilename(id: id, timestamp: updated))"
    }
}

public struct SyncEngine {
    private let adapter: SyncStorageAdapter
    private let now: Date

    public init(adapter: SyncStorageAdapter, now: Date = Date()) {
        self.adapter = adapter
        self.now = now
    }

    public func sync(
        localTasks: [Task],
        localDeletedTasks: [DeletedTask],
        localProjects: [Project],
        outbox: [OutboxOperation]
    ) throws -> SyncResult {
        try flushOutbox(outbox, localTasks: localTasks, localDeletedTasks: localDeletedTasks)

        var meta = try adapter.readMeta()
        var manifest = meta.files
        let metadata = try adapter.listFileMetadata().sorted { $0.path < $1.path }

        var taskMap = Dictionary(uniqueKeysWithValues: localTasks.map { ($0.id, $0) })
        var deletedMap = Dictionary(uniqueKeysWithValues: localDeletedTasks.map { ($0.id, $0) })
        var projectMap = Dictionary(uniqueKeysWithValues: localProjects.map { ($0.id, $0) })
        var remoteTasks: [String: Task] = [:]
        var remoteDeleted: [String: DeletedTask] = [:]
        var remoteProjects: [String: Project] = [:]
        var conflictPaths = Set<String>()
        var filesRead = 0

        var remoteTaskPaths = Set<String>()
        var remoteDeletedPaths = Set<String>()
        var remoteProjectPaths = Set<String>()

        for entry in metadata {
            if SyncEngine.isConflictFile(entry.path) {
                conflictPaths.insert(entry.path)
                continue
            }

            if SyncEngine.isTaskFile(entry.path) {
                remoteTaskPaths.insert(entry.path)
                guard let id = SyncEngine.taskIdFromPath(entry.path) else { continue }
                let local = taskMap[id]
                if shouldReadFile(entry: entry, manifestEntry: manifest[entry.path], hasLocal: local != nil) {
                    let raw = try adapter.read(path: entry.path)
                    filesRead += 1
                    let remote = try TaskMarkdown.parse(raw)
                    remoteTasks[remote.id] = remote
                    if MergeLogic.shouldAcceptRemote(local: taskMap[remote.id], remote: remote) {
                        taskMap[remote.id] = remote
                    }
                    manifest[entry.path] = manifestEntry(for: remote.updated, entry: entry)
                } else if let local {
                    remoteTasks[id] = local
                }
                continue
            }

            if SyncEngine.isDeletedTaskFile(entry.path) {
                remoteDeletedPaths.insert(entry.path)
                guard let id = SyncEngine.taskIdFromDeletedPath(entry.path) else { continue }
                let local = deletedMap[id]
                if shouldReadFile(entry: entry, manifestEntry: manifest[entry.path], hasLocal: local != nil) {
                    let raw = try adapter.read(path: entry.path)
                    filesRead += 1
                    let remote = try TaskMarkdown.parseDeleted(raw)
                    remoteDeleted[remote.id] = remote
                    if let local {
                        if remote.deletedAt >= local.deletedAt {
                            deletedMap[remote.id] = remote
                        }
                    } else {
                        deletedMap[remote.id] = remote
                    }
                    manifest[entry.path] = manifestEntry(for: remote.updated, entry: entry)
                } else if let local {
                    remoteDeleted[id] = local
                }
                continue
            }

            if SyncEngine.isProjectFile(entry.path) {
                remoteProjectPaths.insert(entry.path)
                guard let id = SyncEngine.projectIdFromPath(entry.path) else { continue }
                let local = projectMap[id]
                if shouldReadFile(entry: entry, manifestEntry: manifest[entry.path], hasLocal: local != nil) {
                    let raw = try adapter.read(path: entry.path)
                    filesRead += 1
                    let remote = try ProjectMarkdown.parse(raw)
                    remoteProjects[remote.id] = remote
                    if let local {
                        if remote.updated >= local.updated {
                            projectMap[remote.id] = remote
                        }
                    } else {
                        projectMap[remote.id] = remote
                    }
                    manifest[entry.path] = manifestEntry(for: remote.updated, entry: entry)
                } else if let local {
                    remoteProjects[id] = local
                }
            }
        }

        reconcileDeletions(in: &taskMap, remotePaths: remoteTaskPaths, pathForId: SyncPaths.taskPath)
        reconcileDeletions(in: &deletedMap, remotePaths: remoteDeletedPaths, pathForId: SyncPaths.deletedTaskPath)
        reconcileDeletions(in: &projectMap, remotePaths: remoteProjectPaths, pathForId: SyncPaths.projectPath)

        var purgedFromTrash = 0
        for deleted in deletedMap.values where TrashLogic.isTrashExpired(deletedAt: deleted.deletedAt, now: now) {
            let path = SyncPaths.deletedTaskPath(id: deleted.id)
            try adapter.delete(path: path)
            deletedMap.removeValue(forKey: deleted.id)
            manifest.removeValue(forKey: path)
            purgedFromTrash += 1
        }

        for local in localTasks {
            if let remote = remoteTasks[local.id] {
                if try TaskMarkdown.contentEqual(local, remote) {
                    continue
                }
                if remote.updated > local.updated && MergeLogic.shouldAcceptRemote(local: local, remote: remote) {
                    let path = SyncPaths.conflictPath(id: local.id, updated: local.updated)
                    try adapter.write(path: path, content: try TaskMarkdown.serialize(local))
                    conflictPaths.insert(path)
                    continue
                }
            }
            let path = SyncPaths.taskPath(id: local.id)
            let content = try TaskMarkdown.serialize(local)
            try adapter.write(path: path, content: content)
            taskMap[local.id] = local
            manifest[path] = manifestEntry(for: local.updated, size: content.utf8.count)
        }

        for local in localDeletedTasks {
            if TrashLogic.isTrashExpired(deletedAt: local.deletedAt, now: now) {
                let path = SyncPaths.deletedTaskPath(id: local.id)
                try adapter.delete(path: path)
                deletedMap.removeValue(forKey: local.id)
                manifest.removeValue(forKey: path)
                purgedFromTrash += 1
                continue
            }
            if let remote = remoteDeleted[local.id], remote.deletedAt >= local.deletedAt {
                continue
            }
            let path = SyncPaths.deletedTaskPath(id: local.id)
            let content = try TaskMarkdown.serializeDeleted(local.asTask, deletedAt: local.deletedAt)
            try adapter.write(path: path, content: content)
            deletedMap[local.id] = local
            manifest[path] = manifestEntry(for: local.updated, size: content.utf8.count)
        }

        for local in localProjects {
            if let remote = remoteProjects[local.id], remote.updated >= local.updated {
                continue
            }
            let path = SyncPaths.projectPath(id: local.id)
            let content = try ProjectMarkdown.serialize(local)
            try adapter.write(path: path, content: content)
            projectMap[local.id] = local
            manifest[path] = manifestEntry(for: local.updated, size: content.utf8.count)
        }

        meta.files = manifest
        meta.lastSyncedAt = SyncEngine.isoFormatter.string(from: now)
        try adapter.writeMeta(meta)

        return SyncResult(
            tasks: taskMap.values.sorted { $0.id < $1.id },
            deletedTasks: deletedMap.values.sorted { $0.id < $1.id },
            projects: projectMap.values.sorted { $0.id < $1.id },
            conflicts: conflictPaths.sorted(),
            purgedFromTrash: purgedFromTrash,
            filesRead: filesRead
        )
    }

    private func shouldReadFile(
        entry: SyncFileMetadata,
        manifestEntry: FileManifestEntry?,
        hasLocal: Bool
    ) -> Bool {
        if !hasLocal { return true }
        guard let manifestEntry else { return true }
        guard let modifiedAt = entry.modifiedAt else { return true }
        guard let lastModified = SyncEngine.parseManifestDate(manifestEntry.modifiedAt) else { return true }
        return modifiedAt > lastModified
    }

    private func manifestEntry(for updated: String, entry: SyncFileMetadata) -> FileManifestEntry {
        FileManifestEntry(
            updated: updated,
            modifiedAt: SyncEngine.formatManifestDate(entry.modifiedAt ?? now),
            size: entry.size
        )
    }

    private func manifestEntry(for updated: String, size: Int) -> FileManifestEntry {
        FileManifestEntry(
            updated: updated,
            modifiedAt: SyncEngine.formatManifestDate(now),
            size: size
        )
    }

    private func reconcileDeletions<T>(
        in map: inout [String: T],
        remotePaths: Set<String>,
        pathForId: (String) -> String
    ) {
        for id in Array(map.keys) where !remotePaths.contains(pathForId(id)) {
            map.removeValue(forKey: id)
        }
    }

    private func flushOutbox(
        _ outbox: [OutboxOperation],
        localTasks: [Task],
        localDeletedTasks: [DeletedTask]
    ) throws {
        for operation in outbox {
            switch operation.op {
            case .save:
                guard let taskId = operation.taskId else { continue }
                guard let task = operation.task ?? localTasks.first(where: { $0.id == taskId }) else { continue }
                try adapter.write(path: SyncPaths.taskPath(id: task.id), content: try TaskMarkdown.serialize(task))
            case .delete:
                guard let taskId = operation.taskId else { continue }
                try adapter.delete(path: SyncPaths.taskPath(id: taskId))
                if let deleted = operation.deletedTask ?? localDeletedTasks.first(where: { $0.id == taskId }) {
                    let content = try TaskMarkdown.serializeDeleted(deleted.asTask, deletedAt: deleted.deletedAt)
                    try adapter.write(path: SyncPaths.deletedTaskPath(id: taskId), content: content)
                }
            case .restore:
                guard let taskId = operation.taskId else { continue }
                guard let task = operation.task ?? localTasks.first(where: { $0.id == taskId }) else { continue }
                try adapter.write(path: SyncPaths.taskPath(id: task.id), content: try TaskMarkdown.serialize(task))
                try adapter.delete(path: SyncPaths.deletedTaskPath(id: task.id))
            case .purge:
                guard let taskId = operation.taskId else { continue }
                try adapter.delete(path: SyncPaths.deletedTaskPath(id: taskId))
            }
        }
    }

    static func taskIdFromPath(_ path: String) -> String? {
        guard isTaskFile(path) else { return nil }
        let name = path.dropFirst(SyncPaths.tasksDir.count)
        guard name.hasSuffix(".md") else { return nil }
        return String(name.dropLast(3))
    }

    static func taskIdFromDeletedPath(_ path: String) -> String? {
        guard isDeletedTaskFile(path) else { return nil }
        let name = path.dropFirst(SyncPaths.deletedDir.count)
        guard name.hasSuffix(".md") else { return nil }
        return String(name.dropLast(3))
    }

    static func projectIdFromPath(_ path: String) -> String? {
        guard isProjectFile(path) else { return nil }
        let name = path.dropFirst(SyncPaths.projectsDir.count)
        guard name.hasSuffix(".md") else { return nil }
        return "proj-\(name.dropLast(3))"
    }

    private static func isTaskFile(_ path: String) -> Bool {
        path.hasPrefix(SyncPaths.tasksDir)
            && path.hasSuffix(".md")
            && !path.hasPrefix(SyncPaths.deletedDir)
            && !isConflictFile(path)
    }

    private static func isDeletedTaskFile(_ path: String) -> Bool {
        path.hasPrefix(SyncPaths.deletedDir) && path.hasSuffix(".md")
    }

    private static func isProjectFile(_ path: String) -> Bool {
        path.hasPrefix(SyncPaths.projectsDir) && path.hasSuffix(".md")
    }

    private static func isConflictFile(_ path: String) -> Bool {
        path.contains(".conflict.")
    }

    private static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    static func formatManifestDate(_ date: Date) -> String {
        isoFormatter.string(from: date)
    }

    static func parseManifestDate(_ value: String) -> Date? {
        isoFormatter.date(from: value) ?? ISO8601DateFormatter().date(from: value)
    }
}

private enum ProjectMarkdown {
    private static let frontmatterRegex = try! NSRegularExpression(
        pattern: #"^---\r?\n([\s\S]*?)\r?\n---(?:\r?\n([\s\S]*))?$"#
    )

    static func parse(_ raw: String) throws -> Project {
        let (data, body) = try splitFrontmatter(raw)
        return Project(
            id: try requireString(data["id"], field: "id"),
            name: try requireString(data["name"], field: "name"),
            color: optionalString(data["color"]),
            created: try requireString(data["created"], field: "created"),
            updated: try requireString(data["updated"], field: "updated"),
            body: normalizeBody(body)
        )
    }

    static func serialize(_ project: Project) throws -> String {
        var frontmatter: [String: Any] = [
            "id": project.id,
            "name": project.name,
            "created": project.created,
            "updated": project.updated,
        ]
        if let color = project.color {
            frontmatter["color"] = color
        }
        let yaml = try Yams.dump(object: frontmatter, allowUnicode: true)
        let body = project.body.isEmpty ? "" : "\n\(project.body)"
        return "---\n\(yaml.trimmingCharacters(in: .whitespacesAndNewlines))\n---\(body)\n"
    }

    private static func splitFrontmatter(_ raw: String) throws -> ([String: Any], String) {
        let range = NSRange(raw.startIndex..., in: raw)
        guard let match = frontmatterRegex.firstMatch(in: raw, range: range),
              let frontmatterRange = Range(match.range(at: 1), in: raw) else {
            throw TaskMarkdownError.missingFrontmatter
        }
        let contentRange = match.range(at: 2).location != NSNotFound
            ? Range(match.range(at: 2), in: raw)!
            : raw.endIndex..<raw.endIndex
        guard let loaded = try Yams.load(yaml: String(raw[frontmatterRange])) as? [String: Any] else {
            throw TaskMarkdownError.invalidFrontmatter
        }
        return (loaded, String(raw[contentRange]))
    }

    private static func requireString(_ value: Any?, field: String) throws -> String {
        if let string = value as? String, !string.trimmingCharacters(in: .whitespaces).isEmpty {
            return string
        }
        throw TaskMarkdownError.missingField(field)
    }

    private static func optionalString(_ value: Any?) -> String? {
        guard let string = value as? String else { return nil }
        return string.isEmpty ? nil : string
    }

    private static func normalizeBody(_ content: String) -> String {
        var normalized = content
        if normalized.hasPrefix("\n") {
            normalized.removeFirst()
        }
        return normalized
            .trimmingCharacters(in: .newlines)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\r\n", with: "\n")
    }
}
