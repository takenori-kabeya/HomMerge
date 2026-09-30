import AppKit
import DiffEngine

enum DiffPaneRenderer {
    static let gutterHorizontalPadding: CGFloat = 6
    static let contentHorizontalPadding: CGFloat = 4
    static let contentVerticalPadding: CGFloat = 8

    private static var monoFont: NSFont {
        NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
    }

    static func makeContentAttributedString(
        lines: [SideBySideLine],
        side: DiffPaneSide,
        highlightedRowRange: Range<Int>?,
        tabWidth: Int = EditorPreferences.defaultTabWidth
    ) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let contentParagraphStyle = paragraphStyle(alignment: .left, tabWidth: tabWidth)

        for (rowIndex, line) in lines.enumerated() {
            let text = DiffPaneTextLayout.text(for: line, side: side)
            let inlineSpans: [InlineSpan]
            switch side {
            case .left:
                inlineSpans = line.leftInlineSpans
            case .right:
                inlineSpans = line.rightInlineSpans
            }

            let rowString = DiffPaneTextLayout.contentRowString(
                text: text,
                isLastRow: rowIndex == lines.count - 1
            )
            let rowAttributed = NSMutableAttributedString(
                string: rowString,
                attributes: [
                    .font: monoFont,
                    .foregroundColor: NSColor.labelColor,
                    .paragraphStyle: contentParagraphStyle,
                ]
            )

            let fullRange = NSRange(location: 0, length: rowAttributed.length)
            rowAttributed.addAttribute(
                .backgroundColor,
                value: backgroundColor(
                    for: line.kind,
                    side: side,
                    highlighted: highlightedRowRange?.contains(rowIndex) == true
                ),
                range: fullRange
            )

            if line.kind == .modify {
                applyInlineHighlights(
                    to: rowAttributed,
                    content: text,
                    spans: inlineSpans
                )
            }

            result.append(rowAttributed)
        }

        return result
    }

    static func makeGutterAttributedString(
        lines: [SideBySideLine],
        side: DiffPaneSide,
        digitCount: Int,
        highlightedRowRange: Range<Int>?,
        tabWidth: Int = EditorPreferences.defaultTabWidth
    ) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let gutterParagraphStyle = paragraphStyle(alignment: .right, tabWidth: tabWidth)

        for (rowIndex, line) in lines.enumerated() {
            let label = DiffPaneTextLayout.gutterLabel(
                lineNumber: DiffPaneTextLayout.lineNumber(for: line, side: side),
                digitCount: digitCount
            )
            let rowString = DiffPaneTextLayout.contentRowString(
                text: label,
                isLastRow: rowIndex == lines.count - 1
            )
            let rowAttributed = NSMutableAttributedString(
                string: rowString,
                attributes: [
                    .font: monoFont,
                    .foregroundColor: NSColor.secondaryLabelColor,
                    .paragraphStyle: gutterParagraphStyle,
                ]
            )
            let fullRange = NSRange(location: 0, length: rowAttributed.length)
            rowAttributed.addAttribute(
                .backgroundColor,
                value: backgroundColor(
                    for: line.kind,
                    side: side,
                    highlighted: highlightedRowRange?.contains(rowIndex) == true
                ),
                range: fullRange
            )
            result.append(rowAttributed)
        }

        return result
    }

    /// Width in points for a gutter with `digitCount` columns, including horizontal padding.
    static func gutterWidth(digitCount: Int) -> CGFloat {
        let sample = String(repeating: "0", count: max(digitCount, 1))
        let digitsWidth = (sample as NSString).size(withAttributes: [.font: monoFont]).width
        return ceil(digitsWidth) + gutterHorizontalPadding * 2
    }

    static func utf16Location(forRow row: Int, in lines: [SideBySideLine], side: DiffPaneSide) -> Int {
        DiffPaneTextLayout.utf16Location(forRow: row, in: lines, side: side)
    }

    static func backgroundColor(
        for kind: DiffRowKind,
        side: DiffPaneSide,
        highlighted: Bool
    ) -> NSColor {
        let base: NSColor
        switch kind {
        case .equal:
            base = .clear
        case .delete:
            base = side == .left
                ? NSColor.systemRed.withAlphaComponent(0.18)
                : NSColor.systemRed.withAlphaComponent(0.08)
        case .insert:
            base = side == .right
                ? NSColor.systemGreen.withAlphaComponent(0.18)
                : NSColor.systemGreen.withAlphaComponent(0.08)
        case .modify:
            base = NSColor.systemYellow.withAlphaComponent(0.20)
        }

        if highlighted, kind != .equal {
            return DiffHighlightStyle.currentHunkPaneFill
        }
        return base
    }

    private static func paragraphStyle(alignment: NSTextAlignment, tabWidth: Int) -> NSParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.lineBreakMode = .byClipping
        style.alignment = alignment
        style.defaultTabInterval = EditorPreferences.defaultTabInterval(font: monoFont, tabWidth: tabWidth)
        return style
    }

    private static func applyInlineHighlights(
        to attributed: NSMutableAttributedString,
        content: String,
        spans: [InlineSpan]
    ) {
        for span in spans where span.kind != .equal {
            guard let contentRange = nsRange(
                in: content,
                characterStart: span.start,
                characterEnd: span.end
            ) else {
                continue
            }
            guard contentRange.location + contentRange.length <= attributed.length else { continue }

            let color: NSColor = span.kind == .delete
                ? NSColor.systemRed.withAlphaComponent(0.35)
                : NSColor.systemGreen.withAlphaComponent(0.35)
            attributed.addAttribute(.backgroundColor, value: color, range: contentRange)
        }
    }

    private static func nsRange(
        in string: String,
        characterStart: Int,
        characterEnd: Int
    ) -> NSRange? {
        guard characterStart >= 0,
              characterEnd >= characterStart,
              characterEnd <= string.count
        else {
            return nil
        }
        let lower = string.index(string.startIndex, offsetBy: characterStart)
        let upper = string.index(string.startIndex, offsetBy: characterEnd)
        return NSRange(lower..<upper, in: string)
    }
}
