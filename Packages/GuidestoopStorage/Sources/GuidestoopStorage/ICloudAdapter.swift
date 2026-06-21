import Foundation
import GuidestoopCore

public final class ICloudAdapter: StorageAdapter, @unchecked Sendable {
    public static let containerIdentifier = "iCloud.com.guidestoop.ios"

    private let rootURL: URL
    private let coordinator = NSFileCoordinator()
    private let fm = FileManager.default

    public init(rootURL: URL) {
        self.rootURL = rootURL
    }

    public static func defaultFolderURL() throws -> URL {
        guard let container = FileManager.default.url(
            forUbiquityContainerIdentifier: containerIdentifier
        ) else {
            throw StorageError.folderNotConfigured
        }
        return container.appendingPathComponent("Documents/Guidestoop", isDirectory: true)
    }

    public func ensureFolderStructure() async throws {
        for dir in [StoragePaths.tasksDir, StoragePaths.deletedDir,
                    StoragePaths.projectsDir, StoragePaths.metaDir] {
            let url = rootURL.appendingPathComponent(dir, isDirectory: true)
            try fm.createDirectory(at: url, withIntermediateDirectories: true)
        }
        if !fm.fileExists(atPath: rootURL.appendingPathComponent(StoragePaths.metaFile).path) {
            try await writeMeta(SyncMeta())
        }
    }

    private func relativePath(for fileURL: URL) -> String? {
        var rootPath = rootURL.standardizedFileURL.resolvingSymlinksInPath().path(percentEncoded: false)
        if rootPath.hasSuffix("/") {
            rootPath.removeLast()
        }
        let filePath = fileURL.standardizedFileURL.resolvingSymlinksInPath().path(percentEncoded: false)
        guard filePath.hasPrefix(rootPath + "/") else { return nil }
        return "/" + String(filePath.dropFirst(rootPath.count + 1))
    }

    public func listFileMetadata() async throws -> [RemoteFileMetadata] {
        var results: [RemoteFileMetadata] = []
        let root = rootURL.standardizedFileURL
        let enumerator = fm.enumerator(
            at: root,
            includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey]
        )
        while let url = enumerator?.nextObject() as? URL {
            guard url.pathExtension == "md" else { continue }
            guard let rel = relativePath(for: url) else { continue }
            let values = try url.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey])
            results.append(RemoteFileMetadata(
                path: rel,
                modifiedAt: values.contentModificationDate,
                size: values.fileSize
            ))
        }
        return results
    }

    public func listFiles() async throws -> [RemoteFile] {
        let metadata = try await listFileMetadata()
        var results: [RemoteFile] = []
        for entry in metadata {
            let content = try await read(path: entry.path)
            results.append(RemoteFile(path: entry.path, content: content, modifiedAt: entry.modifiedAt))
        }
        return results
    }

    public func read(path: String) async throws -> String {
        let url = rootURL.appendingPathComponent(path.trimmingCharacters(in: CharacterSet(charactersIn: "/")))
        var result = ""
        var coordError: NSError?
        coordinator.coordinate(readingItemAt: url, options: [], error: &coordError) { readURL in
            result = (try? String(contentsOf: readURL, encoding: .utf8)) ?? ""
        }
        if let coordError {
            throw StorageError.readFailed(coordError.localizedDescription)
        }
        return result
    }

    public func write(path: String, content: String) async throws {
        let url = rootURL.appendingPathComponent(path.trimmingCharacters(in: CharacterSet(charactersIn: "/")))
        try fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        var coordError: NSError?
        coordinator.coordinate(writingItemAt: url, options: .forReplacing, error: &coordError) { writeURL in
            try? content.write(to: writeURL, atomically: true, encoding: .utf8)
        }
        if let coordError {
            throw StorageError.writeFailed(coordError.localizedDescription)
        }
    }

    public func delete(path: String) async throws {
        let url = rootURL.appendingPathComponent(path.trimmingCharacters(in: CharacterSet(charactersIn: "/")))
        var coordError: NSError?
        coordinator.coordinate(writingItemAt: url, options: .forDeleting, error: &coordError) { deleteURL in
            try? fm.removeItem(at: deleteURL)
        }
        if let coordError {
            throw StorageError.writeFailed(coordError.localizedDescription)
        }
    }

    public func readMeta() async throws -> SyncMeta {
        let raw = try await read(path: StoragePaths.metaFile)
        return try JSONDecoder().decode(SyncMeta.self, from: Data(raw.utf8))
    }

    public func writeMeta(_ meta: SyncMeta) async throws {
        let data = try JSONEncoder().encode(meta)
        try await write(path: StoragePaths.metaFile, content: String(decoding: data, as: UTF8.self))
    }
}
