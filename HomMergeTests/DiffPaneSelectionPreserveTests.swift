import AppKit
import DiffEngine
import XCTest
@testable import HomMerge

@MainActor
final class DiffPaneSelectionPreserveTests: XCTestCase {
    func testApplyPreservesNonEmptySelectedRange() {
        let host = DiffPaneHostView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
        let result = TextDiffer.compare("hello world\n", "hello swift\n")
        let lines = SideBySideBuilder.build(from: result)
        let hunks = result.hunks

        host.apply(
            lines: lines,
            hunks: hunks,
            currentHunkIndex: 0,
            highlightedRowRange: hunks[0].startRow..<(hunks[0].startRow + hunks[0].rowCount)
        )

        guard let textView = host.leftScrollView.documentView as? DiffPaneContentTextView else {
            XCTFail("Expected DiffPaneContentTextView")
            return
        }

        let selection = NSRange(location: 0, length: 5)
        textView.setSelectedRange(selection)
        XCTAssertEqual(textView.selectedRange().length, 5)

        host.apply(
            lines: lines,
            hunks: hunks,
            currentHunkIndex: 0,
            highlightedRowRange: nil
        )

        XCTAssertEqual(textView.selectedRange().location, selection.location)
        XCTAssertEqual(textView.selectedRange().length, selection.length)
    }

    func testApplyWithIdenticalHighlightStillPreservesSelectedRange() {
        let host = DiffPaneHostView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
        let result = TextDiffer.compare("alpha\nbeta\n", "alpha\ngamma\n")
        let lines = SideBySideBuilder.build(from: result)
        let hunks = result.hunks
        let highlight = hunks[0].startRow..<(hunks[0].startRow + hunks[0].rowCount)

        host.apply(
            lines: lines,
            hunks: hunks,
            currentHunkIndex: 0,
            highlightedRowRange: highlight
        )

        guard let textView = host.rightScrollView.documentView as? DiffPaneContentTextView else {
            XCTFail("Expected DiffPaneContentTextView")
            return
        }

        textView.setSelectedRange(NSRange(location: 1, length: 4))

        host.apply(
            lines: lines,
            hunks: hunks,
            currentHunkIndex: 0,
            highlightedRowRange: highlight
        )

        XCTAssertEqual(textView.selectedRange().location, 1)
        XCTAssertEqual(textView.selectedRange().length, 4)
    }
}
