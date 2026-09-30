import Foundation

/// Moves files to the Trash from folder-compare actions.
public enum FolderFileTrash {
    public enum Error: Swift.Error, Equatable, LocalizedError {
        case missing

        public var errorDescription: String? {
            switch self {
            case .missing:
                return "The file could not be found."
            }
        }
    }

    /// Moves `url` to the Trash when it exists on disk.
    public static func moveToTrash(
        at url: URL,
        fileManager: FileManager = .default
    ) throws {
        guard fileManager.fileExists(atPath: url.path) else {
            throw Error.missing
        }
        try fileManager.trashItem(at: url, resultingItemURL: nil)
    }
}
