import SwiftUI

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

@MainActor
final class AppearanceSettings: ObservableObject {
    private static let key = "guidestoop.appearance"

    @Published var preference: AppearancePreference {
        didSet {
            UserDefaults.standard.set(preference.rawValue, forKey: Self.key)
        }
    }

    init() {
        Self.sanitizeStoredValue()
        if let raw = UserDefaults.standard.string(forKey: Self.key),
           let value = AppearancePreference(rawValue: raw) {
            preference = value
        } else {
            preference = .system
        }
    }

    private static func sanitizeStoredValue() {
        guard UserDefaults.standard.object(forKey: key) != nil else { return }
        if UserDefaults.standard.string(forKey: key) == nil {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }
}
