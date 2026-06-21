import Foundation
import SwiftData
import GuidestoopStorage

@MainActor
final class AppEnvironment: ObservableObject {
    let localStore: LocalStore
    let syncCoordinator: SyncCoordinator
    let folderURL: URL

    init(modelContext: ModelContext) {
        localStore = LocalStore(modelContext: modelContext)

        if let folder = try? ICloudAdapter.defaultFolderURL() {
            folderURL = folder
        } else {
            folderURL = FileManager.default
                .urls(for: .documentDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("Guidestoop", isDirectory: true)
        }

        syncCoordinator = SyncCoordinator(localStore: localStore, folderURL: folderURL)
    }
}
