import Foundation

public enum TaskStatus: String, Codable, CaseIterable, Sendable {
    case inbox, blocked, focus, scheduled, done

    public static func isValid(_ raw: String) -> Bool {
        TaskStatus(rawValue: raw) != nil
    }
}
