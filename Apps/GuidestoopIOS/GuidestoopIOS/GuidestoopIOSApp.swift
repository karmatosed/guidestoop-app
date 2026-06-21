import SwiftUI
import SwiftData

@main
struct GuidestoopIOSApp: App {
    private let modelContainer: ModelContainer
    @StateObject private var appEnvironment: AppEnvironment

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
        _appEnvironment = StateObject(
            wrappedValue: AppEnvironment(modelContext: container.mainContext)
        )
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appEnvironment)
        }
        .modelContainer(modelContainer)
    }
}
