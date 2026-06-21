import Foundation
import SwiftData
import GuidestoopCore

@Model
final class CachedTask {
    @Attribute(.unique) var id: String
    var title: String
    var statusRawValue: String
    var scheduled: String?
    var duration: Int?
    var project: String?
    var tagsJSON: String
    var created: String
    var updated: String
    var body: String

    init(
        id: String,
        title: String,
        statusRawValue: String,
        scheduled: String?,
        duration: Int?,
        project: String?,
        tagsJSON: String,
        created: String,
        updated: String,
        body: String
    ) {
        self.id = id
        self.title = title
        self.statusRawValue = statusRawValue
        self.scheduled = scheduled
        self.duration = duration
        self.project = project
        self.tagsJSON = tagsJSON
        self.created = created
        self.updated = updated
        self.body = body
    }

    var status: TaskStatus {
        TaskStatus(rawValue: statusRawValue) ?? .inbox
    }

    var tags: [String] {
        get { Self.decodeTags(tagsJSON) }
        set { tagsJSON = Self.encodeTags(newValue) }
    }

    func toTask() -> Task {
        Task(
            id: id,
            title: title,
            status: status,
            scheduled: scheduled,
            duration: duration,
            project: project,
            tags: tags,
            created: created,
            updated: updated,
            body: body
        )
    }

    static func from(_ task: Task) -> CachedTask {
        CachedTask(
            id: task.id,
            title: task.title,
            statusRawValue: task.status.rawValue,
            scheduled: task.scheduled,
            duration: task.duration,
            project: task.project,
            tagsJSON: Self.encodeTags(task.tags),
            created: task.created,
            updated: task.updated,
            body: task.body
        )
    }

    private static func encodeTags(_ tags: [String]) -> String {
        guard let data = try? JSONEncoder().encode(tags),
              let json = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return json
    }

    private static func decodeTags(_ json: String) -> [String] {
        guard let data = json.data(using: .utf8),
              let tags = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }
        return tags
    }
}
