import SwiftUI
import UniformTypeIdentifiers

struct OnboardingView: View {
    let onComplete: () -> Void

    @State private var isWorking = false
    @State private var errorMessage: String?
    @State private var showFolderPicker = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Text("g")
                .font(.system(size: 56, weight: .light, design: .serif))
                .foregroundStyle(.primary)

            VStack(spacing: 8) {
                Text("Guidestoop")
                    .font(.title2.weight(.semibold))
                Text("Your tasks live as markdown files in iCloud Drive.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()

            VStack(spacing: 12) {
                Button {
                    Swift.Task { await useDefaultFolder() }
                } label: {
                    Text("Use Default Folder")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isWorking)

                Button {
                    showFolderPicker = true
                } label: {
                    Text("Choose Folder")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(isWorking)

                if isWorking {
                    ProgressView("Setting up…")
                        .padding(.top, 8)
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .fileImporter(
            isPresented: $showFolderPicker,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                Swift.Task { await configurePickedFolder(url) }
            case .failure(let error):
                errorMessage = error.localizedDescription
            }
        }
    }

    private func useDefaultFolder() async {
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }
        do {
            try await FolderSetup.useDefaultFolder()
            onComplete()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func configurePickedFolder(_ url: URL) async {
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }
        do {
            try await FolderSetup.configurePickedFolder(url)
            onComplete()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    OnboardingView(onComplete: {})
}
