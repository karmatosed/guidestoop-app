import Foundation
import GuidestoopCore

/// Phase 2 stub — GitHub-backed storage is not yet implemented.
public struct GitHubAdapter: StorageAdapter {
    private static let message = "GitHub storage coming in phase 2"

    public init() {}

    public func ensureFolderStructure() async throws {
        throw StorageError.notImplemented(Self.message)
    }

    public func listFileMetadata() async throws -> [RemoteFileMetadata] {
        throw StorageError.notImplemented(Self.message)
    }

    public func listFiles() async throws -> [RemoteFile] {
        throw StorageError.notImplemented(Self.message)
    }

    public func read(path: String) async throws -> String {
        throw StorageError.notImplemented(Self.message)
    }

    public func write(path: String, content: String) async throws {
        throw StorageError.notImplemented(Self.message)
    }

    public func delete(path: String) async throws {
        throw StorageError.notImplemented(Self.message)
    }

    public func readMeta() async throws -> SyncMeta {
        throw StorageError.notImplemented(Self.message)
    }

    public func writeMeta(_ meta: SyncMeta) async throws {
        throw StorageError.notImplemented(Self.message)
    }
}
