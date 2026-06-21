import XCTest
@testable import GuidestoopCore
@testable import GuidestoopStorage

final class IntegrationTests: XCTestCase {
    func testWriteAndReadTaskFile() async throws {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let adapter = ICloudAdapter(rootURL: tmp)
        try await adapter.ensureFolderStructure()

        let task = TaskFactory.create(title: "Integration test")
        let content = try TaskMarkdown.serialize(task)
        try await adapter.write(path: StoragePaths.taskPath(id: task.id), content: content)

        let read = try await adapter.read(path: StoragePaths.taskPath(id: task.id))
        let parsed = try TaskMarkdown.parse(read)
        XCTAssertEqual(parsed, task)
    }
}
