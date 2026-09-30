import AppKit
import DiffEngine
import XCTest
@testable import HomMerge

final class DiffHighlightStyleTests: XCTestCase {
    func testCurrentHunkPaneFillUsesSharedAccentAcrossDiffKinds() {
        let expected = DiffHighlightStyle.currentHunkPaneFill

        for kind in [DiffRowKind.delete, .insert, .modify] {
            for side in [DiffPaneSide.left, .right] {
                let color = DiffPaneRenderer.backgroundColor(for: kind, side: side, highlighted: true)
                assertColorsEqual(color, expected)
            }
        }
    }

    func testNonHighlightedRowsKeepDiffBaseColors() {
        let leftDelete = DiffPaneRenderer.backgroundColor(for: .delete, side: .left, highlighted: false)
        let rightInsert = DiffPaneRenderer.backgroundColor(for: .insert, side: .right, highlighted: false)
        let modify = DiffPaneRenderer.backgroundColor(for: .modify, side: .left, highlighted: false)

        assertColorsEqual(leftDelete, NSColor.systemRed.withAlphaComponent(0.18))
        assertColorsEqual(rightInsert, NSColor.systemGreen.withAlphaComponent(0.18))
        assertColorsEqual(modify, NSColor.systemYellow.withAlphaComponent(0.20))
    }

    func testLocationBarColorsDeriveFromSharedAccent() {
        assertColorsEqual(
            DiffHighlightStyle.currentHunkBarFill,
            DiffHighlightStyle.currentHunkAccent.withAlphaComponent(0.85)
        )
        assertColorsEqual(
            DiffHighlightStyle.currentHunkBarStroke,
            DiffHighlightStyle.currentHunkAccent
        )
    }

    private func assertColorsEqual(
        _ lhs: NSColor,
        _ rhs: NSColor,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard let left = lhs.usingColorSpace(.sRGB), let right = rhs.usingColorSpace(.sRGB) else {
            XCTFail("Failed to convert colors to sRGB", file: file, line: line)
            return
        }

        XCTAssertEqual(left.redComponent, right.redComponent, accuracy: 0.001, file: file, line: line)
        XCTAssertEqual(left.greenComponent, right.greenComponent, accuracy: 0.001, file: file, line: line)
        XCTAssertEqual(left.blueComponent, right.blueComponent, accuracy: 0.001, file: file, line: line)
        XCTAssertEqual(left.alphaComponent, right.alphaComponent, accuracy: 0.001, file: file, line: line)
    }
}
