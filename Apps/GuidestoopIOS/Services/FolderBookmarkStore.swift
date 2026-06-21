import Foundation
import GuidestoopStorage

enum FolderBookmarkStore {
    private static let key = "guidestoop.folder.bookmark"

    static func save(url: URL) throws {
        let data = try url.bookmarkData(
            options: .minimalBookmark,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        UserDefaults.standard.set(data, forKey: key)
    }

    static func resolve() throws -> URL {
        guard let data = UserDefaults.standard.data(forKey: key) else {
            throw StorageError.folderNotConfigured
        }
        var stale = false
        let url = try URL(
            resolvingBookmarkData: data,
            options: .withoutUI,
            relativeTo: nil,
            bookmarkDataIsStale: &stale
        )
        guard url.startAccessingSecurityScopedResource() else {
            throw StorageError.folderNotConfigured
        }
        return url
    }

    static var isConfigured: Bool {
        UserDefaults.standard.data(forKey: key) != nil
    }
}
