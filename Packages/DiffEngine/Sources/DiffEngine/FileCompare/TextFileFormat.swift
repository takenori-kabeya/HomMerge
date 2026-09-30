import Foundation

/// Line ending style detected on disk.
public enum LineEndingStyle: Sendable, Equatable {
    case lf
    case crlf
    case cr

    /// Human-readable label for status display (e.g. `LF`, `CRLF`).
    public var displayName: String {
        switch self {
        case .lf:
            return "LF"
        case .crlf:
            return "CRLF"
        case .cr:
            return "CR"
        }
    }
}

/// Supported on-disk text encodings.
public enum TextEncoding: Sendable, Equatable {
    case utf8
    case shiftJIS

    /// Human-readable label for status display (e.g. `UTF-8`, `Shift_JIS`).
    public var displayName: String {
        switch self {
        case .utf8:
            return "UTF-8"
        case .shiftJIS:
            return "Shift_JIS"
        }
    }
}

/// Metadata describing how a text file is encoded on disk.
public struct TextFileFormat: Sendable, Equatable {
    public var encoding: TextEncoding
    public var lineEnding: LineEndingStyle
    public var includesUTF8BOM: Bool

    public init(
        encoding: TextEncoding,
        lineEnding: LineEndingStyle,
        includesUTF8BOM: Bool = false
    ) {
        self.encoding = encoding
        self.lineEnding = lineEnding
        self.includesUTF8BOM = includesUTF8BOM
    }

    public static let `default` = TextFileFormat(encoding: .utf8, lineEnding: .lf)

    /// Compact label for status bars (e.g. `UTF-8 · CRLF`).
    public var statusDescription: String {
        let encodingLabel: String
        switch encoding {
        case .utf8:
            encodingLabel = includesUTF8BOM ? "UTF-8 BOM" : encoding.displayName
        case .shiftJIS:
            encodingLabel = encoding.displayName
        }
        return "\(encodingLabel) · \(lineEnding.displayName)"
    }
}

/// LF-normalized text plus the original on-disk format.
public struct LoadedTextFile: Sendable, Equatable {
    public var text: String
    public var format: TextFileFormat

    public init(text: String, format: TextFileFormat) {
        self.text = text
        self.format = format
    }
}
