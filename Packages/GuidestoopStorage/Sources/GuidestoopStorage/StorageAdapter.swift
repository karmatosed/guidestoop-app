import Foundation
import GuidestoopCore

public struct RemoteFileMetadata: Sendable {
    public let path: String
    public let modifiedAt: Date?
    public let size: Int?

    public init(path: String, modifiedAt: Date? = nil, size: Int? = nil) {
        self.path = path
        self.modifiedAt = modifiedAt
        self.size = size
    }
}

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

public typealias FolderMeta = SyncMeta

public enum StorageError: Error, Sendable {
    case notImplemented(String)
    case folderNotConfigured
    case readFailed(String)
    case writeFailed(String)
}

public protocol StorageAdapter: Sendable {
    func ensureFolderStructure() async throws
    func listFileMetadata() async throws -> [RemoteFileMetadata]
    func listFiles() async throws -> [RemoteFile]
    func read(path: String) async throws -> String
    func write(path: String, content: String) async throws
    func delete(path: String) async throws
    func readMeta() async throws -> SyncMeta
    func writeMeta(_ meta: SyncMeta) async throws
}
