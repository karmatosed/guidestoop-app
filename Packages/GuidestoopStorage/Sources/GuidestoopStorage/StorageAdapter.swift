import Foundation
import GuidestoopCore

public struct RemoteFile: Sendable {
    public let path: String
    public let content: String
    public let modifiedAt: Date?

    public init(path: String, content: String, modifiedAt: Date? = nil) {
        self.path = path
        self.content = content
        self.modifiedAt = modifiedAt
    }
}

public struct FolderMeta: Codable, Sendable {
    public var schemaVersion: Int
    public var lastSyncedAt: String?

    public init(schemaVersion: Int = 1, lastSyncedAt: String? = nil) {
        self.schemaVersion = schemaVersion
        self.lastSyncedAt = lastSyncedAt
    }
}

public enum StorageError: Error, Sendable {
    case notImplemented(String)
    case folderNotConfigured
    case readFailed(String)
    case writeFailed(String)
}

public protocol StorageAdapter: Sendable {
    func ensureFolderStructure() async throws
    func listFiles() async throws -> [RemoteFile]
    func read(path: String) async throws -> String
    func write(path: String, content: String) async throws
    func delete(path: String) async throws
    func readMeta() async throws -> FolderMeta
    func writeMeta(_ meta: FolderMeta) async throws
}
