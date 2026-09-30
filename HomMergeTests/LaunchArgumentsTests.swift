import XCTest
@testable import HomMerge

final class LaunchArgumentsTests: XCTestCase {
    func testParseReturnsNilForExecutableOnly() {
        XCTAssertNil(LaunchArgumentsParser.parse(["/Applications/HomMerge.app/Contents/MacOS/HomMerge"]))
    }

    func testParsePositionalArguments() {
        let request = LaunchArgumentsParser.parse([
            "/Applications/HomMerge.app/Contents/MacOS/HomMerge",
            "/tmp/left.txt",
            "/tmp/right.txt",
        ])
        XCTAssertEqual(request?.left.path, URL(fileURLWithPath: "/tmp/left.txt").standardizedFileURL.path)
        XCTAssertEqual(request?.right.path, URL(fileURLWithPath: "/tmp/right.txt").standardizedFileURL.path)
    }

    func testParseFlagArguments() {
        let request = LaunchArgumentsParser.parse([
            "/Applications/HomMerge.app/Contents/MacOS/HomMerge",
            "--right",
            "/tmp/right.txt",
            "--left",
            "/tmp/left.txt",
        ])
        XCTAssertEqual(request?.left.path, URL(fileURLWithPath: "/tmp/left.txt").standardizedFileURL.path)
        XCTAssertEqual(request?.right.path, URL(fileURLWithPath: "/tmp/right.txt").standardizedFileURL.path)
    }

    func testParseFlagArgumentsWithEqualsSyntax() {
        let request = LaunchArgumentsParser.parse([
            "/Applications/HomMerge.app/Contents/MacOS/HomMerge",
            "--left=/tmp/left.txt",
            "--right=/tmp/right.txt",
        ])
        XCTAssertEqual(request?.left.path, URL(fileURLWithPath: "/tmp/left.txt").standardizedFileURL.path)
        XCTAssertEqual(request?.right.path, URL(fileURLWithPath: "/tmp/right.txt").standardizedFileURL.path)
    }

    func testParseIgnoresInternalDebugArguments() {
        let request = LaunchArgumentsParser.parse([
            "/Applications/HomMerge.app/Contents/MacOS/HomMerge",
            "-NSDocumentRevisionsDebugMode",
            "YES",
            "/tmp/left.txt",
            "/tmp/right.txt",
        ])
        XCTAssertEqual(request?.left.path, URL(fileURLWithPath: "/tmp/left.txt").standardizedFileURL.path)
        XCTAssertEqual(request?.right.path, URL(fileURLWithPath: "/tmp/right.txt").standardizedFileURL.path)
    }

    func testParseReturnsNilForSinglePath() {
        XCTAssertNil(LaunchArgumentsParser.parse([
            "/Applications/HomMerge.app/Contents/MacOS/HomMerge",
            "/tmp/only.txt",
        ]))
    }

    func testParseReturnsNilForThreePositionalPaths() {
        XCTAssertNil(LaunchArgumentsParser.parse([
            "/Applications/HomMerge.app/Contents/MacOS/HomMerge",
            "/tmp/a.txt",
            "/tmp/b.txt",
            "/tmp/c.txt",
        ]))
    }

    func testParseExpandsTildeInPaths() throws {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let request = LaunchArgumentsParser.parse([
            "/Applications/HomMerge.app/Contents/MacOS/HomMerge",
            "~/left.txt",
            "~/right.txt",
        ])
        XCTAssertEqual(request?.left.path, URL(fileURLWithPath: home).appendingPathComponent("left.txt").standardizedFileURL.path)
        XCTAssertEqual(request?.right.path, URL(fileURLWithPath: home).appendingPathComponent("right.txt").standardizedFileURL.path)
    }

    func testParseOpenFilesReturnsRequestForTwoPaths() {
        let request = LaunchArgumentsParser.parseOpenFiles(["/tmp/left.txt", "/tmp/right.txt"])
        XCTAssertEqual(request?.left.path, URL(fileURLWithPath: "/tmp/left.txt").standardizedFileURL.path)
        XCTAssertEqual(request?.right.path, URL(fileURLWithPath: "/tmp/right.txt").standardizedFileURL.path)
    }

    func testParseOpenFilesReturnsNilForSinglePath() {
        XCTAssertNil(LaunchArgumentsParser.parseOpenFiles(["/tmp/only.txt"]))
    }

    func testParseOpenFilesReturnsNilForThreePaths() {
        XCTAssertNil(LaunchArgumentsParser.parseOpenFiles(["/tmp/a.txt", "/tmp/b.txt", "/tmp/c.txt"]))
    }

    func testIsFlagBasedComparisonDetectsFlagArguments() {
        XCTAssertTrue(LaunchArgumentsParser.isFlagBasedComparison([
            "/Applications/HomMerge.app/Contents/MacOS/HomMerge",
            "--left",
            "/tmp/left.txt",
            "--right",
            "/tmp/right.txt",
        ]))
        XCTAssertFalse(LaunchArgumentsParser.isFlagBasedComparison([
            "/Applications/HomMerge.app/Contents/MacOS/HomMerge",
            "/tmp/left.txt",
            "/tmp/right.txt",
        ]))
    }
}
