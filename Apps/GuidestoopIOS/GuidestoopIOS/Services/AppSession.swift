import Foundation
import SwiftData

@MainActor
final class AppSession: ObservableObject {
    enum Phase {
        case onboarding
        case ready(AppEnvironment)
    }

    @Published private(set) var phase: Phase
    private let modelContainer: ModelContainer

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
        if FolderBookmarkStore.isConfigured,
           let environment = try? AppEnvironment(modelContext: modelContainer.mainContext) {
            phase = .ready(environment)
        } else {
            phase = .onboarding
        }
    }

    func finishOnboarding() {
        reloadEnvironment()
    }

    func reloadEnvironment() {
        guard FolderBookmarkStore.isConfigured,
              let environment = try? AppEnvironment(modelContext: modelContainer.mainContext) else {
            phase = .onboarding
            return
        }
        phase = .ready(environment)
    }
}
