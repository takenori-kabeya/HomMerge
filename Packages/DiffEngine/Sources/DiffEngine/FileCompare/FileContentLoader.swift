import Foundation

/// Errors produced while loading file contents for comparison.
public enum FileLoadError: Error, Equatable, Sendable {
    /// The payload contains NUL bytes (or otherwise looks binary).
    case binary
    /// The payload is not valid UTF-8 or Shift_JIS text.
    case notUTF8
    /// The file could not be read from disk.
    case unreadable
}

/// Loads text for comparison and rejects binary payloads.
public enum FileContentLoader {
    /// Returns `true` when `data` appears to be binary (contains a NUL byte).
    public static func isBinary(_ data: Data) -> Bool {
        data.contains(0)
    }

    /// Loads LF-normalized text and on-disk format metadata from raw bytes.
    public static func loadFile(data: Data) throws -> LoadedTextFile {
        try TextFileFormatDetector.decode(data: data)
    }

    /// Loads LF-normalized text and on-disk format metadata from a file URL.
    public static func loadFile(from url: URL) throws -> LoadedTextFile {
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw FileLoadError.unreadable
        }
        return try loadFile(data: data)
    }

    /// Loads LF-normalized text from raw bytes.
    public static func load(data: Data) throws -> String {
        try loadFile(data: data).text
    }

    /// Loads LF-normalized text from a file URL.
    public static func load(from url: URL) throws -> String {
        try loadFile(from: url).text
    }
}
