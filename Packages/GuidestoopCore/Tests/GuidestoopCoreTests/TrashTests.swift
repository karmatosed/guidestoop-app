import XCTest
@testable import GuidestoopCore

final class TrashTests: XCTestCase {
    func testRetentionIs30Days() {
        XCTAssertEqual(TrashLogic.retentionDays, 30)
    }

    func testExpiresAfter30Days() {
        let deletedAt = "2026-01-01T12:00:00.000Z"
        let before = Date(timeIntervalSince1970: 1_769_788_800) // 2026-01-30
        let after = Date(timeIntervalSince1970: 1_770_451_200)  // 2026-02-01
        XCTAssertFalse(TrashLogic.isTrashExpired(deletedAt: deletedAt, now: before))
        XCTAssertTrue(TrashLogic.isTrashExpired(deletedAt: deletedAt, now: after))
    }

    func testDaysUntilPurge() {
        let deletedAt = "2026-05-01T12:00:00.000Z"
        let day2 = Date(timeIntervalSince1970: 1_777_593_600)  // 2026-05-02
        let day30 = Date(timeIntervalSince1970: 1_780_012_800) // 2026-05-30
        let day31 = Date(timeIntervalSince1970: 1_780_099_200) // 2026-05-31
        XCTAssertEqual(TrashLogic.daysUntilPurge(deletedAt: deletedAt, now: day2), 29)
        XCTAssertEqual(TrashLogic.daysUntilPurge(deletedAt: deletedAt, now: day30), 1)
        XCTAssertEqual(TrashLogic.daysUntilPurge(deletedAt: deletedAt, now: day31), 0)
    }
}
