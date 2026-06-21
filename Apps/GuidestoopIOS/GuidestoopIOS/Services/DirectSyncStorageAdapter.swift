import Foundation
import GuidestoopCore

/// Synchronous file adapter for background sync — no async/semaphore bridging.
final class DirectSyncStorageAdapter: SyncStorageAdapter, @unchecked Sendable {
    private let rootURL: URL
    private let fileManager = FileManager.default

    init(rootURL: URL) {
        self.rootURL = rootURL
    }

    func ensureFolderStructure() throws {
        for dir in ["tasks", "tasks/deleted", "projects", "_meta"] {
            let url = rootURL.appendingPathComponent(dir, isDirectory: true)
            try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        }
        let metaURL = url(for: SyncPaths.metaFile)
        if !fileManager.fileExists(atPath: metaURL.path) {
            try writeMeta(SyncMeta())
        }
    }

    func listFileMetadata() throws -> [SyncFileMetadata] {
        var results: [SyncFileMetadata] = []
        let enumerator = fileManager.enumerator(
            at: rootURL,
            includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey]
        )
        while let fileURL = enumerator?.nextObject() as? URL {
            guard fileURL.pathExtension == "md" else { continue }
            guard let path = relativePath(for: fileURL) else { continue }
            let values = try fileURL.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey])
            results.append(
                SyncFileMetadata(
                    path: path,
                    modifiedAt: values.contentModificationDate,
                    size: values.fileSize
                )
            )
        }
        return results
    }

    func read(path: String) throws -> String {
        try String(contentsOf: url(for: path), encoding: .utf8)
    }

    func write(path: String, content: String) throws {
        let fileURL = url(for: path)
        try fileManager.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try content.write(to: fileURL, atomically: true, encoding: .utf8)
    }

    func delete(path: String) throws {
        let fileURL = url(for: path)
        if fileManager.fileExists(atPath: fileURL.path) {
            try fileManager.removeItem(at: fileURL)
        }
    }

    func readMeta() throws -> SyncMeta {
        let raw = try read(path: SyncPaths.metaFile)
        return try JSONDecoder().decode(SyncMeta.self, from: Data(raw.utf8))
    }

    func writeMeta(_ meta: SyncMeta) throws {
        let data = try JSONEncoder().encode(meta)
        try write(path: SyncPaths.metaFile, content: String(decoding: data, as: UTF8.self))
    }

    private func url(for path: String) -> URL {
        rootURL.appendingPathComponent(path.trimmingCharacters(in: CharacterSet(charactersIn: "/")))
    }

    private func relativePath(for fileURL: URL) -> String? {
        var rootPath = rootURL.standardizedFileURL.resolvingSymlinksInPath().path(percentEncoded: false)
        if rootPath.hasSuffix("/") { rootPath.removeLast() }
        let filePath = fileURL.standardizedFileURL.resolvingSymlinksInPath().path(percentEncoded: false)
        guard filePath.hasPrefix(rootPath + "/") else { return nil }
        return "/" + String(filePath.dropFirst(rootPath.count + 1))
    }
}
