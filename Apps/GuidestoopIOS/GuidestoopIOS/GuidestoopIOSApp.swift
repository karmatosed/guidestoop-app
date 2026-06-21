import SwiftUI

@main
struct GuidestoopIOSApp: App {
    @StateObject private var appSession = AppSession()
    @StateObject private var appearanceSettings = AppearanceSettings()
    @StateObject private var energySettings = EnergySettings()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appSession)
                .environmentObject(appearanceSettings)
                .environmentObject(energySettings)
                .background(GuidestoopTheme.background)
        }
    }
}

private struct RootView: View {
    @EnvironmentObject private var appSession: AppSession
    @EnvironmentObject private var appearanceSettings: AppearanceSettings

    var body: some View {
        Group {
            switch appSession.phase {
            case .bootstrapping:
                bootstrappingView
            case .onboarding:
                OnboardingView(initialError: appSession.bootstrapError) {
                    appSession.finishOnboarding()
                }
            case .ready:
                ReadyRootView()
                    .environmentObject(appSession)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(GuidestoopTheme.background)
        .guidestoopScreenStyle()
        .preferredColorScheme(appearanceSettings.preference.colorScheme)
        .task {
            await appSession.bootstrapStorageIfNeeded()
        }
    }

    private var bootstrappingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .tint(GuidestoopTheme.textPrimary)
            Text("Setting up iCloud…")
                .font(.subheadline)
                .foregroundStyle(GuidestoopTheme.textSecondary)
        }
    }
}
