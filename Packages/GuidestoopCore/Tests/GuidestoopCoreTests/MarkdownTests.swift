import XCTest
@testable import GuidestoopCore

final class MarkdownTests: XCTestCase {
    static let sampleTask = Task(
        id: "550e8400-e29b-41d4-a716-446655440000",
        title: "Write implementation spec",
        status: .focus,
        scheduled: "2026-05-23T09:00:00Z",
        duration: 90,
        project: "guidestoop",
        tags: ["spec", "writing"],
        created: "2026-05-23T08:00:00Z",
        updated: "2026-05-23T10:30:00Z",
        body: "Task body and notes.\n\n- [ ] sub-item"
    )

    static let sampleMarkdown = """
    ---
    id: 550e8400-e29b-41d4-a716-446655440000
    title: Write implementation spec
    status: focus
    scheduled: 2026-05-23T09:00:00Z
    duration: 90
    project: guidestoop
    tags:
      - spec
      - writing
    created: 2026-05-23T08:00:00Z
    updated: 2026-05-23T10:30:00Z
    ---

    Task body and notes.

    - [ ] sub-item
    """

    func testParsesSpecExample() throws {
        let task = try TaskMarkdown.parse(Self.sampleMarkdown)
        XCTAssertEqual(task, Self.sampleTask)
    }

    func testSerializesAndRoundTrips() throws {
        let md = try TaskMarkdown.serialize(Self.sampleTask)
        XCTAssertTrue(md.contains("status: focus"))
        XCTAssertTrue(md.contains("Task body and notes."))
        XCTAssertEqual(try TaskMarkdown.parse(md), Self.sampleTask)
    }

    func testRoundTripMinimalInboxTask() throws {
        let minimal = Task(
            id: "abc", title: "Quick task", status: .inbox,
            created: "2026-05-23T08:00:00Z", updated: "2026-05-23T08:00:00Z"
        )
        XCTAssertEqual(try TaskMarkdown.roundTrip(minimal), minimal)
    }

    func testRoundTripBlockedStatus() throws {
        var blocked = Self.sampleTask
        blocked.status = .blocked
        blocked.scheduled = nil
        blocked.tags = ["waiting"]
        XCTAssertEqual(try TaskMarkdown.roundTrip(blocked), blocked)
    }

    func testRejectsInvalidStatus() {
        let bad = Self.sampleMarkdown.replacingOccurrences(of: "status: focus", with: "status: invalid")
        XCTAssertThrowsError(try TaskMarkdown.parse(bad)) { error in
            XCTAssertTrue("\(error)".contains("status"))
        }
    }

    func testDeletedTaskRoundTrip() throws {
        let task = Self.sampleTask
        let deletedAt = "2026-05-23T10:00:00.000Z"
        let raw = try TaskMarkdown.serializeDeleted(task, deletedAt: deletedAt)
        let parsed = try TaskMarkdown.parseDeleted(raw)
        XCTAssertEqual(parsed.deletedAt, deletedAt)
        XCTAssertEqual(parsed.title, task.title)
    }
}
