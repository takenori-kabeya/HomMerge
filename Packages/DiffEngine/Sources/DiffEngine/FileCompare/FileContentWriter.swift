import Foundation

/// Writes text to disk for merge saves.
public enum FileContentWriter {
    public static func write(_ text: String, format: TextFileFormat, to url: URL) throws {
        let onDiskText = LineEndingNormalizer.denormalizeFromLF(text, lineEnding: format.lineEnding)
        let encoded: Data?
        switch format.encoding {
        case .utf8:
            encoded = encodeUTF8(onDiskText, includesBOM: format.includesUTF8BOM)
        case .shiftJIS:
            encoded = onDiskText.data(using: .shiftJIS)
        }
        guard let encoded else {
            throw FileSaveError.unwritable
        }
        do {
            try encoded.write(to: url, options: .atomic)
        } catch {
            throw FileSaveError.unwritable
        }
    }

    /// Writes UTF-8 LF text using the default format.
    public static func write(_ text: String, to url: URL) throws {
        try write(text, format: .default, to: url)
    }

    private static func encodeUTF8(_ text: String, includesBOM: Bool) -> Data? {
        guard var data = text.data(using: .utf8) else {
            return nil
        }
        if includesBOM {
            data = Data([0xEF, 0xBB, 0xBF]) + data
        }
        return data
    }
}

/// Errors produced while saving file contents.
public enum FileSaveError: Error, Equatable, Sendable {
    case unwritable
}
