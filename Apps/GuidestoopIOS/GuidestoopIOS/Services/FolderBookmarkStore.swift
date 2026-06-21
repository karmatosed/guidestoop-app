import Foundation
import GuidestoopStorage

enum FolderBookmarkStore {
    private static let key = "guidestoop.folder.bookmark"

    static func save(url: URL, securityScoped: Bool = false) throws {
        var options: URL.BookmarkCreationOptions = .minimalBookmark
        #if os(macOS)
        if securityScoped {
            options.insert(.withSecurityScope)
        }
        #endif
        let data = try url.bookmarkData(
            options: options,
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
        var options: URL.BookmarkResolutionOptions = [.withoutUI]
        #if os(macOS)
        options.insert(.withSecurityScope)
        #endif
        let url = try URL(
            resolvingBookmarkData: data,
            options: options,
            relativeTo: nil,
            bookmarkDataIsStale: &stale
        )
        if stale {
            try save(url: url, securityScoped: true)
        }
        guard url.startAccessingSecurityScopedResource() else {
            throw StorageError.folderNotConfigured
        }
        return url
    }

    static var isConfigured: Bool {
        UserDefaults.standard.data(forKey: key) != nil
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}

enum FolderSetup {
    static func defaultFolderURL() -> URL {
        if let icloud = try? ICloudAdapter.defaultFolderURL() {
            return icloud
        }
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Guidestoop", isDirectory: true)
    }

    static func useDefaultFolder() async throws {
        let url = defaultFolderURL()
        try await configure(url: url, securityScoped: false)
    }

    static func configurePickedFolder(_ url: URL) async throws {
        guard url.startAccessingSecurityScopedResource() else {
            throw StorageError.folderNotConfigured
        }
        defer { url.stopAccessingSecurityScopedResource() }
        try await configure(url: url, securityScoped: true)
    }

    private static func configure(url: URL, securityScoped: Bool) async throws {
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        let adapter = ICloudAdapter(rootURL: url)
        try await adapter.ensureFolderStructure()
        try FolderBookmarkStore.save(url: url, securityScoped: securityScoped)
    }
}
