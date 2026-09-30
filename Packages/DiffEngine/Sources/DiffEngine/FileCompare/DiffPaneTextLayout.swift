import CoreGraphics
import Foundation

/// Which side of a side-by-side presentation to read text from.
public enum DiffPaneSide: Sendable, Equatable, Hashable {
    case left
    case right
}

/// Builds the content-only plain text used by file-compare panes and
/// computes UTF-16 offsets / gutter labels that match that assembly.
public enum DiffPaneTextLayout {
    /// Minimum digit columns so small files keep a stable gutter width.
    public static let minimumGutterDigitCount = 4

    public static func gutterDigitCount(maxLineNumber: Int) -> Int {
        let digits = String(max(maxLineNumber, 1)).count
        return max(minimumGutterDigitCount, digits)
    }

    public static func gutterDigitCount(lines: [SideBySideLine], side: DiffPaneSide) -> Int {
        var maxNumber = 0
        for line in lines {
            if let number = lineNumber(for: line, side: side) {
                maxNumber = max(maxNumber, number)
            }
        }
        return gutterDigitCount(maxLineNumber: maxNumber)
    }

    public static func gutterLabel(lineNumber: Int?, digitCount: Int) -> String {
        let width = max(digitCount, 1)
        guard let lineNumber else {
            return String(repeating: " ", count: width)
        }
        return String(format: "%\(width)d", lineNumber)
    }

    public static func contentRowString(text: String, isLastRow: Bool) -> String {
        text + (isLastRow ? "" : "\n")
    }

    public static func contentPlainText(lines: [SideBySideLine], side: DiffPaneSide) -> String {
        var result = ""
        for (rowIndex, line) in lines.enumerated() {
            result += contentRowString(
                text: text(for: line, side: side),
                isLastRow: rowIndex == lines.count - 1
            )
        }
        return result
    }

    /// UTF-16 character offset at the start of `row` in the content-only pane text.
    public static func utf16Location(forRow row: Int, in lines: [SideBySideLine], side: DiffPaneSide) -> Int {
        var location = 0
        for index in 0..<min(row, lines.count) {
            let rowString = contentRowString(
                text: text(for: lines[index], side: side),
                isLastRow: index == lines.count - 1
            )
            location += (rowString as NSString).length
        }
        return location
    }

    /// Presentation row containing `location` in the content-only pane text.
    /// Locations past the end clamp to the last row.
    public static func row(
        forUtf16Location location: Int,
        in lines: [SideBySideLine],
        side: DiffPaneSide
    ) -> Int {
        guard !lines.isEmpty else { return 0 }
        var offset = 0
        for (index, line) in lines.enumerated() {
            let rowString = contentRowString(
                text: text(for: line, side: side),
                isLastRow: index == lines.count - 1
            )
            let length = (rowString as NSString).length
            if location < offset + length {
                return index
            }
            offset += length
        }
        return lines.count - 1
    }

    public static func lineNumber(for line: SideBySideLine, side: DiffPaneSide) -> Int? {
        switch side {
        case .left: return line.leftLineNumber
        case .right: return line.rightLineNumber
        }
    }

    public static func text(for line: SideBySideLine, side: DiffPaneSide) -> String {
        switch side {
        case .left: return line.leftText
        case .right: return line.rightText
        }
    }

    /// Clamps a vertical clip origin so it stays within the scrollable document range.
    public static func clampedVerticalOffset(
        currentY: CGFloat,
        documentHeight: CGFloat,
        visibleHeight: CGFloat
    ) -> CGFloat {
        let maxY = max(documentHeight - visibleHeight, 0)
        return min(max(currentY, 0), maxY)
    }

    /// Vertical clip origin that places `lineMinY` at `anchorFractionInViewport` within the visible area.
    ///
    /// `anchorFractionInViewport` is 0 at the top of the viewport and 1 at the bottom.
    public static func verticalOffsetAligningRow(
        lineMinY: CGFloat,
        visibleHeight: CGFloat,
        documentHeight: CGFloat,
        anchorFractionInViewport: CGFloat
    ) -> CGFloat {
        let anchor = min(max(anchorFractionInViewport, 0), 1)
        let raw = lineMinY - visibleHeight * anchor
        return clampedVerticalOffset(
            currentY: raw,
            documentHeight: documentHeight,
            visibleHeight: visibleHeight
        )
    }

    /// Fraction of the viewport height at which `lineMinY` sits (0 = top, 1 = bottom), clamped.
    public static func viewportAnchorFraction(
        lineMinY: CGFloat,
        visibleOriginY: CGFloat,
        visibleHeight: CGFloat
    ) -> CGFloat? {
        guard visibleHeight > 0 else { return nil }
        let raw = (lineMinY - visibleOriginY) / visibleHeight
        return min(max(raw, 0), 1)
    }

    /// Scrollable document height from layout metrics (prefer over `NSTextView.bounds.height`).
    public static func layoutDocumentHeight(
        usedRectHeight: CGFloat,
        textContainerInsetHeight: CGFloat
    ) -> CGFloat {
        usedRectHeight + textContainerInsetHeight * 2
    }

    /// UTF-16 offset at the start of `row` in a gutter plain-text assembly for `side`.
    public static func utf16Location(
        forGutterRow row: Int,
        in lines: [SideBySideLine],
        side: DiffPaneSide,
        digitCount: Int
    ) -> Int {
        var location = 0
        for index in 0..<min(row, lines.count) {
            let label = gutterLabel(
                lineNumber: lineNumber(for: lines[index], side: side),
                digitCount: digitCount
            )
            let rowString = contentRowString(
                text: label,
                isLastRow: index == lines.count - 1
            )
            location += (rowString as NSString).length
        }
        return location
    }

    /// Converts pane plain text back to file text by dropping empty visual gap rows for `side`.
    ///
    /// Gap rows are presentation spacers (`lineNumber == nil`). Pane rows are realigned to the
    /// presentation by common prefix / suffix, so an edit that changes the line count does not
    /// shift every following row. In the unmatched middle region only empty rows are dropped,
    /// and at most as many as there were gap rows there, so a multi-line paste into a gap
    /// consumes the spacers it pushed out instead of writing them as blank file lines.
    public static func fileTextByDroppingGapRows(
        paneText: String,
        lines: [SideBySideLine],
        side: DiffPaneSide
    ) -> String {
        let paneRows = splitPaneRows(paneText)
        guard !lines.isEmpty else {
            return paneRows.joined(separator: "\n")
        }

        let presentationRows = lines.map { text(for: $0, side: side) }
        let isGap = lines.map { lineNumber(for: $0, side: side) == nil }
        let alignableCount = min(paneRows.count, presentationRows.count)

        var prefix = 0
        while prefix < alignableCount, paneRows[prefix] == presentationRows[prefix] {
            prefix += 1
        }

        var suffix = 0
        while suffix < alignableCount - prefix,
              paneRows[paneRows.count - 1 - suffix] == presentationRows[presentationRows.count - 1 - suffix]
        {
            suffix += 1
        }

        var fileRows: [String] = []

        for index in 0..<prefix where !(isGap[index] && paneRows[index].isEmpty) {
            fileRows.append(paneRows[index])
        }

        let middlePane = Array(paneRows[prefix..<(paneRows.count - suffix)])
        let middleGapCount = (prefix..<(presentationRows.count - suffix)).reduce(into: 0) { count, index in
            if isGap[index] { count += 1 }
        }
        fileRows.append(contentsOf: rowsDroppingTrailingEmpties(middlePane, limit: middleGapCount))

        for offset in 0..<suffix {
            let paneIndex = paneRows.count - suffix + offset
            let lineIndex = presentationRows.count - suffix + offset
            if isGap[lineIndex], paneRows[paneIndex].isEmpty { continue }
            fileRows.append(paneRows[paneIndex])
        }

        return fileRows.joined(separator: "\n")
    }

    /// Drops up to `limit` empty rows, scanning from the end (pushed-out spacers trail the edit).
    private static func rowsDroppingTrailingEmpties(_ rows: [String], limit: Int) -> [String] {
        guard limit > 0 else { return rows }
        var remaining = limit
        var kept: [String] = []
        for row in rows.reversed() {
            if row.isEmpty, remaining > 0 {
                remaining -= 1
                continue
            }
            kept.append(row)
        }
        return kept.reversed()
    }

    /// Restores a trailing newline when `previous` had one but `edited` does not.
    /// Does not remove a trailing newline that the user explicitly added in `edited`.
    public static func normalizingTrailingNewline(edited: String, previous: String?) -> String {
        guard let previous else { return edited }
        let previousHadTrailing = previous.hasSuffix("\n")
        let editedHasTrailing = edited.hasSuffix("\n")
        if previousHadTrailing && !editedHasTrailing {
            return edited + "\n"
        }
        return edited
    }

    /// Whether a pane should rewrite its text storage / gutter for the latest presentation.
    ///
    /// While the pane has uncommitted keystrokes, skip rewrites unless `shouldForceApply`
    /// (post-commit). Highlight / presentation updates must not clobber in-progress edits.
    /// When there are no uncommitted edits, always write so highlight and presentation stay
    /// in sync even if the pane has focus.
    ///
    /// `presentationChanged` and `highlightChanged` remain in the signature for call-site
    /// compatibility; uncommitted edits are never overridden by those flags.
    public static func shouldApplyPaneContent(
        hasUncommittedEdits: Bool,
        shouldForceApply: Bool,
        presentationChanged: Bool,
        highlightChanged: Bool = false
    ) -> Bool {
        let _ = (presentationChanged, highlightChanged)
        return shouldForceApply || !hasUncommittedEdits
    }

    /// Maps a caret presentation row across a hunk replacement (Copy Left/Right).
    ///
    /// - Before the replaced range: unchanged
    /// - Inside: moves to `replacedStart`
    /// - After: keeps distance past the old end, applied after the new block
    public static func remappedPresentationRow(
        caretRow: Int,
        replacedStart: Int,
        replacedOldCount: Int,
        replacedNewCount: Int
    ) -> Int {
        let oldEnd = replacedStart + max(replacedOldCount, 0)
        let newCount = max(replacedNewCount, 0)
        if caretRow < replacedStart {
            return max(caretRow, 0)
        }
        if caretRow < oldEnd {
            return max(replacedStart, 0)
        }
        return max(replacedStart, 0) + newCount + (caretRow - oldEnd)
    }

    /// Clamps a presentation row into `0..<lineCount`. Returns `nil` when there are no lines.
    public static func clampedPresentationRow(_ row: Int, lineCount: Int) -> Int? {
        guard lineCount > 0 else { return nil }
        return min(max(row, 0), lineCount - 1)
    }

    /// Clipboard text for a pane selection, omitting empty gap rows (`lineNumber == nil`).
    ///
    /// Gap positions come from the presentation (`lines`); only the selected row range is derived
    /// from `selectedRange` in `paneText`.
    public static func clipboardTextByDroppingGapRows(
        paneText: String,
        selectedRange: NSRange,
        lines: [SideBySideLine],
        side: DiffPaneSide
    ) -> String {
        guard selectedRange.length > 0 else { return "" }

        let isGap = lines.map { lineNumber(for: $0, side: side) == nil }
        let paneRows = splitPaneRows(paneText)
        guard !paneRows.isEmpty else { return "" }

        let paneNSString = paneText as NSString
        let selectionEnd = selectedRange.location + selectedRange.length
        let startRow = paneRowIndex(forUtf16Location: selectedRange.location, paneRows: paneRows)
        let endLocation = max(selectionEnd - 1, selectedRange.location)
        let endRow = paneRowIndex(forUtf16Location: endLocation, paneRows: paneRows)

        var parts: [String] = []
        for row in startRow...endRow {
            let bounds = paneRowUtf16Bounds(row: row, paneRows: paneRows)
            let lineEnd = row < paneRows.count - 1 ? bounds.contentEnd + 1 : bounds.contentEnd
            let selectionIntersectsRow = selectedRange.location < lineEnd && selectionEnd > bounds.contentStart
            guard selectionIntersectsRow else { continue }

            let selStart = max(selectedRange.location, bounds.contentStart)
            let selEnd = min(selectionEnd, bounds.contentEnd)
            let fragment = selStart < selEnd
                ? paneNSString.substring(with: NSRange(location: selStart, length: selEnd - selStart))
                : ""
            if row < isGap.count, isGap[row], fragment.isEmpty {
                continue
            }
            parts.append(fragment)
        }
        return parts.joined(separator: "\n")
    }

    private static func paneRowIndex(forUtf16Location location: Int, paneRows: [String]) -> Int {
        guard !paneRows.isEmpty else { return 0 }
        var offset = 0
        for (index, row) in paneRows.enumerated() {
            let contentLength = (row as NSString).length
            let lineLength = index < paneRows.count - 1 ? contentLength + 1 : contentLength
            if location < offset + lineLength {
                return index
            }
            offset += lineLength
        }
        return paneRows.count - 1
    }

    private static func paneRowUtf16Bounds(row: Int, paneRows: [String]) -> (contentStart: Int, contentEnd: Int) {
        var offset = 0
        for index in 0..<row {
            offset += (paneRows[index] as NSString).length + 1
        }
        let contentLength = (paneRows[row] as NSString).length
        return (offset, offset + contentLength)
    }

    private static func splitPaneRows(_ paneText: String) -> [String] {
        if paneText.isEmpty {
            return []
        }
        return paneText.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
    }
}
