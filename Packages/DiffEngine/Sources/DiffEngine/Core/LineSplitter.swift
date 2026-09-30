/// Result of splitting text into logical lines.
public struct LineSplitResult: Sendable, Equatable {
    public let lines: [String]
    /// Whether the original text ended with `\n`.
    public let endsWithNewline: Bool

    public init(lines: [String], endsWithNewline: Bool) {
        self.lines = lines
        self.endsWithNewline = endsWithNewline
    }
}

/// Splits text into logical lines for comparison.
public enum LineSplitter {
    /// Splits `text` on `\n`.
    ///
    /// - A trailing newline does not create an extra empty line.
    /// - Empty input yields an empty array.
    /// - Internal blank lines are preserved as `""`.
    public static func split(_ text: String) -> [String] {
        splitDetailed(text).lines
    }

    /// Splits `text` on `\n` and reports whether it ended with a newline.
    public static func splitDetailed(_ text: String) -> LineSplitResult {
        let endsWithNewline = text.hasSuffix("\n")
        if text.isEmpty {
            return LineSplitResult(lines: [], endsWithNewline: false)
        }

        var lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        if endsWithNewline, lines.last == "" {
            lines.removeLast()
        }
        return LineSplitResult(lines: lines, endsWithNewline: endsWithNewline)
    }
}
