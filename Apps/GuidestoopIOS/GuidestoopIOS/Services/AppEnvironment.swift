import Foundation
import SwiftData
import GuidestoopStorage

@MainActor
final class AppEnvironment: ObservableObject {
    let localStore: LocalStore
    let syncCoordinator: SyncCoordinator
    let folderURL: URL

    init(modelContext: ModelContext) throws {
        localStore = LocalStore(modelContext: modelContext)
        folderURL = try FolderBookmarkStore.resolve()
        syncCoordinator = SyncCoordinator(localStore: localStore, folderURL: folderURL)
    }
}
