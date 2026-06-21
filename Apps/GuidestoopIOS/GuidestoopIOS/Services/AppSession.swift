import Foundation

@MainActor
final class AppSession: ObservableObject {
    enum Phase {
        case bootstrapping
        case onboarding
        case ready
    }

    @Published private(set) var phase: Phase
    @Published private(set) var reloadToken = UUID()
    @Published private(set) var bootstrapError: String?

    init() {
        phase = FolderBookmarkStore.isConfigured ? .ready : .bootstrapping
    }

    func bootstrapStorageIfNeeded() async {
        guard !FolderBookmarkStore.isConfigured else {
            if phase != .ready {
                phase = .ready
            }
            return
        }

        guard phase == .bootstrapping else { return }

        phase = .bootstrapping
        bootstrapError = nil

        do {
            try await FolderSetup.useDefaultFolder()
            phase = .ready
            reloadToken = UUID()
        } catch {
            bootstrapError = error.localizedDescription
            phase = .onboarding
        }
    }

    func finishOnboarding() {
        reloadEnvironment()
    }

    func revertToOnboardingIfNeeded() {
        guard !FolderBookmarkStore.isConfigured else { return }
        phase = .onboarding
    }

    func reloadEnvironment() {
        guard FolderBookmarkStore.isConfigured else {
            phase = .bootstrapping
            bootstrapError = nil
            Swift.Task { await bootstrapStorageIfNeeded() }
            return
        }
        phase = .ready
        reloadToken = UUID()
    }
}
