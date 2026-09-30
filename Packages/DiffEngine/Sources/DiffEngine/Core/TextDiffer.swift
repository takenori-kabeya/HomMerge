/// Compares two texts and produces a side-by-side alignment.
public enum TextDiffer {
    public static func compare(
        _ left: String,
        _ right: String,
        options: DiffOptions = .default
    ) -> TextDiffResult {
        let leftSplit = LineSplitter.splitDetailed(left)
        let rightSplit = LineSplitter.splitDetailed(right)
        var leftLines = leftSplit.lines
        var rightLines = rightSplit.lines

        let leftItems = indexedLines(leftLines, options: options)
        let rightItems = indexedLines(rightLines, options: options)

        let leftKeys = leftItems.map(\.compareKey)
        let rightKeys = rightItems.map(\.compareKey)
        let edits = MyersDiffer.diff(leftKeys, rightKeys)

        let rawRows: [DiffRow] = edits.map { edit in
            switch edit {
            case .equal(let aIndex, let bIndex):
                return DiffRow(
                    kind: .equal,
                    leftIndex: leftItems[aIndex].originalIndex,
                    rightIndex: rightItems[bIndex].originalIndex
                )
            case .delete(let aIndex):
                return DiffRow(
                    kind: .delete,
                    leftIndex: leftItems[aIndex].originalIndex,
                    rightIndex: nil
                )
            case .insert(let bIndex):
                return DiffRow(
                    kind: .insert,
                    leftIndex: nil,
                    rightIndex: rightItems[bIndex].originalIndex
                )
            }
        }

        var alignedRows = coalesceModifies(
            rawRows,
            leftLines: leftLines,
            rightLines: rightLines,
            computeInlineDiffs: options.computeInlineDiffs
        )

        // Only synthesize a trailing-newline row when content lines already match.
        // e.g. "" vs "\n" already differs as [] vs [""] after split.
        if leftSplit.endsWithNewline != rightSplit.endsWithNewline,
           leftSplit.lines == rightSplit.lines
        {
            if leftSplit.endsWithNewline {
                leftLines.append("")
                alignedRows.append(
                    DiffRow(kind: .delete, leftIndex: leftLines.count - 1, rightIndex: nil)
                )
            } else {
                rightLines.append("")
                alignedRows.append(
                    DiffRow(kind: .insert, leftIndex: nil, rightIndex: rightLines.count - 1)
                )
            }
        }

        let hunks = makeHunks(from: alignedRows)

        return TextDiffResult(
            leftLines: leftLines,
            rightLines: rightLines,
            alignedRows: alignedRows,
            hunks: hunks,
            leftEndsWithNewline: leftSplit.endsWithNewline,
            rightEndsWithNewline: rightSplit.endsWithNewline
        )
    }

    private struct IndexedLine {
        let originalIndex: Int
        let compareKey: String
    }

    private static func indexedLines(
        _ lines: [String],
        options: DiffOptions
    ) -> [IndexedLine] {
        lines.enumerated().compactMap { index, line in
            if options.ignoreBlankLines, line.isEmpty {
                return nil
            }
            return IndexedLine(
                originalIndex: index,
                compareKey: compareKey(for: line, options: options)
            )
        }
    }

    private static func compareKey(for line: String, options: DiffOptions) -> String {
        if options.ignoreWhitespace {
            return String(line.filter { !$0.isWhitespace })
        }
        return line
    }

    private static func coalesceModifies(
        _ rows: [DiffRow],
        leftLines: [String],
        rightLines: [String],
        computeInlineDiffs: Bool
    ) -> [DiffRow] {
        var result: [DiffRow] = []
        var index = 0

        while index < rows.count {
            let row = rows[index]
            if row.kind == .equal {
                result.append(row)
                index += 1
                continue
            }

            var deletes: [DiffRow] = []
            var inserts: [DiffRow] = []
            while index < rows.count, rows[index].kind != .equal {
                switch rows[index].kind {
                case .delete:
                    deletes.append(rows[index])
                case .insert:
                    inserts.append(rows[index])
                case .equal, .modify:
                    break
                }
                index += 1
            }

            let paired = min(deletes.count, inserts.count)
            for pairIndex in 0..<paired {
                let leftIndex = deletes[pairIndex].leftIndex!
                let rightIndex = inserts[pairIndex].rightIndex!
                let spans: ([InlineSpan], [InlineSpan])
                if computeInlineDiffs {
                    spans = InlineDiffer.diff(leftLines[leftIndex], rightLines[rightIndex])
                } else {
                    spans = ([], [])
                }
                result.append(
                    DiffRow(
                        kind: .modify,
                        leftIndex: leftIndex,
                        rightIndex: rightIndex,
                        leftInlineSpans: spans.0,
                        rightInlineSpans: spans.1
                    )
                )
            }
            if paired < deletes.count {
                result.append(contentsOf: deletes[paired...])
            }
            if paired < inserts.count {
                result.append(contentsOf: inserts[paired...])
            }
        }

        return result
    }

    private static func makeHunks(from rows: [DiffRow]) -> [DiffHunk] {
        var hunks: [DiffHunk] = []
        var start: Int?
        var count = 0

        for (rowIndex, row) in rows.enumerated() {
            if row.kind == .equal {
                if let start, count > 0 {
                    hunks.append(DiffHunk(startRow: start, rowCount: count))
                }
                start = nil
                count = 0
            } else {
                if start == nil {
                    start = rowIndex
                    count = 1
                } else {
                    count += 1
                }
            }
        }

        if let start, count > 0 {
            hunks.append(DiffHunk(startRow: start, rowCount: count))
        }

        return hunks
    }
}
