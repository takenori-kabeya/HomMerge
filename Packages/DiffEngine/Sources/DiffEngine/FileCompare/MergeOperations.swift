/// Direction of a hunk copy during merge.
public enum MergeTarget: Sendable, Equatable {
    /// Copy the current hunk onto the left pane (right → left).
    case left
    /// Copy the current hunk onto the right pane (left → right).
    case right
}

/// Direction used by pure merge operations.
public enum MergeDirection: Sendable, Equatable {
    /// Make the right side match the left side for the selected hunk.
    case leftToRight
    /// Make the left side match the right side for the selected hunk.
    case rightToLeft
}

/// Result of applying one hunk merge.
public struct MergedTexts: Sendable, Equatable {
    public let leftText: String
    public let rightText: String

    public init(leftText: String, rightText: String) {
        self.leftText = leftText
        self.rightText = rightText
    }
}

/// Presentation-row mapping for caret restoration after a hunk copy.
public struct MergeCaretRemap: Sendable, Equatable {
    public let replacedStart: Int
    public let replacedOldCount: Int
    public let replacedNewCount: Int

    public init(replacedStart: Int, replacedOldCount: Int, replacedNewCount: Int) {
        self.replacedStart = replacedStart
        self.replacedOldCount = replacedOldCount
        self.replacedNewCount = replacedNewCount
    }
}

/// Applies hunk-level copy operations to a diff result.
public enum MergeOperations {
    public static func apply(
        direction: MergeDirection,
        hunkIndex: Int,
        to result: TextDiffResult
    ) -> MergedTexts? {
        guard result.hunks.indices.contains(hunkIndex) else {
            return nil
        }

        let hunk = result.hunks[hunkIndex]
        let hunkRange = hunk.startRow ..< (hunk.startRow + hunk.rowCount)

        var outLeft: [String] = []
        var outRight: [String] = []

        for (rowIndex, row) in result.alignedRows.enumerated() {
            let inHunk = hunkRange.contains(rowIndex)

            if !inHunk {
                if let leftIndex = row.leftIndex {
                    outLeft.append(result.leftLines[leftIndex])
                }
                if let rightIndex = row.rightIndex {
                    outRight.append(result.rightLines[rightIndex])
                }
                continue
            }

            switch direction {
            case .leftToRight:
                if let leftIndex = row.leftIndex {
                    let line = result.leftLines[leftIndex]
                    outLeft.append(line)
                    outRight.append(line)
                }
            case .rightToLeft:
                if let rightIndex = row.rightIndex {
                    let line = result.rightLines[rightIndex]
                    outLeft.append(line)
                    outRight.append(line)
                }
            }
        }

        // Unchanged side keeps its trailing-newline flag; changed side takes the source side's.
        let leftEnds: Bool
        let rightEnds: Bool
        switch direction {
        case .leftToRight:
            leftEnds = result.leftEndsWithNewline
            rightEnds = result.leftEndsWithNewline
        case .rightToLeft:
            leftEnds = result.rightEndsWithNewline
            rightEnds = result.rightEndsWithNewline
        }

        return MergedTexts(
            leftText: joinLines(outLeft, endsWithNewline: leftEnds),
            rightText: joinLines(outRight, endsWithNewline: rightEnds)
        )
    }

    /// Builds the caret remap for a hunk copy: new count is source-side content rows in the hunk.
    public static func caretRemap(
        direction: MergeDirection,
        hunkIndex: Int,
        to result: TextDiffResult
    ) -> MergeCaretRemap? {
        guard result.hunks.indices.contains(hunkIndex) else {
            return nil
        }
        let hunk = result.hunks[hunkIndex]
        let hunkRange = hunk.startRow ..< (hunk.startRow + hunk.rowCount)
        var newCount = 0
        for rowIndex in hunkRange {
            let row = result.alignedRows[rowIndex]
            switch direction {
            case .leftToRight:
                if row.leftIndex != nil { newCount += 1 }
            case .rightToLeft:
                if row.rightIndex != nil { newCount += 1 }
            }
        }
        return MergeCaretRemap(
            replacedStart: hunk.startRow,
            replacedOldCount: hunk.rowCount,
            replacedNewCount: newCount
        )
    }

    private static func joinLines(_ lines: [String], endsWithNewline: Bool) -> String {
        if lines.isEmpty {
            return endsWithNewline ? "\n" : ""
        }
        let body = lines.joined(separator: "\n")
        return endsWithNewline ? body + "\n" : body
    }
}
