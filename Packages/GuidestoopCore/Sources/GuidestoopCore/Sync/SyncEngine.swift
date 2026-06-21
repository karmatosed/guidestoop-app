import Foundation
import Yams

public struct SyncRemoteFile: Sendable {
    public var path: String
    public var content: String

    public init(path: String, content: String) {
        self.path = path
        self.content = content
    }
}

public protocol SyncStorageAdapter: Sendable {
    func listFiles() throws -> [SyncRemoteFile]
    func write(path: String, content: String) throws
    func delete(path: String) throws
}

public struct SyncResult: Equatable, Sendable {
    public var tasks: [Task]
    public var deletedTasks: [DeletedTask]
    public var projects: [Project]
    public var conflicts: [String]
    public var purgedFromTrash: Int

    public init(
        tasks: [Task],
        deletedTasks: [DeletedTask],
        projects: [Project],
        conflicts: [String],
        purgedFromTrash: Int
    ) {
        self.tasks = tasks
        self.deletedTasks = deletedTasks
        self.projects = projects
        self.conflicts = conflicts
        self.purgedFromTrash = purgedFromTrash
    }
}

public enum SyncPaths {
    public static let tasksDir = "/tasks/"
    public static let deletedDir = "/tasks/deleted/"
    public static let projectsDir = "/projects/"

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
        try flushOutbox(outbox)

        let files = try adapter.listFiles().sorted { $0.path < $1.path }
        var taskMap = Dictionary(uniqueKeysWithValues: localTasks.map { ($0.id, $0) })
        var deletedMap = Dictionary(uniqueKeysWithValues: localDeletedTasks.map { ($0.id, $0) })
        var projectMap = Dictionary(uniqueKeysWithValues: localProjects.map { ($0.id, $0) })
        var remoteTasks: [String: Task] = [:]
        var remoteDeleted: [String: DeletedTask] = [:]
        var remoteProjects: [String: Project] = [:]
        var conflictPaths = Set<String>()

        for file in files {
            if SyncEngine.isConflictFile(file.path) {
                conflictPaths.insert(file.path)
                continue
            }

            if let task = try parseTask(from: file) {
                remoteTasks[task.id] = task
                if MergeLogic.shouldAcceptRemote(local: taskMap[task.id], remote: task) {
                    taskMap[task.id] = task
                }
                continue
            }

            if let deleted = try parseDeletedTask(from: file) {
                remoteDeleted[deleted.id] = deleted
                if let local = deletedMap[deleted.id] {
                    if deleted.deletedAt >= local.deletedAt {
                        deletedMap[deleted.id] = deleted
                    }
                } else {
                    deletedMap[deleted.id] = deleted
                }
                continue
            }

            if let project = try parseProject(from: file) {
                remoteProjects[project.id] = project
                if let local = projectMap[project.id] {
                    if project.updated >= local.updated {
                        projectMap[project.id] = project
                    }
                } else {
                    projectMap[project.id] = project
                }
            }
        }

        var purgedFromTrash = 0
        for deleted in deletedMap.values where TrashLogic.isTrashExpired(deletedAt: deleted.deletedAt, now: now) {
            try adapter.delete(path: SyncPaths.deletedTaskPath(id: deleted.id))
            deletedMap.removeValue(forKey: deleted.id)
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
            try adapter.write(path: SyncPaths.taskPath(id: local.id), content: try TaskMarkdown.serialize(local))
            taskMap[local.id] = local
        }

        for local in localDeletedTasks {
            if TrashLogic.isTrashExpired(deletedAt: local.deletedAt, now: now) {
                try adapter.delete(path: SyncPaths.deletedTaskPath(id: local.id))
                deletedMap.removeValue(forKey: local.id)
                purgedFromTrash += 1
                continue
            }
            if let remote = remoteDeleted[local.id], remote.deletedAt >= local.deletedAt {
                continue
            }
            let content = try TaskMarkdown.serializeDeleted(local.asTask, deletedAt: local.deletedAt)
            try adapter.write(path: SyncPaths.deletedTaskPath(id: local.id), content: content)
            deletedMap[local.id] = local
        }

        for local in localProjects {
            if let remote = remoteProjects[local.id], remote.updated >= local.updated {
                continue
            }
            try adapter.write(path: SyncPaths.projectPath(id: local.id), content: try ProjectMarkdown.serialize(local))
            projectMap[local.id] = local
        }

        return SyncResult(
            tasks: taskMap.values.sorted { $0.id < $1.id },
            deletedTasks: deletedMap.values.sorted { $0.id < $1.id },
            projects: projectMap.values.sorted { $0.id < $1.id },
            conflicts: conflictPaths.sorted(),
            purgedFromTrash: purgedFromTrash
        )
    }

    private func flushOutbox(_ outbox: [OutboxOperation]) throws {
        for operation in outbox {
            switch operation.op {
            case .save:
                guard let task = operation.task else { continue }
                try adapter.write(path: SyncPaths.taskPath(id: task.id), content: try TaskMarkdown.serialize(task))
            case .delete:
                guard let taskId = operation.taskId else { continue }
                try adapter.delete(path: SyncPaths.taskPath(id: taskId))
                if let deleted = operation.deletedTask {
                    let content = try TaskMarkdown.serializeDeleted(deleted.asTask, deletedAt: deleted.deletedAt)
                    try adapter.write(path: SyncPaths.deletedTaskPath(id: taskId), content: content)
                }
            case .restore:
                guard let task = operation.task else { continue }
                try adapter.write(path: SyncPaths.taskPath(id: task.id), content: try TaskMarkdown.serialize(task))
                try adapter.delete(path: SyncPaths.deletedTaskPath(id: task.id))
            case .purge:
                guard let taskId = operation.taskId else { continue }
                try adapter.delete(path: SyncPaths.deletedTaskPath(id: taskId))
            }
        }
    }

    private func parseTask(from file: SyncRemoteFile) throws -> Task? {
        guard SyncEngine.isTaskFile(file.path) else { return nil }
        return try TaskMarkdown.parse(file.content)
    }

    private func parseDeletedTask(from file: SyncRemoteFile) throws -> DeletedTask? {
        guard SyncEngine.isDeletedTaskFile(file.path) else { return nil }
        return try TaskMarkdown.parseDeleted(file.content)
    }

    private func parseProject(from file: SyncRemoteFile) throws -> Project? {
        guard SyncEngine.isProjectFile(file.path) else { return nil }
        return try ProjectMarkdown.parse(file.content)
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
