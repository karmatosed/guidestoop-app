import SwiftUI
import UniformTypeIdentifiers
import GuidestoopCore

enum AppearancePreference: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject private var appEnvironment: AppEnvironment
    @EnvironmentObject private var appSession: AppSession
    @AppStorage("guidestoop.appearance") private var appearanceRaw = AppearancePreference.system.rawValue

    var onOpenTrash: (() -> Void)?

    @State private var showFolderPicker = false
    @State private var folderError: String?

    private var appearance: AppearancePreference {
        AppearancePreference(rawValue: appearanceRaw) ?? .system
    }

    var body: some View {
        List {
            Section("Storage") {
                LabeledContent("Provider", value: "iCloud Drive")
                Text(appEnvironment.folderURL.path)
                    .font(.caption)
                    .foregroundStyle(GuidestoopTheme.textSecondary)
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

            Section("Appearance") {
                Picker("Theme", selection: $appearanceRaw) {
                    ForEach(AppearancePreference.allCases) { option in
                        Text(option.title).tag(option.rawValue)
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
                    .font(.caption)
                    .foregroundStyle(GuidestoopTheme.textSecondary)
            }
        }
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
                    Text("No conflicts")
                        .foregroundStyle(GuidestoopTheme.textSecondary)
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
        .preferredColorScheme(.dark)
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
                }
            }
            .background(GuidestoopTheme.background)
            .foregroundStyle(GuidestoopTheme.textPrimary)
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
                loadConflict()
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
        .preferredColorScheme(.dark)
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

    private func loadConflict() {
        do {
            conflict = try appEnvironment.syncCoordinator.loadConflict(at: conflictPath)
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
