import Foundation

public struct FileManifestEntry: Codable, Sendable, Equatable {
    public var updated: String
    public var modifiedAt: String
    public var size: Int?

    public init(updated: String, modifiedAt: String, size: Int? = nil) {
        self.updated = updated
        self.modifiedAt = modifiedAt
        self.size = size
    }
}

public struct SyncMeta: Codable, Sendable, Equatable {
    public static let schemaVersion = 1

    public var schemaVersion: Int
    public var lastSyncedAt: String?
    public var files: [String: FileManifestEntry]

    public init(
        schemaVersion: Int = SyncMeta.schemaVersion,
        lastSyncedAt: String? = nil,
        files: [String: FileManifestEntry] = [:]
    ) {
        self.schemaVersion = schemaVersion
        self.lastSyncedAt = lastSyncedAt
        self.files = files
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? Self.schemaVersion
        lastSyncedAt = try container.decodeIfPresent(String.self, forKey: .lastSyncedAt)
        files = try container.decodeIfPresent([String: FileManifestEntry].self, forKey: .files) ?? [:]
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, lastSyncedAt, files
    }
}

public struct SyncFileMetadata: Sendable, Equatable {
    public var path: String
    public var modifiedAt: Date?
    public var size: Int?

    public init(path: String, modifiedAt: Date? = nil, size: Int? = nil) {
        self.path = path
        self.modifiedAt = modifiedAt
        self.size = size
    }
}
