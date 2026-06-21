import SwiftUI
import SwiftData
import GuidestoopCore
import GuidestoopStorage

struct ContentView: View {
    @EnvironmentObject private var appEnvironment: AppEnvironment
    @State private var taskCount = 0

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 48))
            Text("Guidestoop")
                .font(.title)
            Text("Core v\(GuidestoopCoreVersion.current) · Storage v\(GuidestoopStorageVersion.current)")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("Tasks after sync: \(taskCount)")
                .font(.headline)
            Button {
                Swift.Task {
                    await appEnvironment.syncCoordinator.syncNow()
                    refreshTaskCount()
                }
            } label: {
                if appEnvironment.syncCoordinator.isSyncing {
                    ProgressView()
                } else {
                    Text("Sync now")
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .task {
            await appEnvironment.syncCoordinator.syncNow()
            refreshTaskCount()
        }
    }

    private func refreshTaskCount() {
        taskCount = (try? appEnvironment.localStore.taskCount()) ?? 0
    }
}

#Preview {
    if let environment = try? AppEnvironment(
        modelContext: try! ModelContainer(
            for: CachedTask.self,
            CachedProject.self,
            CachedDeletedTask.self,
            CachedOutboxEntry.self
        ).mainContext
    ) {
        ContentView()
            .environmentObject(environment)
    }
}
