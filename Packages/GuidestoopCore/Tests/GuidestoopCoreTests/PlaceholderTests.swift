import XCTest
@testable import GuidestoopCore

final class PlaceholderTests: XCTestCase {
    func testVersionIsPositive() {
        XCTAssertGreaterThan(GuidestoopCoreVersion.current, 0)
    }
}
