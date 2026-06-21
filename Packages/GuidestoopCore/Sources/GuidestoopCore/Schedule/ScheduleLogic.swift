import Foundation

public enum ScheduleLogic {
    public static func localYmdFromIso(_ iso: String, calendar: Calendar = .current) -> String {
        guard let date = ISO8601DateFormatter().date(from: iso) ??
              ISO8601DateFormatter().date(from: iso + "T00:00:00Z") else { return "" }
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year!, c.month!, c.day!)
    }

    public static func isScheduledToday(_ task: Task, dateYmd: String, calendar: Calendar = .current) -> Bool {
        guard let scheduled = task.scheduled else { return false }
        if scheduled.count == 10 { return scheduled == dateYmd }
        return localYmdFromIso(scheduled, calendar: calendar) == dateYmd
    }

    public static func tasksDueToday(_ tasks: [Task], dateYmd: String, calendar: Calendar = .current) -> [Task] {
        tasks.filter { isScheduledToday($0, dateYmd: dateYmd, calendar: calendar) }
             .sorted { ($0.scheduled ?? "") < ($1.scheduled ?? "") }
    }
}
