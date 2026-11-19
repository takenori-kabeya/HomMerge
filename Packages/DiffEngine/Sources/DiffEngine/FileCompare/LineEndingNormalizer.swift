import Foundation

/// Converts between on-disk line endings and the LF-normalized in-memory form.
public enum LineEndingNormalizer {
    /// Converts `text` read with `lineEnding` into LF-separated logical lines.
    public static func normalizeToLF(_ text: String, lineEnding: LineEndingStyle) -> String {
        switch lineEnding {
        case .lf:
            return text
        case .crlf:
            return text.replacingOccurrences(of: "\r\n", with: "\n")
        case .cr:
            return text
                .replacingOccurrences(of: "\r\n", with: "\n")
                .replacingOccurrences(of: "\r", with: "\n")
        }
    }

    /// Converts LF-normalized `text` back to `lineEnding` for writing to disk.
    public static func denormalizeFromLF(_ text: String, lineEnding: LineEndingStyle) -> String {
        let split = LineSplitter.splitDetailed(text)
        let separator = separator(for: lineEnding)
        // Trailing empty line elements already encode a final newline; do not append again.
        return split.lines.joined(separator: separator)
    }

    private static func separator(for lineEnding: LineEndingStyle) -> String {
        switch lineEnding {
        case .lf:
            "\n"
        case .crlf:
            "\r\n"
        case .cr:
            "\r"
        }
    }
}
