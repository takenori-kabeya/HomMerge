import AppKit
import XCTest
@testable import HomMerge

@MainActor
final class WarmOpenFileTests: XCTestCase {
    private let registry = SessionRegistry.shared

    override func setUp() {
        super.setUp()
        registry.resetLaunchStateForTesting()
    }

    override func tearDown() {
        registry.resetLaunchStateForTesting()
        super.tearDown()
    }

    func testCompareSessionViewModelApplyDockDroppedFileSetsLeftWhenEmpty() throws {
        let leftFile = try makeTemporaryFile(named: "left.txt", contents: "alpha")
        let session = CompareSessionViewModel()

        session.applyDockDroppedFile(leftFile)

        XCTAssertEqual(session.leftURL, leftFile)
        XCTAssertNil(session.rightURL)
        if case .idle = session.phase {
        } else {
            XCTFail("Expected idle phase after setting left only")
        }
    }

    func testCompareSessionViewModelApplyDockDroppedFileComparesWhenLeftSet() throws {
        let leftFile = try makeTemporaryFile(named: "left.txt", contents: "alpha")
        let rightFile = try makeTemporaryFile(named: "right.txt", contents: "beta")
        let session = CompareSessionViewModel()
        session.leftURL = leftFile

        session.applyDockDroppedFile(rightFile)

        XCTAssertEqual(session.leftURL, leftFile)
        XCTAssertEqual(session.rightURL, rightFile)
        XCTAssertNotNil(session.fileCompare)
    }

    func testWarmSingleFileSetsLeftWhenEmpty() throws {
        let appModel = AppViewModel()
        let window = NSWindow(contentRect: .zero, styleMask: [], backing: .buffered, defer: false)
        registry.register(appModel, window: window)
        defer { registry.unregister(appModel) }

        resolveLaunchForWarmTesting()
        let leftFile = try makeTemporaryFile(named: "warm-left.txt", contents: "alpha")

        XCTAssertEqual(registry.noteOpenPath(leftFile.path), .readyToReply)
        XCTAssertEqual(appModel.selectedSession?.leftURL, leftFile.standardizedFileURL)
        XCTAssertNil(appModel.selectedSession?.rightURL)
        if case .idle = appModel.selectedSession?.phase {
        } else {
            XCTFail("Expected idle phase after warm single-file drop on empty session")
        }
    }

    func testWarmSingleFileSetsRightAndComparesWhenLeftSet() throws {
        let appModel = AppViewModel()
        let window = NSWindow(contentRect: .zero, styleMask: [], backing: .buffered, defer: false)
        registry.register(appModel, window: window)
        defer { registry.unregister(appModel) }

        resolveLaunchForWarmTesting()
        let leftFile = try makeTemporaryFile(named: "warm-left.txt", contents: "alpha")
        let rightFile = try makeTemporaryFile(named: "warm-right.txt", contents: "beta")
        appModel.selectedSession?.restorePaths(left: leftFile, right: nil)

        XCTAssertEqual(registry.noteOpenPath(rightFile.path), .readyToReply)
        XCTAssertEqual(appModel.selectedSession?.leftURL, leftFile)
        XCTAssertEqual(appModel.selectedSession?.rightURL, rightFile.standardizedFileURL)
        XCTAssertNotNil(appModel.selectedSession?.fileCompare)
    }

    func testWarmSingleFileReplacesRightWhenBothSet() throws {
        let appModel = AppViewModel()
        let window = NSWindow(contentRect: .zero, styleMask: [], backing: .buffered, defer: false)
        registry.register(appModel, window: window)
        defer { registry.unregister(appModel) }

        resolveLaunchForWarmTesting()
        let leftFile = try makeTemporaryFile(named: "warm-left.txt", contents: "alpha")
        let originalRight = try makeTemporaryFile(named: "warm-right-old.txt", contents: "beta")
        let replacementRight = try makeTemporaryFile(named: "warm-right-new.txt", contents: "gamma")
        appModel.selectedSession?.restorePaths(left: leftFile, right: originalRight)

        XCTAssertEqual(registry.noteOpenPath(replacementRight.path), .readyToReply)
        XCTAssertEqual(appModel.selectedSession?.leftURL, leftFile)
        XCTAssertEqual(appModel.selectedSession?.rightURL, replacementRight.standardizedFileURL)
        XCTAssertNotNil(appModel.selectedSession?.fileCompare)
    }

    private func resolveLaunchForWarmTesting() {
        registry.resolveLaunch(cliArguments: [
            "/Applications/HomMerge.app/Contents/MacOS/HomMerge",
        ])
        XCTAssertTrue(registry.isLaunchResolvedForTesting)
    }

    private func makeTemporaryFile(named name: String, contents: String) throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("HomMerge-WarmOpenFileTests", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent(name)
        try contents.write(to: url, atomically: true, encoding: .utf8)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: url)
        }
        return url.standardizedFileURL
    }
}
