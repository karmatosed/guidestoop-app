import Foundation

@MainActor
final class AppEnvironmentHolder: ObservableObject {
    @Published private(set) var environment: AppEnvironment?
    @Published private(set) var errorMessage: String?

    func bootstrap() {
        guard FolderBookmarkStore.isConfigured else {
            environment = nil
            errorMessage = nil
            return
        }

        do {
            environment = try AppEnvironment()
            errorMessage = nil
        } catch {
            environment = nil
            errorMessage = error.localizedDescription
        }
    }
}
