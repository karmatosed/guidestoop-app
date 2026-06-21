import Foundation

public struct Project: Codable, Identifiable, Equatable, Sendable {
    public var id: String       // proj-{slug}
    public var name: String
    public var color: String?
    public var created: String
    public var updated: String
    public var body: String
}
