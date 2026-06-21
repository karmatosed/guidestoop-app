import Foundation

public enum StoragePaths {
    public static let tasksDir = "tasks"
    public static let deletedDir = "tasks/deleted"
    public static let projectsDir = "projects"
    public static let metaDir = "_meta"
    public static let metaFile = "_meta/guidestoop.json"

    public static func taskPath(id: String) -> String { "/tasks/\(id).md" }
    public static func deletedTaskPath(id: String) -> String { "/tasks/deleted/\(id).md" }
    public static func projectPath(slug: String) -> String { "/projects/\(slug).md" }
    public static func isConflictFile(_ filename: String) -> Bool {
        filename.contains(".conflict.")
    }
}
