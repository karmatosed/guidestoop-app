import Foundation
import GuidestoopStorage

@MainActor
final class AppEnvironment: ObservableObject {
    let localStore: LocalStore
    let syncCoordinator: SyncCoordinator
    let folderURL: URL

    init() throws {
        localStore = try LocalStore()
        folderURL = try FolderBookmarkStore.resolve()
        syncCoordinator = SyncCoordinator(localStore: localStore, folderURL: folderURL)
    }
}
