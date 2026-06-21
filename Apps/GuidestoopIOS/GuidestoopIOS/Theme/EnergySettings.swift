import SwiftUI
import GuidestoopCore

enum EnergyLevel: String, CaseIterable, Identifiable {
    case low
    case medium
    case high

    var id: String { rawValue }

    var title: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        }
    }

    var subtitle: String {
        switch self {
        case .low: return "Take it easy"
        case .medium: return "Steady pace"
        case .high: return "Full steam"
        }
    }
}

@MainActor
final class EnergySettings: ObservableObject {
    private static let levelKey = "guidestoop.energy.level"
    private static let dateKey = "guidestoop.energy.date"
    private static let limitPrefix = "guidestoop.energy.limit."

    static let defaultLimits: [EnergyLevel: Int] = [
        .low: 2,
        .medium: 4,
        .high: 6,
    ]

    @Published private(set) var limits: [EnergyLevel: Int]
    @Published private(set) var todayLevel: EnergyLevel

    init() {
        limits = Self.loadLimits()
        let storedDate = UserDefaults.standard.string(forKey: Self.dateKey)
        let todayYmd = TaskFilters.localDateYmd()
        if storedDate == todayYmd,
           let raw = UserDefaults.standard.string(forKey: Self.levelKey),
           let level = EnergyLevel(rawValue: raw) {
            todayLevel = level
        } else {
            todayLevel = .medium
            UserDefaults.standard.set(todayYmd, forKey: Self.dateKey)
            UserDefaults.standard.set(EnergyLevel.medium.rawValue, forKey: Self.levelKey)
        }
    }

    func selectTodayLevel(_ level: EnergyLevel) {
        guard todayLevel != level else { return }
        todayLevel = level
        persistTodayLevel()
    }

    func taskLimit(for level: EnergyLevel) -> Int {
        limits[level] ?? Self.defaultLimits[level] ?? 4
    }

    var todayTaskLimit: Int {
        taskLimit(for: todayLevel)
    }

    func setLimit(_ value: Int, for level: EnergyLevel) {
        let clamped = min(max(value, 1), 20)
        limits[level] = clamped
        UserDefaults.standard.set(clamped, forKey: Self.limitKey(for: level))
    }

    func refreshForNewDayIfNeeded() {
        let todayYmd = TaskFilters.localDateYmd()
        let storedDate = UserDefaults.standard.string(forKey: Self.dateKey)
        guard storedDate != todayYmd else { return }
        todayLevel = .medium
        UserDefaults.standard.set(todayYmd, forKey: Self.dateKey)
        UserDefaults.standard.set(EnergyLevel.medium.rawValue, forKey: Self.levelKey)
    }

    private func persistTodayLevel() {
        UserDefaults.standard.set(todayLevel.rawValue, forKey: Self.levelKey)
        UserDefaults.standard.set(TaskFilters.localDateYmd(), forKey: Self.dateKey)
    }

    private static func limitKey(for level: EnergyLevel) -> String {
        limitPrefix + level.rawValue
    }

    private static func loadLimits() -> [EnergyLevel: Int] {
        var loaded: [EnergyLevel: Int] = [:]
        for level in EnergyLevel.allCases {
            let key = limitKey(for: level)
            if UserDefaults.standard.object(forKey: key) != nil {
                loaded[level] = UserDefaults.standard.integer(forKey: key)
            }
        }
        return loaded
    }
}

extension EnergySettings {
    var todayLevelBinding: Binding<EnergyLevel> {
        Binding(
            get: { self.todayLevel },
            set: { self.selectTodayLevel($0) }
        )
    }
}
