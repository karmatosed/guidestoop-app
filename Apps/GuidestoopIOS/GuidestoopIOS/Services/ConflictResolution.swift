import Foundation
import GuidestoopCore

struct ConflictInfo: Identifiable, Sendable {
    var id: String { conflictPath }
    let conflictPath: String
    let taskId: String
    let localTask: Task
    let remoteTask: Task
}

enum ConflictPathParser {
    static func taskId(fromConflictPath path: String) -> String? {
        let name = (path as NSString).lastPathComponent
        guard let range = name.range(of: ".conflict.") else { return nil }
        let id = String(name[..<range.lowerBound])
        return id.isEmpty ? nil : id
    }
}
