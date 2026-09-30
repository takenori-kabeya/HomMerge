import AppKit
import XCTest
@testable import HomMerge

final class FinderCompareServiceTests: XCTestCase {
    func testComparisonRequestUsesSelectionOrder() {
        let left = URL(fileURLWithPath: "/tmp/left.txt")
        let right = URL(fileURLWithPath: "/tmp/right.txt")

        let request = FinderCompareService.comparisonRequest(fromFileURLs: [left, right])

        XCTAssertEqual(request?.left.path, left.standardizedFileURL.path)
        XCTAssertEqual(request?.right.path, right.standardizedFileURL.path)
    }

    func testComparisonRequestReturnsNilWhenCountIsNotTwo() {
        let first = URL(fileURLWithPath: "/tmp/a.txt")
        let second = URL(fileURLWithPath: "/tmp/b.txt")
        let third = URL(fileURLWithPath: "/tmp/c.txt")

        XCTAssertNil(FinderCompareService.comparisonRequest(fromFileURLs: []))
        XCTAssertNil(FinderCompareService.comparisonRequest(fromFileURLs: [first]))
        XCTAssertNil(FinderCompareService.comparisonRequest(fromFileURLs: [first, second, third]))
    }

    func testComparisonRequestFromPathsMatchesFileURLs() {
        let paths = ["/tmp/left.txt", "/tmp/right.txt"]
        let urls = paths.map { URL(fileURLWithPath: $0) }

        XCTAssertEqual(
            FinderCompareService.comparisonRequest(fromFileURLs: urls),
            LaunchArgumentsParser.parseOpenFiles(paths)
        )
    }

    func testFileURLsFromPasteboardPreserveOrder() {
        let left = URL(fileURLWithPath: "/tmp/left.txt")
        let right = URL(fileURLWithPath: "/tmp/right.txt")
        let pasteboard = NSPasteboard.withUniqueName()
        pasteboard.clearContents()
        XCTAssertTrue(pasteboard.writeObjects([left as NSURL, right as NSURL]))

        let urls = FinderCompareService.fileURLs(from: pasteboard)

        XCTAssertEqual(urls.map(\.standardizedFileURL.path), [
            left.standardizedFileURL.path,
            right.standardizedFileURL.path,
        ])
        XCTAssertEqual(
            FinderCompareService.comparisonRequest(fromFileURLs: urls),
            LaunchArgumentsParser.parseOpenFiles([left.path, right.path])
        )
    }
}
