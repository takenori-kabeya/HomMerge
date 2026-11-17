import XCTest
@testable import HomMerge

final class SecurityScopedBookmarkTests: XCTestCase {
    func testMakeAndResolveBookmarkRoundTripsFileURL() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("HomMergeBookmarkTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let fileURL = directory.appendingPathComponent("sample.txt")
        try Data("bookmark-round-trip".utf8).write(to: fileURL)

        let bookmark = try XCTUnwrap(SecurityScopedBookmark.makeBookmark(from: fileURL))
        let resolved = try XCTUnwrap(SecurityScopedBookmark.resolveBookmark(bookmark))

        XCTAssertEqual(resolved.standardizedFileURL.path, fileURL.standardizedFileURL.path)
    }

    func testResolveBookmarkReturnsNilForInvalidData() {
        let garbage = Data([0x00, 0x01, 0x02, 0x03])
        XCTAssertNil(SecurityScopedBookmark.resolveBookmark(garbage))
    }
}
