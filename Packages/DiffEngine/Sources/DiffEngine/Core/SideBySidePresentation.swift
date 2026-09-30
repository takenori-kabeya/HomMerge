/// One visual row in a side-by-side file comparison pane.
public struct SideBySideLine: Sendable, Equatable {
    public let kind: DiffRowKind
    /// One-based line number in the left file, if this row shows left content.
    public let leftLineNumber: Int?
    /// One-based line number in the right file, if this row shows right content.
    public let rightLineNumber: Int?
    public let leftText: String
    public let rightText: String
    public let leftInlineSpans: [InlineSpan]
    public let rightInlineSpans: [InlineSpan]

    public init(
        kind: DiffRowKind,
        leftLineNumber: Int?,
        rightLineNumber: Int?,
        leftText: String,
        rightText: String,
        leftInlineSpans: [InlineSpan] = [],
        rightInlineSpans: [InlineSpan] = []
    ) {
        self.kind = kind
        self.leftLineNumber = leftLineNumber
        self.rightLineNumber = rightLineNumber
        self.leftText = leftText
        self.rightText = rightText
        self.leftInlineSpans = leftInlineSpans
        self.rightInlineSpans = rightInlineSpans
    }
}

/// Builds side-by-side display rows from a `TextDiffResult`.
public enum SideBySideBuilder {
    public static func build(from result: TextDiffResult) -> [SideBySideLine] {
        result.alignedRows.map { row in
            let leftText: String
            let leftNumber: Int?
            if let leftIndex = row.leftIndex {
                leftText = result.leftLines[leftIndex]
                leftNumber = leftIndex + 1
            } else {
                leftText = ""
                leftNumber = nil
            }

            let rightText: String
            let rightNumber: Int?
            if let rightIndex = row.rightIndex {
                rightText = result.rightLines[rightIndex]
                rightNumber = rightIndex + 1
            } else {
                rightText = ""
                rightNumber = nil
            }

            return SideBySideLine(
                kind: row.kind,
                leftLineNumber: leftNumber,
                rightLineNumber: rightNumber,
                leftText: leftText,
                rightText: rightText,
                leftInlineSpans: row.leftInlineSpans,
                rightInlineSpans: row.rightInlineSpans
            )
        }
    }
}
