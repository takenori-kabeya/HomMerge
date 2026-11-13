import XCTest
@testable import HomMerge

@MainActor
final class AppViewModelSessionRestoreTests: XCTestCase {
    func testMakeSnapshotStoresPathsAndBookmarks() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("HomMergeSnapshot-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let left = directory.appendingPathComponent("left.txt")
        let right = directory.appendingPathComponent("right.txt")
        try Data("L".utf8).write(to: left)
        try Data("R".utf8).write(to: right)

        let appModel = AppViewModel()
        appModel.selectedSession?.restorePaths(left: left, right: right)

        let snapshot = appModel.makeSnapshot()
        let tab = try XCTUnwrap(snapshot.tabs.first)

        XCTAssertEqual(tab.leftPath, left.path)
        XCTAssertEqual(tab.rightPath, right.path)
        XCTAssertNotNil(tab.leftBookmark)
        XCTAssertNotNil(tab.rightBookmark)

        let resolvedLeft = try XCTUnwrap(
            tab.leftBookmark.flatMap(SecurityScopedBookmark.resolveBookmark)
        )
        let resolvedRight = try XCTUnwrap(
            tab.rightBookmark.flatMap(SecurityScopedBookmark.resolveBookmark)
        )
        XCTAssertEqual(resolvedLeft.standardizedFileURL.path, left.standardizedFileURL.path)
        XCTAssertEqual(resolvedRight.standardizedFileURL.path, right.standardizedFileURL.path)
    }

    func testRestoringPrefersBookmarkOverPath() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("HomMergeRestore-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let realLeft = directory.appendingPathComponent("real-left.txt")
        let realRight = directory.appendingPathComponent("real-right.txt")
        try Data("L".utf8).write(to: realLeft)
        try Data("R".utf8).write(to: realRight)

        let leftBookmark = try XCTUnwrap(SecurityScopedBookmark.makeBookmark(from: realLeft))
        let rightBookmark = try XCTUnwrap(SecurityScopedBookmark.makeBookmark(from: realRight))

        let window = WindowSnapshot(
            selectedTabIndex: 0,
            tabs: [
                TabSnapshot(
                    leftPath: "/tmp/stale-left-should-not-win.txt",
                    rightPath: "/tmp/stale-right-should-not-win.txt",
                    leftBookmark: leftBookmark,
                    rightBookmark: rightBookmark
                ),
            ]
        )

        let appModel = AppViewModel(restoring: window)
        let session = try XCTUnwrap(appModel.selectedSession)

        XCTAssertEqual(session.leftURL?.standardizedFileURL.path, realLeft.standardizedFileURL.path)
        XCTAssertEqual(session.rightURL?.standardizedFileURL.path, realRight.standardizedFileURL.path)
    }

    func testRestoringFallsBackToPathWhenBookmarkMissing() {
        let window = WindowSnapshot(
            selectedTabIndex: 0,
            tabs: [
                TabSnapshot(
                    leftPath: "/tmp/path-only-left.txt",
                    rightPath: "/tmp/path-only-right.txt"
                ),
            ]
        )

        let appModel = AppViewModel(restoring: window)
        let session = appModel.selectedSession

        XCTAssertEqual(session?.leftURL?.path, "/tmp/path-only-left.txt")
        XCTAssertEqual(session?.rightURL?.path, "/tmp/path-only-right.txt")
    }
}
