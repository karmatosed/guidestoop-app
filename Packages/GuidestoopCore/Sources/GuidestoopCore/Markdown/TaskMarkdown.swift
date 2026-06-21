import Foundation
import Yams

public enum TaskMarkdownError: Error, LocalizedError {
    case missingFrontmatter
    case invalidFrontmatter
    case missingField(String)
    case invalidStatus

    public var errorDescription: String? {
        switch self {
        case .missingFrontmatter:
            return "Task markdown must start with YAML frontmatter (---)"
        case .invalidFrontmatter:
            return "Invalid task frontmatter"
        case .missingField(let field):
            return "Task frontmatter \"\(field)\" must be a non-empty string"
        case .invalidStatus:
            return "Task frontmatter \"status\" must be one of: inbox, blocked, focus, scheduled, done"
        }
    }
}

extension TaskMarkdownError: CustomStringConvertible {
    public var description: String {
        errorDescription ?? String(describing: self)
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
            highPriority: parseOptionalBool(data["highPriority"]) ?? false,
            created: try coerceString(data["created"], field: "created"),
            updated: try coerceString(data["updated"], field: "updated"),
            body: normalizeBody(content)
        )
    }

    public static func serialize(_ task: Task) throws -> String {
        var frontmatter: [String: Any] = [
            "id": task.id,
            "title": task.title,
            "status": task.status.rawValue,
            "created": task.created,
            "updated": task.updated,
        ]
        if let scheduled = task.scheduled { frontmatter["scheduled"] = scheduled }
        if let duration = task.duration { frontmatter["duration"] = duration }
        if let project = task.project { frontmatter["project"] = project }
        if !task.tags.isEmpty { frontmatter["tags"] = task.tags }
        if task.highPriority { frontmatter["highPriority"] = true }

        let yaml = try Yams.dump(object: frontmatter, allowUnicode: true)
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
            highPriority: parseOptionalBool(data["highPriority"]) ?? false,
            created: try coerceString(data["created"], field: "created"),
            updated: try coerceString(data["updated"], field: "updated"),
            deletedAt: try coerceString(data["deletedAt"], field: "deletedAt"),
            body: normalizeBody(content)
        )
    }

    public static func serializeDeleted(_ task: Task, deletedAt: String) throws -> String {
        var frontmatter: [String: Any] = [
            "id": task.id,
            "title": task.title,
            "status": task.status.rawValue,
            "created": task.created,
            "updated": task.updated,
            "deletedAt": deletedAt,
        ]
        if let scheduled = task.scheduled { frontmatter["scheduled"] = scheduled }
        if let duration = task.duration { frontmatter["duration"] = duration }
        if let project = task.project { frontmatter["project"] = project }
        if !task.tags.isEmpty { frontmatter["tags"] = task.tags }
        if task.highPriority { frontmatter["highPriority"] = true }

        let yaml = try Yams.dump(object: frontmatter, allowUnicode: true)
        let body = task.body.isEmpty ? "" : "\n\(task.body)"
        return "---\n\(yaml.trimmingCharacters(in: .whitespacesAndNewlines))\n---\(body)\n"
    }

    public static func contentEqual(_ a: Task, _ b: Task) throws -> Bool {
        let stamp = "1970-01-01T00:00:00.000Z"
        var normalizedA = a
        normalizedA.updated = stamp
        var normalizedB = b
        normalizedB.updated = stamp
        return try serialize(normalizedA) == serialize(normalizedB)
    }

    // MARK: - Private helpers

    private static func splitFrontmatter(_ raw: String) throws -> ([String: Any], String) {
        let trimmed = raw.hasPrefix("\u{FEFF}") ? String(raw.dropFirst()) : raw
        let range = NSRange(trimmed.startIndex..., in: trimmed)
        guard let match = frontmatterRegex.firstMatch(in: trimmed, range: range),
              let frontmatterRange = Range(match.range(at: 1), in: trimmed) else {
            throw TaskMarkdownError.missingFrontmatter
        }
        let contentRange = match.range(at: 2).location != NSNotFound
            ? Range(match.range(at: 2), in: trimmed)!
            : trimmed.endIndex..<trimmed.endIndex
        let frontmatterText = String(trimmed[frontmatterRange])
        let content = String(trimmed[contentRange])
        guard let loaded = try Yams.load(yaml: frontmatterText) as? [String: Any] else {
            throw TaskMarkdownError.invalidFrontmatter
        }
        return (loaded, content)
    }

    private static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    private static func coerceString(_ value: Any?, field: String) throws -> String {
        if let string = value as? String, !string.trimmingCharacters(in: .whitespaces).isEmpty {
            return string
        }
        if let date = value as? Date {
            return isoFormatter.string(from: date)
        }
        if let bool = value as? Bool {
            return bool ? "true" : "false"
        }
        if let number = value as? NSNumber {
            return number.stringValue
        }
        throw TaskMarkdownError.missingField(field)
    }

    private static func parseOptionalString(_ value: Any?) -> String? {
        guard let value, !(value is NSNull) else { return nil }
        if let string = value as? String {
            return string.isEmpty ? nil : string
        }
        if let date = value as? Date {
            return isoFormatter.string(from: date)
        }
        if let bool = value as? Bool {
            return bool ? "true" : "false"
        }
        if let number = value as? NSNumber {
            return number.stringValue
        }
        let string = "\(value)"
        return string.isEmpty ? nil : string
    }

    private static func parseOptionalInt(_ value: Any?) -> Int? {
        if value == nil || value is NSNull { return nil }
        if let intValue = value as? Int { return intValue }
        if let doubleValue = value as? Double { return Int(doubleValue) }
        if let stringValue = value as? String, let intValue = Int(stringValue) { return intValue }
        return nil
    }

    private static func parseTags(_ value: Any?) -> [String] {
        guard let array = value as? [Any] else { return [] }
        var tags: [String] = []
        for item in array {
            guard let string = item as? String else { continue }
            let trimmed = string.trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty && !tags.contains(trimmed) {
                tags.append(trimmed)
            }
        }
        return tags
    }

    private static func parseOptionalBool(_ value: Any?) -> Bool? {
        if value == nil || value is NSNull { return nil }
        if let bool = value as? Bool { return bool }
        if let string = value as? String {
            switch string.lowercased() {
            case "true", "yes", "1", "high":
                return true
            case "false", "no", "0":
                return false
            default:
                return nil
            }
        }
        if let number = value as? NSNumber { return number.boolValue }
        return nil
    }

    private static func parseStatus(_ value: Any?) throws -> TaskStatus {
        if let string = value as? String, let status = TaskStatus(rawValue: string) {
            return status
        }
        if let bool = value as? Bool {
            return bool ? .done : .inbox
        }
        throw TaskMarkdownError.invalidStatus
    }

    private static func normalizeBody(_ content: String) -> String {
        var normalized = content
        if normalized.hasPrefix("\n") {
            normalized.removeFirst()
        }
        return normalized
            .trimmingCharacters(in: .newlines)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\r\n", with: "\n")
    }
}
