import Foundation

public enum OutboxOp: String, Codable, Sendable {
    case save
    case delete
    case restore
    case purge
}

public struct OutboxOperation: Equatable, Sendable {
    public var op: OutboxOp
    public var task: Task?
    public var deletedTask: DeletedTask?
    public var taskId: String?

    public init(op: OutboxOp, task: Task? = nil, deletedTask: DeletedTask? = nil, taskId: String? = nil) {
        self.op = op
        self.task = task
        self.deletedTask = deletedTask
        self.taskId = taskId
    }

    public static func save(_ task: Task) -> OutboxOperation {
        OutboxOperation(op: .save, task: task, taskId: task.id)
    }

    public static func delete(id: String, deletedTask: DeletedTask? = nil) -> OutboxOperation {
        OutboxOperation(op: .delete, deletedTask: deletedTask, taskId: id)
    }

    public static func restore(_ task: Task) -> OutboxOperation {
        OutboxOperation(op: .restore, task: task, taskId: task.id)
    }

    public static func purge(id: String) -> OutboxOperation {
        OutboxOperation(op: .purge, taskId: id)
    }
}
