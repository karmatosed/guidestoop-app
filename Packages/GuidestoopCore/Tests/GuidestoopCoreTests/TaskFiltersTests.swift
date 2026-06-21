import XCTest
@testable import GuidestoopCore

final class TaskFiltersTests: XCTestCase {
    private func task(
        id: String = "id",
        title: String = "Title",
        status: TaskStatus = .inbox,
        scheduled: String? = nil,
        project: String? = nil,
        tags: [String] = [],
        body: String = ""
    ) -> Task {
        Task(
            id: id,
            title: title,
            status: status,
            scheduled: scheduled,
            project: project,
            tags: tags,
            created: "2026-05-01T08:00:00Z",
            updated: "2026-05-01T09:00:00Z",
            body: body
        )
    }

    func testFilterByTabInbox() {
        let tasks = [
            task(id: "a", status: .inbox),
            task(id: "b", status: .done),
        ]
        XCTAssertEqual(TaskFilters.filterByTab(tasks, tab: .inbox, todayYmd: "2026-05-23").map(\.id), ["a"])
    }

    func testFilterByTabTodayIncludesFocusAndScheduled() {
        let tasks = [
            task(id: "focus", status: .focus),
            task(id: "scheduled", status: .scheduled, scheduled: "2026-05-23T10:00:00Z"),
            task(id: "done", status: .done, scheduled: "2026-05-23T10:00:00Z"),
            task(id: "other-day", status: .scheduled, scheduled: "2026-05-22T10:00:00Z"),
        ]
        let filtered = TaskFilters.filterByTab(tasks, tab: .today, todayYmd: "2026-05-23")
        XCTAssertEqual(Set(filtered.map(\.id)), Set(["focus", "scheduled"]))
    }

    func testFilterBySearchMatchesTitleBodyProjectAndTags() {
        let tasks = [
            task(id: "a", title: "Buy milk", body: "2%"),
            task(id: "b", project: "Home", body: "paint"),
            task(id: "c", tags: ["errands"], body: ""),
        ]
        XCTAssertEqual(TaskFilters.filterBySearch(tasks, query: "milk").map(\.id), ["a"])
        XCTAssertEqual(TaskFilters.filterBySearch(tasks, query: "paint").map(\.id), ["b"])
        XCTAssertEqual(TaskFilters.filterBySearch(tasks, query: "home").map(\.id), ["b"])
        XCTAssertEqual(TaskFilters.filterBySearch(tasks, query: "errands").map(\.id), ["c"])
    }

    func testFilterByTagAndAllTags() {
        let tasks = [
            task(id: "a", tags: ["work", "urgent"]),
            task(id: "b", tags: ["home"]),
        ]
        XCTAssertEqual(TaskFilters.filterByTag(tasks, tag: "work").map(\.id), ["a"])
        XCTAssertEqual(TaskFilters.allTags(tasks), ["home", "urgent", "work"])
    }

    func testDayTimelineTasks() {
        let today = TaskFilters.localDateYmd()
        let tasks = [
            task(id: "focus", status: .focus),
            task(id: "scheduled", status: .scheduled, scheduled: "\(today)T10:00:00Z"),
            task(id: "done", status: .done, scheduled: "\(today)T10:00:00Z"),
            task(id: "other-day", status: .scheduled, scheduled: "2026-05-22T10:00:00Z"),
        ]
        let result = TaskFilters.dayTimelineTasks(tasks, dateYmd: today)
        XCTAssertEqual(result.scheduled.map(\.id), ["scheduled"])
        XCTAssertEqual(result.focus.map(\.id), ["focus"])
    }
}
