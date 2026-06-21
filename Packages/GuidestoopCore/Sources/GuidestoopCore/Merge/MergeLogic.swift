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
