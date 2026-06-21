import Foundation

public enum TrashLogic {
    public static let retentionDays = 30

    public static func isTrashExpired(deletedAt: String, now: Date = Date()) -> Bool {
        guard let deleted = parseIso(deletedAt),
              let purgeDate = Calendar.current.date(byAdding: .day, value: retentionDays, to: deleted) else {
            return true
        }
        return now >= purgeDate
    }

    public static func daysUntilPurge(deletedAt: String, now: Date = Date()) -> Int {
        guard let deleted = parseIso(deletedAt) else { return 0 }
        let calendar = Calendar.current
        let startOfDeleted = calendar.startOfDay(for: deleted)
        let startOfNow = calendar.startOfDay(for: now)
        let elapsedDays = (calendar.dateComponents([.day], from: startOfDeleted, to: startOfNow).day ?? 0) + 1
        return max(0, retentionDays - elapsedDays)
    }

    private static func parseIso(_ iso: String) -> Date? {
        let withFraction = ISO8601DateFormatter()
        withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = withFraction.date(from: iso) { return date }

        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        return plain.date(from: iso)
    }
}
