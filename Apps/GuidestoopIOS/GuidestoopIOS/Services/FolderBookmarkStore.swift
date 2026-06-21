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
        _ = url.startAccessingSecurityScopedResource()
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
    private static let maxWaitNanoseconds: UInt64 = 10_000_000_000
    private static let retryDelayNanoseconds: UInt64 = 500_000_000

    static func useDefaultFolder() async throws {
        let url = try await resolveDefaultFolderURL()
        try await configure(url: url, securityScoped: false)
    }

    static func resolveDefaultFolderURL() async throws -> URL {
        let deadline = DispatchTime.now().uptimeNanoseconds + maxWaitNanoseconds
        while DispatchTime.now().uptimeNanoseconds < deadline {
            if let url = try? ICloudAdapter.defaultFolderURL() {
                return url
            }
            try await Swift.Task.sleep(nanoseconds: retryDelayNanoseconds)
        }
        throw FolderSetupError.iCloudUnavailable
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

enum FolderSetupError: LocalizedError {
    case iCloudUnavailable

    var errorDescription: String? {
        switch self {
        case .iCloudUnavailable:
            return "Could not access iCloud Drive. Sign in to iCloud, enable iCloud Drive, and try again."
        }
    }
}
