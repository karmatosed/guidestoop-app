import SwiftUI
import SwiftData

@main
struct GuidestoopIOSApp: App {
    private let modelContainer: ModelContainer
    @StateObject private var appSession: AppSession

    init() {
        let container: ModelContainer
        do {
            container = try ModelContainer(
                for: CachedTask.self,
                CachedProject.self,
                CachedDeletedTask.self,
                CachedOutboxEntry.self
            )
        } catch {
            fatalError("Failed to initialize SwiftData container: \(error.localizedDescription)")
        }
        modelContainer = container
        _appSession = StateObject(wrappedValue: AppSession(modelContainer: container))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appSession)
        }
        .modelContainer(modelContainer)
    }
}

private struct RootView: View {
    @EnvironmentObject private var appSession: AppSession

    var body: some View {
        switch appSession.phase {
        case .onboarding:
            OnboardingView {
                appSession.finishOnboarding()
            }
        case .ready(let environment):
            ContentView()
                .environmentObject(environment)
        }
    }
}
