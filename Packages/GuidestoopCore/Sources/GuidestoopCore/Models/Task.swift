import Foundation

public struct Task: Codable, Identifiable, Equatable, Sendable {
    public var id: String
    public var title: String
    public var status: TaskStatus
    public var scheduled: String?
    public var duration: Int?
    public var project: String?
    public var tags: [String]
    public var created: String
    public var updated: String
    public var body: String

    public init(
        id: String,
        title: String,
        status: TaskStatus,
        scheduled: String? = nil,
        duration: Int? = nil,
        project: String? = nil,
        tags: [String] = [],
        created: String,
        updated: String,
        body: String = ""
    ) {
        self.id = id
        self.title = title
        self.status = status
        self.scheduled = scheduled
        self.duration = duration
        self.project = project
        self.tags = tags
        self.created = created
        self.updated = updated
        self.body = body
    }
}
