import SwiftUI
import UniformTypeIdentifiers
import GuidestoopCore

struct SettingsView: View {
    @EnvironmentObject private var appEnvironment: AppEnvironment
    @EnvironmentObject private var appSession: AppSession
    @EnvironmentObject private var appearanceSettings: AppearanceSettings
    @EnvironmentObject private var energySettings: EnergySettings

    var onOpenTrash: (() -> Void)?

    @State private var showFolderPicker = false
    @State private var folderError: String?

    var body: some View {
        List {
            Section("Storage") {
                LabeledContent("Provider", value: "iCloud Drive")
                Text(appEnvironment.folderURL.path)
                    .font(GuidestoopTypography.meta)
                    .foregroundStyle(.secondary)
                Button("Change Folder") {
                    showFolderPicker = true
                }
            }

            Section("Sync") {
                Button("Sync now") {
                    Swift.Task { await appEnvironment.syncCoordinator.syncNow() }
                }
                if let lastSynced = appEnvironment.syncCoordinator.lastSyncedAt {
                    LabeledContent("Last synced") {
                        Text(lastSynced.formatted(date: .abbreviated, time: .shortened))
                    }
                }
                LabeledContent("Pending", value: "\(appEnvironment.syncCoordinator.outboxCount)")
            }

            Section("Energy") {
                ForEach(EnergyLevel.allCases) { level in
                    Stepper(
                        value: Binding(
                            get: { energySettings.taskLimit(for: level) },
                            set: { energySettings.setLimit($0, for: level) }
                        ),
                        in: 1 ... 20
                    ) {
                        Text("\(level.title): \(energySettings.taskLimit(for: level)) tasks")
                    }
                }
                Text("Set today's energy on the Now tab. Limits apply to how many tasks show in your daily focus.")
                    .font(GuidestoopTypography.meta)
                    .foregroundStyle(.secondary)
            }

            Section("Appearance") {
                Picker("Theme", selection: $appearanceSettings.preference) {
                    ForEach(AppearancePreference.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }
            }

            Section("Trash") {
                Button("Open Trash") {
                    onOpenTrash?()
                }
            }

            Section("About") {
                Button("Switch to GitHub") {}
                    .disabled(true)
                Text("Coming in a future update")
                    .font(GuidestoopTypography.meta)
                    .foregroundStyle(.secondary)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(GuidestoopTheme.background)
        .fileImporter(
            isPresented: $showFolderPicker,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                Swift.Task { await changeFolder(to: url) }
            case .failure(let error):
                folderError = error.localizedDescription
            }
        }
        .alert("Could not change folder", isPresented: Binding(
            get: { folderError != nil },
            set: { if !$0 { folderError = nil } }
        )) {
            Button("OK", role: .cancel) { folderError = nil }
        } message: {
            Text(folderError ?? "")
        }
    }

    private func changeFolder(to url: URL) async {
        do {
            try await FolderSetup.configurePickedFolder(url)
            appSession.reloadEnvironment()
        } catch {
            folderError = error.localizedDescription
        }
    }
}

struct ConflictPathItem: Identifiable {
    let path: String
    var id: String { path }
}

struct ConflictsListView: View {
    @EnvironmentObject private var appEnvironment: AppEnvironment
    @Environment(\.dismiss) private var dismiss

    @State private var selectedConflict: ConflictPathItem?
    @State private var errorMessage: String?

    private var conflictPaths: [String] {
        appEnvironment.syncCoordinator.taskConflictPaths
    }

    var body: some View {
        NavigationStack {
            List {
                if conflictPaths.isEmpty {
                    ContentUnavailableView {
                        Label("No conflicts", systemImage: "checkmark.circle")
                    }
                } else {
                    ForEach(conflictPaths, id: \.self) { path in
                        Button {
                            selectedConflict = ConflictPathItem(path: path)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(displayName(for: path))
                                    .foregroundStyle(GuidestoopTheme.textPrimary)
                                Text(path)
                                    .font(.caption)
                                    .foregroundStyle(GuidestoopTheme.textSecondary)
                                    .lineLimit(1)
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(GuidestoopTheme.background)
            .navigationTitle("Conflicts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .sheet(item: $selectedConflict) { item in
                ConflictDetailView(conflictPath: item.path)
                    .environmentObject(appEnvironment)
            }
            .alert("Error", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private func displayName(for path: String) -> String {
        guard let taskId = ConflictPathParser.taskId(fromConflictPath: path) else {
            return path
        }
        return "Task \(taskId.prefix(8))…"
    }
}

struct ConflictDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appEnvironment: AppEnvironment

    let conflictPath: String

    @State private var conflict: ConflictInfo?
    @State private var isResolving = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if let conflict {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            conflictColumn(title: "Local (this device)", task: conflict.localTask)
                            conflictColumn(title: "Remote (iCloud)", task: conflict.remoteTask)
                        }
                        .padding()
                    }
                } else {
                    ProgressView("Loading…")
                        .tint(GuidestoopTheme.accent)
                }
            }
            .guidestoopScreenStyle()
            .navigationTitle("Resolve conflict")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItemGroup(placement: .bottomBar) {
                    Button("Keep remote") {
                        resolve(keepLocal: false)
                    }
                    .disabled(isResolving || conflict == nil)

                    Spacer()

                    Button("Keep mine") {
                        resolve(keepLocal: true)
                    }
                    .disabled(isResolving || conflict == nil)
                }
            }
            .task {
                await loadConflict()
            }
            .alert("Error", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private func conflictColumn(title: String, task: GuidestoopCore.Task) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            Text(task.title)
                .font(.body.weight(.semibold))
            Text("Status: \(task.status.rawValue)")
                .font(.caption)
                .foregroundStyle(GuidestoopTheme.textSecondary)
            if !task.body.isEmpty {
                Text(task.body)
                    .font(.subheadline)
                    .foregroundStyle(GuidestoopTheme.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(GuidestoopTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func loadConflict() async {
        do {
            conflict = try await appEnvironment.syncCoordinator.loadConflict(at: conflictPath)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func resolve(keepLocal: Bool) {
        isResolving = true
        Swift.Task {
            do {
                try await appEnvironment.syncCoordinator.resolveConflict(at: conflictPath, keepLocal: keepLocal)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
            isResolving = false
        }
    }
}
