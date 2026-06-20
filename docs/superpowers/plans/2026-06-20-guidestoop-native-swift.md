# Guidestoop Native Swift App Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build an iOS SwiftUI app where tasks persist as YAML-frontmatter markdown files in a user-picked iCloud Drive folder, with full web feature parity and macOS-ready shared packages.

**Architecture:** Shared Swift packages (`GuidestoopCore`, `GuidestoopStorage`) hold models, markdown I/O, merge/schedule/trash logic, sync engine, and iCloud adapter. The iOS app target is a thin SwiftUI shell over SwiftData local cache + sync. No Guidestoop server in v1.

**Tech Stack:** Swift 5.9+, SwiftUI, SwiftData, Swift Package Manager, Yams (YAML), XCTest, NSFileCoordinator, security-scoped bookmarks

**Design spec:** `docs/superpowers/specs/2026-06-20-guidestoop-native-swift-design.md`

**Reference TypeScript:** `karmatosed/guidestoop` → `packages/task-core/`

---

## File Structure Overview

```
guidestoop-app/
├── Guidestoop.xcworkspace
├── Packages/
│   ├── GuidestoopCore/
│   │   ├── Package.swift
│   │   └── Sources/GuidestoopCore/
│   │       ├── Models/TaskStatus.swift
│   │       ├── Models/Task.swift
│   │       ├── Models/DeletedTask.swift
│   │       ├── Models/Project.swift
│   │       ├── Markdown/TaskMarkdown.swift
│   │       ├── Markdown/ProjectMarkdown.swift
│   │       ├── Merge/MergeLogic.swift
│   │       ├── Schedule/ScheduleLogic.swift
│   │       ├── Trash/TrashLogic.swift
│   │       ├── Factory/TaskFactory.swift
│   │       ├── Sync/OutboxOperation.swift
│   │       ├── Sync/SyncEngine.swift
│   │       └── Filters/TaskFilters.swift
│   └── GuidestoopStorage/
│       ├── Package.swift
│       └── Sources/GuidestoopStorage/
│           ├── StorageAdapter.swift
│           ├── StoragePaths.swift
│           ├── MetaFile.swift
│           ├── ICloudAdapter.swift
│           └── GitHubAdapter.swift          # stub only in v1
├── Apps/GuidestoopIOS/
│   ├── GuidestoopIOS.xcodeproj
│   ├── GuidestoopIOSApp.swift
│   ├── Data/
│   │   ├── CachedTask.swift                 # SwiftData @Model
│   │   ├── CachedProject.swift
│   │   ├── CachedDeletedTask.swift
│   │   ├── CachedOutboxEntry.swift
│   │   └── LocalStore.swift
│   ├── Services/
│   │   ├── AppEnvironment.swift
│   │   ├── FolderBookmarkStore.swift
│   │   └── SyncCoordinator.swift
│   ├── Onboarding/
│   │   └── OnboardingView.swift
│   ├── Views/
│   │   ├── AppShellView.swift
│   │   ├── TasksListView.swift
│   │   ├── KanbanView.swift
│   │   ├── DayTimelineView.swift
│   │   ├── TaskDetailView.swift
│   │   ├── ConflictBannerView.swift
│   │   ├── SettingsView.swift
│   │   └── Components/
│   │       ├── QuickAddField.swift
│   │       ├── TaskRowView.swift
│   │       ├── TagChipView.swift
│   │       └── SyncStatusBadge.swift
│   └── Theme/
│       └── GuidestoopTheme.swift
└── GuidestoopCoreTests/
    ├── MarkdownTests.swift
    ├── MergeTests.swift
    ├── ScheduleTests.swift
    ├── TrashTests.swift
    └── SyncEngineTests.swift
```

---

### Task 1: Xcode Workspace & Package Scaffolding

**Files:**
- Create: `Packages/GuidestoopCore/Package.swift`
- Create: `Packages/GuidestoopStorage/Package.swift`
- Create: `Apps/GuidestoopIOS/` (Xcode iOS app project)
- Create: `Guidestoop.xcworkspace`

- [ ] **Step 1: Create GuidestoopCore package**

```swift
// Packages/GuidestoopCore/Package.swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "GuidestoopCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "GuidestoopCore", targets: ["GuidestoopCore"]),
    ],
    dependencies: [
        .package(url: "https://github.com/jpsim/Yams.git", from: "5.1.0"),
    ],
    targets: [
        .target(
            name: "GuidestoopCore",
            dependencies: ["Yams"]
        ),
        .testTarget(
            name: "GuidestoopCoreTests",
            dependencies: ["GuidestoopCore"]
        ),
    ]
)
```

- [ ] **Step 2: Create GuidestoopStorage package**

```swift
// Packages/GuidestoopStorage/Package.swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "GuidestoopStorage",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "GuidestoopStorage", targets: ["GuidestoopStorage"]),
    ],
    dependencies: [
        .package(path: "../GuidestoopCore"),
    ],
    targets: [
        .target(
            name: "GuidestoopStorage",
            dependencies: ["GuidestoopCore"]
        ),
    ]
)
```

- [ ] **Step 3: Create iOS app in Xcode**

In Xcode: File → New → Project → iOS App. Product name `GuidestoopIOS`, SwiftUI, SwiftData enabled, minimum iOS 17. Save to `Apps/GuidestoopIOS/`.

Add local package dependencies to the app target:
- `Packages/GuidestoopCore`
- `Packages/GuidestoopStorage`

Enable iCloud capability: iCloud → iCloud Documents (for folder access).

Add to `Info.plist`:
```xml
<key>UISupportsDocumentBrowser</key>
<true/>
<key>LSSupportsOpeningDocumentsInPlace</key>
<true/>
```

- [ ] **Step 4: Verify build**

Run: `xcodebuild -scheme GuidestoopIOS -destination 'platform=iOS Simulator,name=iPhone 16' build`
Expected: BUILD SUCCEEDED

- [ ] **Step 5: Commit**

```bash
git add Packages/ Apps/ Guidestoop.xcworkspace
git commit -m "chore: scaffold Xcode workspace and Swift packages"
```

---

### Task 2: Core Models

**Files:**
- Create: `Packages/GuidestoopCore/Sources/GuidestoopCore/Models/TaskStatus.swift`
- Create: `Packages/GuidestoopCore/Sources/GuidestoopCore/Models/Task.swift`
- Create: `Packages/GuidestoopCore/Sources/GuidestoopCore/Models/DeletedTask.swift`
- Create: `Packages/GuidestoopCore/Sources/GuidestoopCore/Models/Project.swift`

- [ ] **Step 1: Write TaskStatus**

```swift
// Packages/GuidestoopCore/Sources/GuidestoopCore/Models/TaskStatus.swift
import Foundation

public enum TaskStatus: String, Codable, CaseIterable, Sendable {
    case inbox, blocked, focus, scheduled, done

    public static func isValid(_ raw: String) -> Bool {
        TaskStatus(rawValue: raw) != nil
    }
}
```

- [ ] **Step 2: Write Task model**

```swift
// Packages/GuidestoopCore/Sources/GuidestoopCore/Models/Task.swift
import Foundation

public struct Task: Codable, Identifiable, Equatable, Sendable {
    public var id: String
    public var title: String
    public var status: TaskStatus
    public var scheduled: String?
    public var duration: Int?
    public var project: String?
    public var tags: [String]
    public var created: String
    public var updated: String
    public var body: String

    public init(
        id: String,
        title: String,
        status: TaskStatus,
        scheduled: String? = nil,
        duration: Int? = nil,
        project: String? = nil,
        tags: [String] = [],
        created: String,
        updated: String,
        body: String = ""
    ) {
        self.id = id
        self.title = title
        self.status = status
        self.scheduled = scheduled
        self.duration = duration
        self.project = project
        self.tags = tags
        self.created = created
        self.updated = updated
        self.body = body
    }
}
```

- [ ] **Step 3: Write DeletedTask and Project**

```swift
// Packages/GuidestoopCore/Sources/GuidestoopCore/Models/DeletedTask.swift
import Foundation

public struct DeletedTask: Codable, Identifiable, Equatable, Sendable {
    public var id: String
    public var title: String
    public var status: TaskStatus
    public var scheduled: String?
    public var duration: Int?
    public var project: String?
    public var tags: [String]
    public var created: String
    public var updated: String
    public var deletedAt: String
    public var body: String

    public var asTask: Task {
        Task(
            id: id, title: title, status: status,
            scheduled: scheduled, duration: duration,
            project: project, tags: tags,
            created: created, updated: updated, body: body
        )
    }
}
```

```swift
// Packages/GuidestoopCore/Sources/GuidestoopCore/Models/Project.swift
import Foundation

public struct Project: Codable, Identifiable, Equatable, Sendable {
    public var id: String       // proj-{slug}
    public var name: String
    public var color: String?
    public var created: String
    public var updated: String
    public var body: String
}
```

- [ ] **Step 4: Build packages**

Run: `swift build --package-path Packages/GuidestoopCore`
Expected: Build complete

- [ ] **Step 5: Commit**

```bash
git add Packages/GuidestoopCore/Sources/GuidestoopCore/Models/
git commit -m "feat(core): add Task, Project, DeletedTask models"
```

---

### Task 3: Markdown Parse & Serialize (TDD)

**Files:**
- Create: `Packages/GuidestoopCore/Tests/GuidestoopCoreTests/MarkdownTests.swift`
- Create: `Packages/GuidestoopCore/Sources/GuidestoopCore/Markdown/TaskMarkdown.swift`

Port from: `packages/task-core/src/markdown.ts` and `packages/task-core/tests/markdown.test.ts`

- [ ] **Step 1: Write failing markdown tests**

```swift
// Packages/GuidestoopCore/Tests/GuidestoopCoreTests/MarkdownTests.swift
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
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --package-path Packages/GuidestoopCore --filter MarkdownTests`
Expected: FAIL — `TaskMarkdown` not found

- [ ] **Step 3: Implement TaskMarkdown**

```swift
// Packages/GuidestoopCore/Sources/GuidestoopCore/Markdown/TaskMarkdown.swift
import Foundation
import Yams

public enum TaskMarkdownError: Error, LocalizedError {
    case missingFrontmatter
    case invalidFrontmatter
    case missingField(String)
    case invalidStatus

    public var errorDescription: String? {
        switch self {
        case .missingFrontmatter: return "Task markdown must start with YAML frontmatter (---)"
        case .invalidFrontmatter: return "Invalid task frontmatter"
        case .missingField(let f): return "Task frontmatter \"\(f)\" must be a non-empty string"
        case .invalidStatus: return "Task frontmatter \"status\" must be one of: inbox, blocked, focus, scheduled, done"
        }
    }
}

public enum TaskMarkdown {
    private static let frontmatterRegex = try! NSRegularExpression(
        pattern: #"^---\r?\n([\s\S]*?)\r?\n---(?:\r?\n([\s\S]*))?$"#
    )

    public static func parse(_ raw: String) throws -> Task {
        let (data, content) = try splitFrontmatter(raw)
        return Task(
            id: try coerceString(data["id"], field: "id"),
            title: try coerceString(data["title"], field: "title"),
            status: try parseStatus(data["status"]),
            scheduled: parseOptionalString(data["scheduled"]),
            duration: parseOptionalInt(data["duration"]),
            project: parseOptionalString(data["project"]),
            tags: parseTags(data["tags"]),
            created: try coerceString(data["created"], field: "created"),
            updated: try coerceString(data["updated"], field: "updated"),
            body: normalizeBody(content)
        )
    }

    public static func serialize(_ task: Task) throws -> String {
        var fm: [String: Any] = [
            "id": task.id,
            "title": task.title,
            "status": task.status.rawValue,
            "created": task.created,
            "updated": task.updated,
        ]
        if let scheduled = task.scheduled { fm["scheduled"] = scheduled }
        if let duration = task.duration { fm["duration"] = duration }
        if let project = task.project { fm["project"] = project }
        if !task.tags.isEmpty { fm["tags"] = task.tags }

        let yaml = try Yams.dump(object: fm, allowUnicode: true)
        let body = task.body.isEmpty ? "" : "\n\(task.body)"
        return "---\n\(yaml.trimmingCharacters(in: .whitespacesAndNewlines))\n---\(body)\n"
    }

    public static func roundTrip(_ task: Task) throws -> Task {
        try parse(serialize(task))
    }

    public static func parseDeleted(_ raw: String) throws -> DeletedTask {
        let (data, content) = try splitFrontmatter(raw)
        return DeletedTask(
            id: try coerceString(data["id"], field: "id"),
            title: try coerceString(data["title"], field: "title"),
            status: try parseStatus(data["status"]),
            scheduled: parseOptionalString(data["scheduled"]),
            duration: parseOptionalInt(data["duration"]),
            project: parseOptionalString(data["project"]),
            tags: parseTags(data["tags"]),
            created: try coerceString(data["created"], field: "created"),
            updated: try coerceString(data["updated"], field: "updated"),
            deletedAt: try coerceString(data["deletedAt"], field: "deletedAt"),
            body: normalizeBody(content)
        )
    }

    public static func serializeDeleted(_ task: Task, deletedAt: String) throws -> String {
        var fm: [String: Any] = [
            "id": task.id, "title": task.title,
            "status": task.status.rawValue,
            "created": task.created, "updated": task.updated,
            "deletedAt": deletedAt,
        ]
        if let scheduled = task.scheduled { fm["scheduled"] = scheduled }
        if let duration = task.duration { fm["duration"] = duration }
        if let project = task.project { fm["project"] = project }
        if !task.tags.isEmpty { fm["tags"] = task.tags }
        let yaml = try Yams.dump(object: fm, allowUnicode: true)
        let body = task.body.isEmpty ? "" : "\n\(task.body)"
        return "---\n\(yaml.trimmingCharacters(in: .whitespacesAndNewlines))\n---\(body)\n"
    }

    public static func contentEqual(_ a: Task, _ b: Task) throws -> Bool {
        let stamp = "1970-01-01T00:00:00.000Z"
        var aa = a; aa.updated = stamp
        var bb = b; bb.updated = stamp
        return try serialize(aa) == serialize(bb)
    }

    // MARK: - Private helpers

    private static func splitFrontmatter(_ raw: String) throws -> ([String: Any], String) {
        let trimmed = raw.hasPrefix("\u{FEFF}") ? String(raw.dropFirst()) : raw
        let range = NSRange(trimmed.startIndex..., in: trimmed)
        guard let match = frontmatterRegex.firstMatch(in: trimmed, range: range),
              let fmRange = Range(match.range(at: 1), in: trimmed) else {
            throw TaskMarkdownError.missingFrontmatter
        }
        let contentRange = match.range(at: 2).location != NSNotFound
            ? Range(match.range(at: 2), in: trimmed)! : trimmed.endIndex..<trimmed.endIndex
        let fmText = String(trimmed[fmRange])
        let content = String(trimmed[contentRange])
        guard let loaded = try Yams.load(yaml: fmText) as? [String: Any] else {
            throw TaskMarkdownError.invalidFrontmatter
        }
        return (loaded, content)
    }

    private static func coerceString(_ value: Any?, field: String) throws -> String {
        guard let s = value as? String, !s.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw TaskMarkdownError.missingField(field)
        }
        return s
    }

    private static func parseOptionalString(_ value: Any?) -> String? {
        guard let v = value, !(v is NSNull) else { return nil }
        let s = "\(v)"
        return s.isEmpty ? nil : s
    }

    private static func parseOptionalInt(_ value: Any?) -> Int? {
        if value == nil || value is NSNull { return nil }
        if let i = value as? Int { return i }
        if let d = value as? Double { return Int(d) }
        if let s = value as? String, let i = Int(s) { return i }
        return nil
    }

    private static func parseTags(_ value: Any?) -> [String] {
        guard let arr = value as? [Any] else { return [] }
        var out: [String] = []
        for item in arr {
            guard let s = item as? String else { continue }
            let t = s.trimmingCharacters(in: .whitespaces)
            if !t.isEmpty && !out.contains(t) { out.append(t) }
        }
        return out
    }

    private static func parseStatus(_ value: Any?) throws -> TaskStatus {
        guard let s = value as? String, let status = TaskStatus(rawValue: s) else {
            throw TaskMarkdownError.invalidStatus
        }
        return status
    }

    private static func normalizeBody(_ content: String) -> String {
        var c = content
        if c.hasPrefix("\n") { c.removeFirst() }
        return c.trimmingCharacters(in: .newlines).trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\r\n", with: "\n")
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --package-path Packages/GuidestoopCore --filter MarkdownTests`
Expected: All 6 tests PASS

- [ ] **Step 5: Commit**

```bash
git add Packages/GuidestoopCore/Sources/GuidestoopCore/Markdown/ \
        Packages/GuidestoopCore/Tests/GuidestoopCoreTests/MarkdownTests.swift
git commit -m "feat(core): add task markdown parse/serialize with round-trip tests"
```

---

### Task 4: Merge Logic (TDD)

**Files:**
- Create: `Packages/GuidestoopCore/Tests/GuidestoopCoreTests/MergeTests.swift`
- Create: `Packages/GuidestoopCore/Sources/GuidestoopCore/Merge/MergeLogic.swift`

Port from: `packages/task-core/src/merge.ts`

- [ ] **Step 1: Write failing merge tests**

```swift
// Packages/GuidestoopCore/Tests/GuidestoopCoreTests/MergeTests.swift
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
```

- [ ] **Step 2: Run tests — expect FAIL**

Run: `swift test --package-path Packages/GuidestoopCore --filter MergeTests`

- [ ] **Step 3: Implement MergeLogic**

```swift
// Packages/GuidestoopCore/Sources/GuidestoopCore/Merge/MergeLogic.swift
import Foundation

public enum MergeLogic {
    public static func shouldAcceptRemote(local: Task?, remote: Task) -> Bool {
        guard let local else { return true }
        if (try? TaskMarkdown.contentEqual(local, remote)) == true { return true }
        return remote.updated >= local.updated
    }

    public static func conflictFilename(id: String, timestamp: String) -> String {
        let safe = timestamp.replacingOccurrences(of: ":", with: "-")
                            .replacingOccurrences(of: ".", with: "-")
        return "\(id).conflict.\(safe).md"
    }
}
```

- [ ] **Step 4: Run tests — expect PASS**

- [ ] **Step 5: Commit**

```bash
git commit -m "feat(core): add merge logic and conflict filename generation"
```

---

### Task 5: Schedule & Trash Logic (TDD)

**Files:**
- Create: `Packages/GuidestoopCore/Sources/GuidestoopCore/Schedule/ScheduleLogic.swift`
- Create: `Packages/GuidestoopCore/Sources/GuidestoopCore/Trash/TrashLogic.swift`
- Create: `Packages/GuidestoopCore/Tests/GuidestoopCoreTests/ScheduleTests.swift`
- Create: `Packages/GuidestoopCore/Tests/GuidestoopCoreTests/TrashTests.swift`
- Create: `Packages/GuidestoopCore/Sources/GuidestoopCore/Factory/TaskFactory.swift`

- [ ] **Step 1: Write ScheduleTests and TrashTests**

```swift
// Packages/GuidestoopCore/Tests/GuidestoopCoreTests/ScheduleTests.swift
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
```

```swift
// Packages/GuidestoopCore/Tests/GuidestoopCoreTests/TrashTests.swift
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
```

- [ ] **Step 2: Run tests — expect FAIL**

- [ ] **Step 3: Implement**

```swift
// ScheduleLogic.swift
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
```

```swift
// TrashLogic.swift
public enum TrashLogic {
    public static let retentionDays = 30
    private static let retentionMs: TimeInterval = Double(retentionDays) * 24 * 60 * 60 * 1000

    public static func isTrashExpired(deletedAt: String, now: Date = Date()) -> Bool {
        guard let deleted = ISO8601DateFormatter().date(from: deletedAt) else { return true }
        return now.timeIntervalSince(deleted) >= retentionMs
    }

    public static func daysUntilPurge(deletedAt: String, now: Date = Date()) -> Int {
        guard let deleted = ISO8601DateFormatter().date(from: deletedAt) else { return 0 }
        let remaining = retentionMs - now.timeIntervalSince(deleted)
        return max(0, Int(ceil(remaining / (24 * 60 * 60))))
    }
}
```

```swift
// TaskFactory.swift
public enum TaskFactory {
    public static func create(title: String, body: String = "", status: TaskStatus = .inbox) -> Task {
        let now = ISO8601DateFormatter().string(from: Date())
        return Task(
            id: UUID().uuidString.lowercased(),
            title: title, status: status,
            created: now, updated: now, body: body
        )
    }
}
```

- [ ] **Step 4: Run all core tests — expect PASS**

Run: `swift test --package-path Packages/GuidestoopCore`
Expected: All tests PASS

- [ ] **Step 5: Commit**

```bash
git commit -m "feat(core): add schedule, trash, and task factory logic"
```

---

### Task 6: StorageAdapter Protocol & Paths

**Files:**
- Create: `Packages/GuidestoopStorage/Sources/GuidestoopStorage/StorageAdapter.swift`
- Create: `Packages/GuidestoopStorage/Sources/GuidestoopStorage/StoragePaths.swift`
- Create: `Packages/GuidestoopStorage/Sources/GuidestoopStorage/MetaFile.swift`
- Create: `Packages/GuidestoopStorage/Sources/GuidestoopStorage/GitHubAdapter.swift`

- [ ] **Step 1: Define StoragePaths**

```swift
// StoragePaths.swift
import Foundation

public enum StoragePaths {
    public static let tasksDir = "tasks"
    public static let deletedDir = "tasks/deleted"
    public static let projectsDir = "projects"
    public static let metaDir = "_meta"
    public static let metaFile = "_meta/guidestoop.json"

    public static func taskPath(id: String) -> String { "/tasks/\(id).md" }
    public static func deletedTaskPath(id: String) -> String { "/tasks/deleted/\(id).md" }
    public static func projectPath(slug: String) -> String { "/projects/\(slug).md" }
    public static func isConflictFile(_ filename: String) -> Bool {
        filename.contains(".conflict.")
    }
}
```

- [ ] **Step 2: Define StorageAdapter protocol**

```swift
// StorageAdapter.swift
import GuidestoopCore

public struct RemoteFile: Sendable {
    public let path: String
    public let content: String
    public let modifiedAt: Date?
}

public struct FolderMeta: Codable, Sendable {
    public var schemaVersion: Int
    public var lastSyncedAt: String?
    public init(schemaVersion: Int = 1, lastSyncedAt: String? = nil) {
        self.schemaVersion = schemaVersion
        self.lastSyncedAt = lastSyncedAt
    }
}

public protocol StorageAdapter: Sendable {
    func ensureFolderStructure() async throws
    func listFiles() async throws -> [RemoteFile]
    func read(path: String) async throws -> String
    func write(path: String, content: String) async throws
    func delete(path: String) async throws
    func readMeta() async throws -> FolderMeta
    func writeMeta(_ meta: FolderMeta) async throws
}
```

- [ ] **Step 3: Add GitHubAdapter stub**

```swift
// GitHubAdapter.swift — phase 2 stub
public struct GitHubAdapter: StorageAdapter {
    public init() {}
    public func ensureFolderStructure() async throws {
        throw StorageError.notImplemented("GitHub storage coming in phase 2")
    }
    // ... all methods throw notImplemented
}

public enum StorageError: Error {
    case notImplemented(String)
    case folderNotConfigured
    case readFailed(String)
    case writeFailed(String)
}
```

- [ ] **Step 4: Commit**

```bash
git commit -m "feat(storage): add StorageAdapter protocol and path helpers"
```

---

### Task 7: ICloudAdapter

**Files:**
- Create: `Packages/GuidestoopStorage/Sources/GuidestoopStorage/ICloudAdapter.swift`
- Create: `Apps/GuidestoopIOS/Services/FolderBookmarkStore.swift`

- [ ] **Step 1: Implement FolderBookmarkStore (Keychain)**

```swift
// Apps/GuidestoopIOS/Services/FolderBookmarkStore.swift
import Foundation

enum FolderBookmarkStore {
    private static let key = "guidestoop.folder.bookmark"

    static func save(url: URL) throws {
        let data = try url.bookmarkData(
            options: .minimalBookmark,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        UserDefaults.standard.set(data, forKey: key)
    }

    static func resolve() throws -> URL {
        guard let data = UserDefaults.standard.data(forKey: key) else {
            throw StorageError.folderNotConfigured
        }
        var stale = false
        let url = try URL(
            resolvingBookmarkData: data,
            options: .withoutUI,
            relativeTo: nil,
            bookmarkDataIsStale: &stale
        )
        guard url.startAccessingSecurityScopedResource() else {
            throw StorageError.folderNotConfigured
        }
        return url
    }

    static var isConfigured: Bool {
        UserDefaults.standard.data(forKey: key) != nil
    }
}
```

- [ ] **Step 2: Implement ICloudAdapter**

```swift
// Packages/GuidestoopStorage/Sources/GuidestoopStorage/ICloudAdapter.swift
import Foundation
import GuidestoopCore

public final class ICloudAdapter: StorageAdapter, @unchecked Sendable {
    private let rootURL: URL
    private let coordinator = NSFileCoordinator()
    private let fm = FileManager.default

    public init(rootURL: URL) {
        self.rootURL = rootURL
    }

    public static func defaultFolderURL() throws -> URL {
        guard let container = FileManager.default.url(forUbiquityContainerIdentifier: nil) else {
            throw StorageError.folderNotConfigured
        }
        return container.appendingPathComponent("Documents/Guidestoop", isDirectory: true)
    }

    public func ensureFolderStructure() async throws {
        for dir in [StoragePaths.tasksDir, StoragePaths.deletedDir,
                    StoragePaths.projectsDir, StoragePaths.metaDir] {
            let url = rootURL.appendingPathComponent(dir, isDirectory: true)
            try fm.createDirectory(at: url, withIntermediateDirectories: true)
        }
        if try !fm.fileExists(atPath: rootURL.appendingPathComponent(StoragePaths.metaFile).path) {
            try await writeMeta(FolderMeta())
        }
    }

    public func listFiles() async throws -> [RemoteFile] {
        var results: [RemoteFile] = []
        let enumerator = fm.enumerator(at: rootURL, includingPropertiesForKeys: [.contentModificationDateKey])
        while let url = enumerator?.nextObject() as? URL {
            guard url.pathExtension == "md" else { continue }
            let rel = "/" + url.path.replacingOccurrences(of: rootURL.path + "/", with: "")
            let content = try await read(path: rel)
            let mod = try url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
            results.append(RemoteFile(path: rel, content: content, modifiedAt: mod))
        }
        return results
    }

    public func read(path: String) async throws -> String {
        let url = rootURL.appendingPathComponent(path.trimmingCharacters(in: CharacterSet(charactersIn: "/")))
        var result = ""
        var error: NSError?
        coordinator.coordinate(readingItemAt: url, options: [], error: &error) { readURL in
            result = (try? String(contentsOf: readURL, encoding: .utf8)) ?? ""
        }
        if let error { throw StorageError.readFailed(error.localizedDescription) }
        return result
    }

    public func write(path: String, content: String) async throws {
        let url = rootURL.appendingPathComponent(path.trimmingCharacters(in: CharacterSet(charactersIn: "/")))
        try fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        var error: NSError?
        coordinator.coordinate(writingItemAt: url, options: .forReplacing, error: &error) { writeURL in
            try? content.write(to: writeURL, atomically: true, encoding: .utf8)
        }
        if let error { throw StorageError.writeFailed(error.localizedDescription) }
    }

    public func delete(path: String) async throws {
        let url = rootURL.appendingPathComponent(path.trimmingCharacters(in: CharacterSet(charactersIn: "/")))
        var error: NSError?
        coordinator.coordinate(writingItemAt: url, options: .forDeleting, error: &error) { deleteURL in
            try? fm.removeItem(at: deleteURL)
        }
        if let error { throw StorageError.writeFailed(error.localizedDescription) }
    }

    public func readMeta() async throws -> FolderMeta {
        let raw = try await read(path: StoragePaths.metaFile)
        return try JSONDecoder().decode(FolderMeta.self, from: Data(raw.utf8))
    }

    public func writeMeta(_ meta: FolderMeta) async throws {
        let data = try JSONEncoder().encode(meta)
        try await write(path: StoragePaths.metaFile, content: String(decoding: data, as: UTF8.self))
    }
}
```

- [ ] **Step 3: Manual smoke test**

Create a test folder in simulator iCloud container, write a task file, read it back.

- [ ] **Step 4: Commit**

```bash
git commit -m "feat(storage): add ICloudAdapter with security-scoped bookmarks"
```

---

### Task 8: SyncEngine & Outbox (TDD)

**Files:**
- Create: `Packages/GuidestoopCore/Sources/GuidestoopCore/Sync/OutboxOperation.swift`
- Create: `Packages/GuidestoopCore/Sources/GuidestoopCore/Sync/SyncEngine.swift`
- Create: `Packages/GuidestoopCore/Tests/GuidestoopCoreTests/SyncEngineTests.swift`

Port merge cycle from: `packages/task-core/src/storage/markdown-storage-adapter.ts`

- [ ] **Step 1: Define OutboxOperation**

```swift
public enum OutboxOp: String, Codable, Sendable {
    case save, delete, restore, purge
}

public struct OutboxOperation: Identifiable, Sendable {
    public let id: String
    public let op: OutboxOp
    public let taskId: String
    public let payload: String?   // serialized markdown for save/restore
}
```

- [ ] **Step 2: Write SyncEngineTests**

Test scenarios:
- Flush outbox writes pending save to adapter
- Remote newer + different content → conflict file created, local kept
- Trashed task removed from active folder
- Expired trash (>30 days) purged on sync
- Merge result replaces local task list

- [ ] **Step 3: Implement SyncEngine**

```swift
public struct SyncResult: Sendable {
    public var tasks: [Task]
    public var deletedTasks: [DeletedTask]
    public var projects: [Project]
    public var conflicts: [String]   // conflict file paths
}

public struct SyncEngine {
    public static func sync(
        adapter: StorageAdapter,
        localTasks: [Task],
        localDeleted: [DeletedTask],
        outbox: [OutboxOperation]
    ) async throws -> SyncResult {
        // 1. Flush outbox
        // 2. List remote files
        // 3. Parse tasks, deleted, projects, conflicts
        // 4. Merge by updated timestamp + MergeLogic.shouldAcceptRemote
        // 5. On reject → write conflict copy via adapter
        // 6. Purge expired trash
        // 7. Push local changes not on remote
        // 8. Return merged SyncResult
    }
}
```

- [ ] **Step 4: Run SyncEngineTests — expect PASS**

- [ ] **Step 5: Commit**

```bash
git commit -m "feat(core): add SyncEngine with outbox flush and conflict handling"
```

---

### Task 9: SwiftData Local Cache

**Files:**
- Create: `Apps/GuidestoopIOS/Data/CachedTask.swift`
- Create: `Apps/GuidestoopIOS/Data/CachedProject.swift`
- Create: `Apps/GuidestoopIOS/Data/CachedDeletedTask.swift`
- Create: `Apps/GuidestoopIOS/Data/CachedOutboxEntry.swift`
- Create: `Apps/GuidestoopIOS/Data/LocalStore.swift`
- Create: `Apps/GuidestoopIOS/Services/SyncCoordinator.swift`

- [ ] **Step 1: Define SwiftData models**

```swift
@Model final class CachedTask {
    @Attribute(.unique) var id: String
    var title: String
    var statusRaw: String
    var scheduled: String?
    var duration: Int?
    var project: String?
    var tags: [String]
    var created: String
    var updated: String
    var body: String

    var status: TaskStatus {
        get { TaskStatus(rawValue: statusRaw) ?? .inbox }
        set { statusRaw = newValue.rawValue }
    }

    func toTask() -> Task { /* map fields */ }
    static func from(_ task: Task) -> CachedTask { /* map fields */ }
}
```

Mirror for `CachedProject`, `CachedDeletedTask`, `CachedOutboxEntry`.

- [ ] **Step 2: Implement LocalStore**

Methods:
- `replaceAll(tasks:deleted:projects:)` — wipe and insert from SyncResult
- `saveTask(_ task:)` — upsert + queue outbox `.save`
- `deleteTask(id:)` — move to deleted + queue `.delete`
- `restoreTask(id:)` — queue `.restore`
- `purgeTask(id:)` — queue `.purge`
- `pendingOutboxCount() -> Int`

- [ ] **Step 3: Implement SyncCoordinator**

```swift
@MainActor
final class SyncCoordinator: ObservableObject {
    @Published var lastSyncedAt: Date?
    @Published var isSyncing = false
    @Published var outboxCount = 0
    @Published var conflictPaths: [String] = []

    func syncNow() async throws { /* adapter + SyncEngine + LocalStore.replaceAll */ }
}
```

- [ ] **Step 4: Wire into GuidestoopIOSApp.swift modelContainer**

- [ ] **Step 5: Commit**

```bash
git commit -m "feat(ios): add SwiftData local cache and sync coordinator"
```

---

### Task 10: Onboarding Flow

**Files:**
- Create: `Apps/GuidestoopIOS/Onboarding/OnboardingView.swift`
- Modify: `Apps/GuidestoopIOS/GuidestoopIOSApp.swift`

- [ ] **Step 1: Build OnboardingView**

Screens:
1. Welcome — "Your tasks live as markdown files in iCloud Drive."
2. Two buttons: **Use Default Folder** | **Choose Folder**
3. Default creates `Documents/Guidestoop/` in iCloud container with subfolders
4. Choose opens `.fileImporter(isPresented:allowedContentTypes:[.folder])`
5. On success → save bookmark → run initial sync → dismiss

- [ ] **Step 2: Gate app root on FolderBookmarkStore.isConfigured**

```swift
@main
struct GuidestoopIOSApp: App {
    var body: some Scene {
        WindowGroup {
            if FolderBookmarkStore.isConfigured {
                AppShellView()
            } else {
                OnboardingView()
            }
        }
        .modelContainer(for: [CachedTask.self, CachedProject.self, CachedDeletedTask.self, CachedOutboxEntry.self])
    }
}
```

- [ ] **Step 3: Test on simulator** — default folder created, initial sync populates empty list

- [ ] **Step 4: Commit**

```bash
git commit -m "feat(ios): add onboarding with default and custom iCloud folder"
```

---

### Task 11: Theme & App Shell

**Files:**
- Create: `Apps/GuidestoopIOS/Theme/GuidestoopTheme.swift`
- Create: `Apps/GuidestoopIOS/Views/AppShellView.swift`
- Create: `Apps/GuidestoopIOS/Views/Components/SyncStatusBadge.swift`

- [ ] **Step 1: Define GuidestoopTheme**

Dark-first colors (reference web `global.css`):
```swift
enum GuidestoopTheme {
    static let background = Color(red: 0.08, green: 0.08, blue: 0.09)
    static let surface = Color(red: 0.12, green: 0.12, blue: 0.13)
    static let textPrimary = Color(red: 0.92, green: 0.91, blue: 0.88)
    static let textSecondary = Color(red: 0.55, green: 0.54, blue: 0.52)
    static let accent = Color(red: 0.55, green: 0.72, blue: 0.85)
    static let dashedBorder = Color(red: 0.30, green: 0.30, blue: 0.32)
}
```

- [ ] **Step 2: Build AppShellView**

Tab bar or segmented control: **List** | **Kanban** | **Day** | **Settings**
Top bar: lowercase "g" mark, SyncStatusBadge, search button
ConflictBannerView when `conflictPaths` non-empty

- [ ] **Step 3: Commit**

```bash
git commit -m "feat(ios): add app shell, theme, and sync status badge"
```

---

### Task 12: List View

**Files:**
- Create: `Apps/GuidestoopIOS/Views/TasksListView.swift`
- Create: `Apps/GuidestoopIOS/Views/Components/TaskRowView.swift`
- Create: `Apps/GuidestoopIOS/Views/Components/QuickAddField.swift`
- Create: `Apps/GuidestoopIOS/Views/Components/TagChipView.swift`
- Create: `Packages/GuidestoopCore/Sources/GuidestoopCore/Filters/TaskFilters.swift`

- [ ] **Step 1: Implement TaskFilters**

Port from `apps/web/src/lib/task-filters.ts`:
- `filterByTab(tasks, tab)` — all, inbox, blocked, today, done
- `filterBySearch(tasks, query)` — title, body, project, tags
- `filterByTag(tasks, tag)` — tag chip filter
- `allTags(tasks) -> [String]` — unique sorted tags

- [ ] **Step 2: Build TasksListView**

- Tab picker: All | Inbox | Blocked | Today | Done | Trash
- `@Query` SwiftData tasks filtered by tab
- TaskRowView with checkbox (toggle done ↔ inbox/other)
- QuickAddField at top (dashed border style)
- Search bar + tag chips
- Tap row → TaskDetailView sheet

- [ ] **Step 3: Trash tab** shows `CachedDeletedTask` with days-until-purge from `TrashLogic`

- [ ] **Step 4: Commit**

```bash
git commit -m "feat(ios): add task list view with tabs, search, and tags"
```

---

### Task 13: Kanban View

**Files:**
- Create: `Apps/GuidestoopIOS/Views/KanbanView.swift`

- [ ] **Step 1: Build KanbanView**

5 columns: inbox, blocked, focus, scheduled, done
Each column: header label + scrollable task cards + QuickAddField
Drag-and-drop via `.draggable` / `.dropDestination` — on drop, update task status + save

- [ ] **Step 2: Test drag inbox → focus updates status and writes markdown file**

- [ ] **Step 3: Commit**

```bash
git commit -m "feat(ios): add kanban view with drag-to-change-status"
```

---

### Task 14: Day Timeline View

**Files:**
- Create: `Apps/GuidestoopIOS/Views/DayTimelineView.swift`

- [ ] **Step 1: Build DayTimelineView**

- Date picker (default today)
- Timeline sorted by `ScheduleLogic.tasksDueToday` + focus tasks for that day
- QuickAddField pre-fills scheduled date for selected day
- Duration shown as time block if set

- [ ] **Step 2: Commit**

```bash
git commit -m "feat(ios): add day timeline view"
```

---

### Task 15: Task Detail View

**Files:**
- Create: `Apps/GuidestoopIOS/Views/TaskDetailView.swift`

- [ ] **Step 1: Build TaskDetailView with two tabs**

**Form tab:**
- Title text field
- Status picker (all 5 statuses)
- Schedule: date picker + optional time toggle
- Duration stepper (minutes)
- Project text field
- Tags: comma-separated or chip input
- Body: TextEditor

**Markdown tab:**
- Raw serialized markdown (read-only display of `TaskMarkdown.serialize`)
- Optional: editable raw text with re-parse on save

- [ ] **Step 2: Save on dismiss** — update `updated` timestamp, write via LocalStore

- [ ] **Step 3: iPad layout** — use `.navigationSplitView` column when horizontal size class is regular

- [ ] **Step 4: Commit**

```bash
git commit -m "feat(ios): add task detail with form and markdown tabs"
```

---

### Task 16: Settings, Conflicts & Manual Sync

**Files:**
- Create: `Apps/GuidestoopIOS/Views/SettingsView.swift`
- Create: `Apps/GuidestoopIOS/Views/ConflictBannerView.swift`

- [ ] **Step 1: Build SettingsView**

Sections:
- **Storage:** "iCloud Drive" + folder path display + "Change Folder" button
- **Sync:** Manual sync button, last synced timestamp, outbox pending count
- **Appearance:** Dark mode (System / Light / Dark)
- **About:** "Switch to GitHub" — disabled, "Coming in a future update"
- **Trash:** link to trash tab

- [ ] **Step 2: Build ConflictBannerView**

When conflict files exist:
- Calm banner (not red — use accent/warning tone): "2 tasks edited elsewhere"
- Tap → list conflict files
- Detail shows local vs remote side-by-side
- "Keep mine" / "Keep remote" → writes winner, deletes conflict file

- [ ] **Step 3: Commit**

```bash
git commit -m "feat(ios): add settings, conflict resolution, and manual sync"
```

---

### Task 17: External Edit Detection

**Files:**
- Modify: `Packages/GuidestoopStorage/Sources/GuidestoopStorage/ICloudAdapter.swift`
- Modify: `Apps/GuidestoopIOS/Services/SyncCoordinator.swift`

- [ ] **Step 1: Add NSFilePresenter to ICloudAdapter**

Register presenter on `tasks/` directory. On `presentedItemDidChange`, debounce 1s then trigger `syncNow()`.

- [ ] **Step 2: Test manually**

Edit a task `.md` file in Files app → app re-syncs within ~1s → UI updates.

- [ ] **Step 3: Commit**

```bash
git commit -m "feat(storage): watch iCloud folder for external edits"
```

---

### Task 18: Integration Test & Manual QA Checklist

**Files:**
- Create: `Packages/GuidestoopCore/Tests/GuidestoopCoreTests/IntegrationTests.swift`

- [ ] **Step 1: Write disk round-trip integration test**

```swift
func testWriteAndReadTaskFile() async throws {
    let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
    let adapter = ICloudAdapter(rootURL: tmp)
    try await adapter.ensureFolderStructure()

    let task = TaskFactory.create(title: "Integration test")
    let content = try TaskMarkdown.serialize(task)
    try await adapter.write(path: StoragePaths.taskPath(id: task.id), content: content)

    let read = try await adapter.read(path: StoragePaths.taskPath(id: task.id))
    let parsed = try TaskMarkdown.parse(read)
    XCTAssertEqual(parsed, task)
}
```

- [ ] **Step 2: Run full test suite**

Run: `swift test --package-path Packages/GuidestoopCore`
Expected: All PASS

- [ ] **Step 3: Manual QA checklist**

- [ ] Onboarding: default folder + custom folder
- [ ] Quick-add creates `.md` file in iCloud folder
- [ ] Edit task in app → file updated on disk
- [ ] Edit file in Files app → app reflects change
- [ ] Conflict: edit same task on two devices → conflict copy created
- [ ] Trash: delete → 30-day retention → restore → permanent delete
- [ ] Offline: airplane mode edit → outbox indicator → sync on reconnect
- [ ] All list tabs filter correctly
- [ ] Kanban drag changes status
- [ ] Day view shows scheduled tasks
- [ ] Search and tag filters work
- [ ] Dark mode renders correctly

- [ ] **Step 4: Commit**

```bash
git commit -m "test: add integration test and document manual QA checklist"
```

---

## Spec Coverage Checklist

| Spec requirement | Task |
|---|---|
| iCloud user-picked folder + default | Task 7, 10 |
| Markdown file format | Task 3 |
| Same sync/merge/conflict rules | Task 4, 8 |
| 30-day trash retention | Task 5, 8 |
| SwiftData local cache + outbox | Task 9 |
| List view all tabs | Task 12 |
| Kanban drag | Task 13 |
| Day timeline | Task 14 |
| Task detail form + markdown tab | Task 15 |
| Search + tag filters | Task 12 |
| Conflict banner + resolution | Task 16 |
| Manual sync + last synced + outbox indicator | Task 9, 11, 16 |
| Settings (folder, dark mode) | Task 16 |
| No auth v1 | Task 10 (no sign-in gate) |
| GitHub stub phase 2 | Task 6 |
| macOS-ready packages (no SwiftUI in core) | Task 1, 2 |
| External edit detection | Task 17 |
| Calm dark-first UI | Task 11 |
| Unit tests ported from task-core | Tasks 3, 4, 5, 8, 18 |

---

## Execution Order Summary

1. Task 1 → scaffold
2. Tasks 2–5 → core logic (TDD, all testable without UI)
3. Tasks 6–8 → storage + sync
4. Task 9 → local cache
5. Task 10 → onboarding
6. Tasks 11–16 → UI (can parallelize 12/13/14 after 11)
7. Task 17 → external edits
8. Task 18 → integration + QA

Estimated: 18 tasks, ~90 bite-sized steps.
