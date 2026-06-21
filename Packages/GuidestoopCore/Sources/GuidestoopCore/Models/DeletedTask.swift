import Foundation

public struct DeletedTask: Codable, Identifiable, Equatable, Sendable {
    public var id: String
    public var title: String
    public var status: TaskStatus
    public var scheduled: String?
    public var duration: Int?
    public var project: String?
    public var tags: [String]
    public var highPriority: Bool = false
    public var created: String
    public var updated: String
    public var deletedAt: String
    public var body: String

    public init(
        id: String,
        title: String,
        status: TaskStatus,
        scheduled: String? = nil,
        duration: Int? = nil,
        project: String? = nil,
        tags: [String] = [],
        highPriority: Bool = false,
        created: String,
        updated: String,
        deletedAt: String,
        body: String = ""
    ) {
        self.id = id
        self.title = title
        self.status = status
        self.scheduled = scheduled
        self.duration = duration
        self.project = project
        self.tags = tags
        self.highPriority = highPriority
        self.created = created
        self.updated = updated
        self.deletedAt = deletedAt
        self.body = body
    }

    public var asTask: Task {
        Task(
            id: id, title: title, status: status,
            scheduled: scheduled, duration: duration,
            project: project, tags: tags, highPriority: highPriority,
            created: created, updated: updated, body: body
        )
    }
}
