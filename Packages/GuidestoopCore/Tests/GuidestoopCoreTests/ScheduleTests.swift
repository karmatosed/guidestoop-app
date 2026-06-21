import XCTest
@testable import GuidestoopCore

final class ScheduleTests: XCTestCase {
    private func task(_ partial: (inout Task) -> Void = { _ in }) -> Task {
        var t = Task(id: "id", title: "Title", status: .scheduled,
                     created: "2026-05-01T08:00:00Z", updated: "2026-05-01T09:00:00Z")
        partial(&t)
        return t
    }

    func testLocalYmdUsesLocalCalendarDay() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 3600)!
        let date = cal.date(from: DateComponents(year: 2026, month: 5, day: 23, hour: 0, minute: 30))!
        let iso = ISO8601DateFormatter().string(from: date)
        XCTAssertEqual(ScheduleLogic.localYmdFromIso(iso, calendar: cal), "2026-05-23")
    }

    func testIsScheduledTodayFalseWhenNoDate() {
        XCTAssertFalse(ScheduleLogic.isScheduledToday(task(), dateYmd: "2026-05-23"))
    }

    func testIsScheduledTodayMatchesDay() {
        let t = task { $0.scheduled = "2026-05-23T10:30:00Z" }
        XCTAssertTrue(ScheduleLogic.isScheduledToday(t, dateYmd: "2026-05-23"))
    }

    func testTasksDueTodaySorted() {
        let t1 = task { $0.id = "a"; $0.scheduled = "2026-05-23T14:00:00Z" }
        let t2 = task { $0.id = "b"; $0.scheduled = "2026-05-23T09:00:00Z" }
        let other = task { $0.id = "c"; $0.scheduled = "2026-05-22T12:00:00Z" }
        XCTAssertEqual(ScheduleLogic.tasksDueToday([t1, other, t2], dateYmd: "2026-05-23"), [t2, t1])
    }
}
