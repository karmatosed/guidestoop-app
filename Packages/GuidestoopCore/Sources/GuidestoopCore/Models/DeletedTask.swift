import Foundation

public struct DeletedTask: Codable, Identifiable, Equatable, Sendable {
    public var id: String
    public var title: String
    public var status: TaskStatus
    public var scheduled: String?
    public var duration: Int?
    public var project: String?
    public var tags: [String]
    public var created: String
    public var updated: String
    public var deletedAt: String
    public var body: String

    public var asTask: Task {
        Task(
            id: id, title: title, status: status,
            scheduled: scheduled, duration: duration,
            project: project, tags: tags,
            created: created, updated: updated, body: body
        )
    }
}
