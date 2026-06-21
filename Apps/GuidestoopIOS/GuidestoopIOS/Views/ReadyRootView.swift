import SwiftUI

struct ReadyRootView: View {
    @EnvironmentObject private var appSession: AppSession

    @State private var environment: AppEnvironment?
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if let environment {
                AppShellView()
                    .environmentObject(environment)
                    .environmentObject(appSession)
            } else if let errorMessage {
                VStack(spacing: 12) {
                    Text("Could not open storage folder")
                        .font(.headline)
                    Text(errorMessage)
                        .font(.subheadline)
                        .foregroundStyle(GuidestoopTheme.textSecondary)
                        .multilineTextAlignment(.center)
                    Button("Choose folder again") {
                        FolderBookmarkStore.clear()
                        appSession.reloadEnvironment()
                    }
                    .guidestoopProminentButton()
                }
                .padding()
            } else {
                VStack(spacing: 16) {
                    ProgressView()
                        .tint(GuidestoopTheme.textPrimary)
                    Text("Loading…")
                        .font(.subheadline)
                        .foregroundStyle(GuidestoopTheme.textSecondary)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(GuidestoopTheme.background)
        .onAppear(perform: loadEnvironment)
        .onChange(of: appSession.reloadToken) { _, _ in
            loadEnvironment()
        }
    }

    private func loadEnvironment() {
        guard FolderBookmarkStore.isConfigured else {
            environment = nil
            errorMessage = nil
            appSession.revertToOnboardingIfNeeded()
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
