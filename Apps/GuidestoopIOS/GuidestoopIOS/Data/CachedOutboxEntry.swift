import Foundation
import SwiftData
import GuidestoopCore

@Model
final class CachedOutboxEntry {
    @Attribute(.unique) var id: UUID
    var opRawValue: String
    var taskId: String?
    var payload: String?
    var createdAt: Date

    init(
        id: UUID = UUID(),
        opRawValue: String,
        taskId: String?,
        payload: String?,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.opRawValue = opRawValue
        self.taskId = taskId
        self.payload = payload
        self.createdAt = createdAt
    }

    var op: OutboxOp {
        OutboxOp(rawValue: opRawValue) ?? .save
    }

    func toOperation() -> OutboxOperation? {
        let decodedPayload = decodePayload()
        return OutboxOperation(
            op: op,
            task: decodedPayload?.task,
            deletedTask: decodedPayload?.deletedTask,
            taskId: taskId
        )
    }

    static func from(_ operation: OutboxOperation) -> CachedOutboxEntry {
        let payload = Payload(task: operation.task, deletedTask: operation.deletedTask)
        return CachedOutboxEntry(
            opRawValue: operation.op.rawValue,
            taskId: operation.taskId,
            payload: payload.isEmpty ? nil : payload.encode()
        )
    }
}

private struct Payload: Codable {
    var task: Task?
    var deletedTask: DeletedTask?

    var isEmpty: Bool {
        task == nil && deletedTask == nil
    }

    func encode() -> String? {
        guard let data = try? JSONEncoder().encode(self) else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }
}

private extension CachedOutboxEntry {
    func decodePayload() -> Payload? {
        guard let payload, let data = payload.data(using: .utf8) else {
            return nil
        }
        return try? JSONDecoder().decode(Payload.self, from: data)
    }
}
