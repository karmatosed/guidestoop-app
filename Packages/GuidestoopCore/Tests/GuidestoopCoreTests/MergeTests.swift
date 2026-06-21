import XCTest
@testable import GuidestoopCore

final class MergeTests: XCTestCase {
    let base = Task(
        id: "a", title: "Original", status: .inbox,
        created: "2026-05-23T08:00:00Z", updated: "2026-05-23T09:00:00Z"
    )

    func testAcceptsRemoteWhenLocalMissing() {
        XCTAssertTrue(MergeLogic.shouldAcceptRemote(local: nil, remote: base))
    }

    func testAcceptsRemoteWhenNewer() {
        let local = Task(id: base.id, title: "Local", status: .inbox,
                         created: base.created, updated: "2026-05-23T09:00:00Z")
        let remote = Task(id: base.id, title: "Remote", status: .inbox,
                          created: base.created, updated: "2026-05-23T10:00:00Z")
        XCTAssertTrue(MergeLogic.shouldAcceptRemote(local: local, remote: remote))
    }

    func testRejectsRemoteWhenLocalNewerAndDiffers() {
        let local = Task(id: base.id, title: "Local edit", status: .inbox,
                         created: base.created, updated: "2026-05-23T11:00:00Z")
        let remote = Task(id: base.id, title: "Remote edit", status: .inbox,
                          created: base.created, updated: "2026-05-23T10:00:00Z")
        XCTAssertFalse(MergeLogic.shouldAcceptRemote(local: local, remote: remote))
    }

    func testConflictFilenameFormat() {
        let name = MergeLogic.conflictFilename(id: "abc", timestamp: "2026-05-23T10:30:00.000Z")
        XCTAssertEqual(name, "abc.conflict.2026-05-23T10-30-00-000Z.md")
    }
}
