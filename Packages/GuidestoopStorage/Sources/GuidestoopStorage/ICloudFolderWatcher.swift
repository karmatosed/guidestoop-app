import Foundation

public final class ICloudFolderWatcher: NSObject, NSFilePresenter, @unchecked Sendable {
    public let presentedItemURL: URL?
    public let presentedItemOperationQueue = OperationQueue.main

    private var debounceTask: Task<Void, Never>?
    private let onChange: @Sendable () -> Void

    public init(folderURL: URL, onChange: @escaping @Sendable () -> Void) {
        presentedItemURL = folderURL.appendingPathComponent(StoragePaths.tasksDir, isDirectory: true)
        self.onChange = onChange
        super.init()
        NSFileCoordinator.addFilePresenter(self)
    }

    deinit {
        NSFileCoordinator.removeFilePresenter(self)
    }

    public func presentedItemDidChange() {
        debounceTask?.cancel()
        debounceTask = Task {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            guard !Task.isCancelled else { return }
            onChange()
        }
    }
}
