import Foundation

public enum TaskListTab: String, CaseIterable, Sendable {
    case all
    case inbox
    case blocked
    case today
    case done
    case trash

    public var title: String {
        switch self {
        case .all: return "All"
        case .inbox: return "Inbox"
        case .blocked: return "Blocked"
        case .today: return "Today"
        case .done: return "Done"
        case .trash: return "Trash"
        }
    }
}

public enum TaskFilters {
    public static func filterByTab(
        _ tasks: [Task],
        tab: TaskListTab,
        todayYmd: String,
        calendar: Calendar = .current
    ) -> [Task] {
        switch tab {
        case .all:
            return tasks
        case .inbox:
            return tasks.filter { $0.status == .inbox }
        case .blocked:
            return tasks.filter { $0.status == .blocked }
        case .today:
            return tasks.filter { task in
                task.status != .done &&
                    (task.status == .focus || ScheduleLogic.isScheduledToday(task, dateYmd: todayYmd, calendar: calendar))
            }
        case .done:
            return tasks.filter { $0.status == .done }
        case .trash:
            return []
        }
    }

    public static func filterBySearch(_ tasks: [Task], query: String) -> [Task] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return tasks }
        let needle = trimmed.lowercased()
        return tasks.filter { task in
            task.title.lowercased().contains(needle) ||
                task.body.lowercased().contains(needle) ||
                (task.project?.lowercased().contains(needle) ?? false) ||
                task.tags.contains { $0.lowercased().contains(needle) }
        }
    }

    public static func filterByTag(_ tasks: [Task], tag: String?) -> [Task] {
        guard let tag, !tag.isEmpty else { return tasks }
        return tasks.filter { $0.tags.contains(tag) }
    }

    public static func allTags(_ tasks: [Task]) -> [String] {
        Array(Set(tasks.flatMap(\.tags))).sorted()
    }

    public static func localDateYmd(calendar: Calendar = .current, date: Date = Date()) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", components.year!, components.month!, components.day!)
    }

    public static func dayTimelineTasks(
        _ tasks: [Task],
        dateYmd: String,
        calendar: Calendar = .current
    ) -> (scheduled: [Task], focus: [Task]) {
        let scheduled = ScheduleLogic.tasksDueToday(tasks, dateYmd: dateYmd, calendar: calendar)
            .filter { $0.status != .done && $0.scheduled != nil }
        let focus: [Task]
        if dateYmd == localDateYmd(calendar: calendar) {
            focus = tasks.filter { $0.status == .focus }
        } else {
            focus = []
        }
        return (scheduled, focus)
    }

    public static func todayCandidates(
        _ tasks: [Task],
        todayYmd: String,
        calendar: Calendar = .current
    ) -> [Task] {
        filterByTab(tasks, tab: .today, todayYmd: todayYmd, calendar: calendar)
    }

    public static func nowTasks(
        _ tasks: [Task],
        todayYmd: String,
        limit: Int,
        calendar: Calendar = .current
    ) -> [Task] {
        let candidates = todayCandidates(tasks, todayYmd: todayYmd, calendar: calendar)
        return sortForNow(candidates).prefix(max(limit, 0)).map { $0 }
    }

    public static func todayFocusCount(
        _ tasks: [Task],
        todayYmd: String,
        calendar: Calendar = .current
    ) -> Int {
        todayCandidates(tasks, todayYmd: todayYmd, calendar: calendar).count
    }

    public static func sortForNow(_ tasks: [Task]) -> [Task] {
        tasks.sorted { lhs, rhs in
            if lhs.highPriority != rhs.highPriority {
                return lhs.highPriority && !rhs.highPriority
            }
            return lhs.updated > rhs.updated
        }
    }
}
