import Foundation
import SwiftData
import GuidestoopCore

@Model
final class CachedProject {
    @Attribute(.unique) var id: String
    var name: String
    var color: String?
    var created: String
    var updated: String
    var body: String

    init(
        id: String,
        name: String,
        color: String?,
        created: String,
        updated: String,
        body: String
    ) {
        self.id = id
        self.name = name
        self.color = color
        self.created = created
        self.updated = updated
        self.body = body
    }

    func toProject() -> Project {
        let payload = CachedProjectPayload(
            id: id,
            name: name,
            color: color,
            created: created,
            updated: updated,
            body: body
        )
        return (try? payload.toProject()) ?? CachedProject.emptyProject
    }

    static func from(_ project: Project) -> CachedProject {
        CachedProject(
            id: project.id,
            name: project.name,
            color: project.color,
            created: project.created,
            updated: project.updated,
            body: project.body
        )
    }

    private static var emptyProject: Project {
        let fallback = CachedProjectPayload(
            id: "",
            name: "",
            color: nil,
            created: "",
            updated: "",
            body: ""
        )
        return try! fallback.toProject()
    }
}

private struct CachedProjectPayload: Codable {
    var id: String
    var name: String
    var color: String?
    var created: String
    var updated: String
    var body: String

    func toProject() throws -> Project {
        let data = try JSONEncoder().encode(self)
        return try JSONDecoder().decode(Project.self, from: data)
    }
}
