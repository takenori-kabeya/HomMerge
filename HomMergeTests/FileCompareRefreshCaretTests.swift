import DiffEngine
import XCTest
@testable import HomMerge

@MainActor
final class FileCompareRefreshCaretTests: XCTestCase {
    func testRefreshRestoresClampedCaretRowWhenShorterAfterReload() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("HomMergeRefreshCaret-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let leftURL = directory.appendingPathComponent("left.txt")
        let rightURL = directory.appendingPathComponent("right.txt")
        try "a\nb\nc\nd\ne\n".write(to: leftURL, atomically: true, encoding: .utf8)
        try "a\nb\nc\nd\ne\n".write(to: rightURL, atomically: true, encoding: .utf8)

        let viewModel = FileCompareViewModel()
        viewModel.seedComparison(
            leftText: "a\nb\nc\nd\ne\n",
            rightText: "a\nb\nc\nd\ne\n",
            leftPath: leftURL.path,
            rightPath: rightURL.path
        )
        viewModel.setCaretContext(row: 10, side: .left)

        try "a\nb\n".write(to: leftURL, atomically: true, encoding: .utf8)
        try "a\nb\n".write(to: rightURL, atomically: true, encoding: .utf8)
        viewModel.refresh()

        XCTAssertEqual(viewModel.pendingCaretLineStartRestore?.row, 1)
        XCTAssertEqual(viewModel.pendingCaretLineStartRestore?.side, .left)
        XCTAssertEqual(viewModel.pendingCaretLineStartRestore?.focus, true)
        XCTAssertEqual(viewModel.scrollToRow, 1)
        XCTAssertGreaterThan(viewModel.caretLineStartRestoreToken, 0)
    }

    func testRefreshWithoutCaretContextDoesNotScrollOrSelectHunk() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("HomMergeRefreshCaret-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let leftURL = directory.appendingPathComponent("left.txt")
        let rightURL = directory.appendingPathComponent("right.txt")
        try "alpha\n".write(to: leftURL, atomically: true, encoding: .utf8)
        try "beta\n".write(to: rightURL, atomically: true, encoding: .utf8)

        let viewModel = FileCompareViewModel()
        viewModel.seedComparison(
            leftText: "alpha\n",
            rightText: "beta\n",
            leftPath: leftURL.path,
            rightPath: rightURL.path
        )
        XCTAssertNil(viewModel.lastKnownCaretRow)
        XCTAssertNil(viewModel.currentHunkIndex)

        viewModel.refresh()

        XCTAssertNil(viewModel.pendingCaretLineStartRestore)
        XCTAssertNil(viewModel.scrollToRow)
        XCTAssertNil(viewModel.currentHunkIndex)
    }

    func testRefreshSelectsNearestHunkToRestoredCaretRow() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("HomMergeRefreshCaret-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let leftText = "a\nL1\nb\nL2\nc\n"
        let rightText = "a\nR1\nb\nR2\nc\n"
        let leftURL = directory.appendingPathComponent("left.txt")
        let rightURL = directory.appendingPathComponent("right.txt")
        try leftText.write(to: leftURL, atomically: true, encoding: .utf8)
        try rightText.write(to: rightURL, atomically: true, encoding: .utf8)

        let viewModel = FileCompareViewModel()
        viewModel.seedComparison(
            leftText: leftText,
            rightText: rightText,
            leftPath: leftURL.path,
            rightPath: rightURL.path
        )
        XCTAssertEqual(viewModel.locationHunks.count, 2)
        XCTAssertNil(viewModel.currentHunkIndex)

        let secondHunkStart = viewModel.locationHunks[1].startRow
        viewModel.setCaretContext(row: secondHunkStart, side: .left)
        viewModel.refresh()

        XCTAssertEqual(viewModel.currentHunkIndex, 1)
        XCTAssertEqual(viewModel.pendingCaretLineStartRestore?.row, secondHunkStart)
        XCTAssertEqual(viewModel.pendingCaretLineStartRestore?.focus, true)
        XCTAssertEqual(viewModel.scrollToRow, secondHunkStart)
    }
}
