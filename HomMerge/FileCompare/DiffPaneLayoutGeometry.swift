import AppKit
import DiffEngine

/// Layout helpers for aligning gutter and content text views row-by-row.
@MainActor
enum DiffPaneLayoutGeometry {
    static func layoutDocumentHeight(for textView: NSTextView) -> CGFloat {
        guard let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer
        else {
            return textView.bounds.height
        }
        layoutManager.ensureLayout(for: textContainer)
        let usedHeight = layoutManager.usedRect(for: textContainer).height
        return DiffPaneTextLayout.layoutDocumentHeight(
            usedRectHeight: usedHeight,
            textContainerInsetHeight: textView.textContainerInset.height
        )
    }

    static func lineMinY(
        forRow row: Int,
        in lines: [SideBySideLine],
        side: DiffPaneSide,
        textView: NSTextView,
        digitCount: Int?,
        isGutter: Bool
    ) -> CGFloat? {
        guard let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer,
              !lines.isEmpty
        else {
            return nil
        }

        let clamped = DiffPaneTextLayout.clampedPresentationRow(row, lineCount: lines.count) ?? 0
        let location: Int
        if isGutter, let digitCount {
            location = DiffPaneTextLayout.utf16Location(
                forGutterRow: clamped,
                in: lines,
                side: side,
                digitCount: digitCount
            )
        } else {
            location = DiffPaneTextLayout.utf16Location(forRow: clamped, in: lines, side: side)
        }

        let length = (textView.string as NSString).length
        guard length > 0 else { return nil }
        let characterLocation = min(max(location, 0), max(length - 1, 0))
        let characterRange = NSRange(location: characterLocation, length: 1)

        layoutManager.ensureLayout(for: textContainer)
        let glyphRange = layoutManager.glyphRange(
            forCharacterRange: characterRange,
            actualCharacterRange: nil
        )
        var lineRect = layoutManager.lineFragmentRect(forGlyphAt: glyphRange.location, effectiveRange: nil)
        lineRect.origin.y += textView.textContainerOrigin.y
        return lineRect.minY
    }

    static func verticalOffsetAligningRow(
        _ row: Int,
        in lines: [SideBySideLine],
        side: DiffPaneSide,
        textView: NSTextView,
        scrollView: NSScrollView,
        anchorFractionInViewport: CGFloat,
        digitCount: Int?,
        isGutter: Bool
    ) -> CGFloat? {
        guard let lineMinY = lineMinY(
            forRow: row,
            in: lines,
            side: side,
            textView: textView,
            digitCount: digitCount,
            isGutter: isGutter
        ) else {
            return nil
        }

        let visibleHeight = scrollView.contentView.bounds.height
        let documentHeight = layoutDocumentHeight(for: textView)
        return DiffPaneTextLayout.verticalOffsetAligningRow(
            lineMinY: lineMinY,
            visibleHeight: visibleHeight,
            documentHeight: documentHeight,
            anchorFractionInViewport: anchorFractionInViewport
        )
    }

    static func refreshLayoutOnly(for textView: NSTextView) {
        guard let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer
        else {
            textView.needsDisplay = true
            return
        }

        layoutManager.ensureLayout(for: textContainer)
        textView.needsDisplay = true
    }

    /// Bottom inset for a gutter clip view so its visible document height matches a content
    /// scroll view that may be shorter due to a horizontal scroller.
    static func gutterBottomInset(
        contentClipHeight: CGFloat,
        gutterClipHeight: CGFloat
    ) -> CGFloat {
        max(gutterClipHeight - contentClipHeight, 0)
    }

    static func refreshDocumentPresentation(for textView: NSTextView) {
        guard let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer,
              let scrollView = textView.enclosingScrollView
        else {
            textView.needsDisplay = true
            return
        }

        layoutManager.ensureLayout(for: textContainer)

        let documentHeight = layoutDocumentHeight(for: textView)
        let clipView = scrollView.contentView
        let clampedY = DiffPaneTextLayout.clampedVerticalOffset(
            currentY: clipView.bounds.origin.y,
            documentHeight: documentHeight,
            visibleHeight: clipView.bounds.height
        )

        var origin = clipView.bounds.origin
        if origin.y != clampedY {
            origin.y = clampedY
            clipView.setBoundsOrigin(origin)
        }
        scrollView.reflectScrolledClipView(clipView)
        textView.needsDisplay = true
    }
}
