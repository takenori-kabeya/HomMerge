/// Options that control how two texts are compared.
public struct DiffOptions: Sendable, Equatable {
    /// When true, whitespace is ignored while deciding whether lines match.
    public var ignoreWhitespace: Bool

    /// When true, blank (empty) lines are excluded from comparison.
    public var ignoreBlankLines: Bool

    /// When true, character-level spans are computed for `.modify` rows.
    public var computeInlineDiffs: Bool

    public init(
        ignoreWhitespace: Bool = false,
        ignoreBlankLines: Bool = false,
        computeInlineDiffs: Bool = true
    ) {
        self.ignoreWhitespace = ignoreWhitespace
        self.ignoreBlankLines = ignoreBlankLines
        self.computeInlineDiffs = computeInlineDiffs
    }

    public static let `default` = DiffOptions()
}

/// Kind of a side-by-side aligned row.
public enum DiffRowKind: Sendable, Equatable {
    case equal
    case insert
    case delete
    case modify
}

/// Kind of a character span within a modified line.
public enum InlineSpanKind: Sendable, Equatable {
    case equal
    case insert
    case delete
}

/// A contiguous character range within one side of a modified line.
///
/// Offsets are measured in `String` characters (`String.count` / `Character`).
public struct InlineSpan: Sendable, Equatable {
    public let start: Int
    public let end: Int
    public let kind: InlineSpanKind

    public init(start: Int, end: Int, kind: InlineSpanKind) {
        self.start = start
        self.end = end
        self.kind = kind
    }
}

/// One row in a side-by-side alignment of left and right texts.
public struct DiffRow: Sendable, Equatable {
    public let kind: DiffRowKind
    /// Zero-based index into `TextDiffResult.leftLines`, if present on this row.
    public let leftIndex: Int?
    /// Zero-based index into `TextDiffResult.rightLines`, if present on this row.
    public let rightIndex: Int?
    public let leftInlineSpans: [InlineSpan]
    public let rightInlineSpans: [InlineSpan]

    public init(
        kind: DiffRowKind,
        leftIndex: Int?,
        rightIndex: Int?,
        leftInlineSpans: [InlineSpan] = [],
        rightInlineSpans: [InlineSpan] = []
    ) {
        self.kind = kind
        self.leftIndex = leftIndex
        self.rightIndex = rightIndex
        self.leftInlineSpans = leftInlineSpans
        self.rightInlineSpans = rightInlineSpans
    }
}

/// A contiguous run of non-equal aligned rows.
public struct DiffHunk: Sendable, Equatable {
    /// Index into `TextDiffResult.alignedRows` where this hunk starts.
    public let startRow: Int
    /// Number of aligned rows in this hunk.
    public let rowCount: Int

    public init(startRow: Int, rowCount: Int) {
        self.startRow = startRow
        self.rowCount = rowCount
    }
}

/// Result of comparing two texts.
public struct TextDiffResult: Sendable, Equatable {
    public let leftLines: [String]
    public let rightLines: [String]
    public let alignedRows: [DiffRow]
    public let hunks: [DiffHunk]
    /// Whether the original left text ended with `\n`.
    public let leftEndsWithNewline: Bool
    /// Whether the original right text ended with `\n`.
    public let rightEndsWithNewline: Bool

    public init(
        leftLines: [String],
        rightLines: [String],
        alignedRows: [DiffRow],
        hunks: [DiffHunk],
        leftEndsWithNewline: Bool = false,
        rightEndsWithNewline: Bool = false
    ) {
        self.leftLines = leftLines
        self.rightLines = rightLines
        self.alignedRows = alignedRows
        self.hunks = hunks
        self.leftEndsWithNewline = leftEndsWithNewline
        self.rightEndsWithNewline = rightEndsWithNewline
    }

    public var hasChanges: Bool {
        alignedRows.contains { $0.kind != .equal }
            || leftEndsWithNewline != rightEndsWithNewline
    }
}
