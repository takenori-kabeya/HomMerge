import Foundation

public enum PathKind: Equatable, Sendable {
    case file
    case directory
}

public enum ComparePairResolution: Equatable, Sendable {
    /// One or both paths are unset, or a path does not exist on disk.
    case incomplete
    /// Both paths exist and are regular files (or non-directory items).
    case files
    /// Both paths exist and are directories.
    case folders
    /// Both paths exist but one is a file and the other is a directory.
    case mismatch
}

public enum PathKindDetector {
    /// Returns the kind of an existing path, or `nil` if it does not exist.
    public static func kind(of url: URL, fileManager: FileManager = .default) -> PathKind? {
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
            return nil
        }
        return isDirectory.boolValue ? .directory : .file
    }
}

public enum ComparePairResolver {
    /// Decides how a left/right path pair should be compared.
    public static func resolve(
        left: URL?,
        right: URL?,
        fileManager: FileManager = .default
    ) -> ComparePairResolution {
        guard let left, let right else {
            return .incomplete
        }
        guard let leftKind = PathKindDetector.kind(of: left, fileManager: fileManager),
              let rightKind = PathKindDetector.kind(of: right, fileManager: fileManager)
        else {
            return .incomplete
        }
        switch (leftKind, rightKind) {
        case (.file, .file):
            return .files
        case (.directory, .directory):
            return .folders
        case (.file, .directory), (.directory, .file):
            return .mismatch
        }
    }
}
