import Foundation

public enum TaskFactory {
    public static func create(title: String, body: String = "", status: TaskStatus = .inbox) -> Task {
        let now = ISO8601DateFormatter().string(from: Date())
        return Task(
            id: UUID().uuidString.lowercased(),
            title: title, status: status,
            created: now, updated: now, body: body
        )
    }
}
