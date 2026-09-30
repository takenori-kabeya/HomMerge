import XCTest
@testable import HomMerge

@MainActor
final class LaunchFlowTests: XCTestCase {
    private let registry = SessionRegistry.shared

    override func setUp() async throws {
        try await super.setUp()
        registry.resetLaunchStateForTesting()
    }
    
    override func tearDown() async throws {
        registry.resetLaunchStateForTesting()
        try await super.tearDown()
    }

    func testNoteOpenPathAccumulatesWithoutResolvingLaunch() {
        XCTAssertEqual(registry.noteOpenPath("/tmp/left.txt"), .accumulating)
        XCTAssertEqual(registry.noteOpenPath("/tmp/right.txt"), .readyToReply)

        XCTAssertFalse(registry.isLaunchResolvedForTesting)
        XCTAssertFalse(registry.hasPendingLaunchComparisonForTesting)
    }

    func testDuplicateOpenPathIsIgnoredUntilTwoUniquePathsArrive() {
        XCTAssertEqual(registry.noteOpenPath("/tmp/left.txt"), .accumulating)
        XCTAssertEqual(registry.noteOpenPath("/tmp/left.txt"), .accumulating)
        XCTAssertEqual(registry.noteOpenPath("/tmp/right.txt"), .readyToReply)

        XCTAssertFalse(registry.isLaunchResolvedForTesting)
    }

    func testConsumeBeforeResolveReturnsNil() {
        XCTAssertNil(registry.consumeInitialLaunchComparison())
        XCTAssertNil(registry.consumeInitialRestoreSnapshot())
        XCTAssertNil(registry.consumeInitialSingleFileURL())
    }

    func testResolveWithCLIArgumentsSkipsRestore() {
        registry.resolveLaunch(cliArguments: [
            "/Applications/HomMerge.app/Contents/MacOS/HomMerge",
            "--left",
            "/tmp/left.txt",
            "--right",
            "/tmp/right.txt",
        ])

        XCTAssertTrue(registry.hasPendingLaunchComparisonForTesting)
        XCTAssertEqual(registry.restoreQueueCountForTesting, 0)
        XCTAssertTrue(registry.isLaunchResolvedForTesting)
        XCTAssertFalse(registry.shouldPresentMainWindowForTesting)
    }

    func testResolveWithPositionalCLIArgumentsRequestsMainWindow() {
        registry.resolveLaunch(cliArguments: [
            "/Applications/HomMerge.app/Contents/MacOS/HomMerge",
            "/tmp/left.txt",
            "/tmp/right.txt",
        ])

        XCTAssertTrue(registry.hasPendingLaunchComparisonForTesting)
        XCTAssertTrue(registry.shouldPresentMainWindowForTesting)
    }

    func testResolveWithOpenPathsRequestsMainWindow() {
        _ = registry.noteOpenPath("/tmp/left.txt")
        _ = registry.noteOpenPath("/tmp/right.txt")

        registry.resolveLaunch(cliArguments: [
            "/Applications/HomMerge.app/Contents/MacOS/HomMerge",
        ])

        XCTAssertTrue(registry.hasPendingLaunchComparisonForTesting)
        XCTAssertEqual(registry.restoreQueueCountForTesting, 0)
        XCTAssertTrue(registry.isLaunchResolvedForTesting)
        XCTAssertTrue(registry.shouldPresentMainWindowForTesting)
    }

    func testResolveWithoutArgumentsLoadsRestoreQueue() {
        let front = WindowSnapshot(
            selectedTabIndex: 0,
            tabs: [TabSnapshot(leftPath: "/tmp/front-left", rightPath: "/tmp/front-right")]
        )
        let back = WindowSnapshot(
            selectedTabIndex: 0,
            tabs: [TabSnapshot(leftPath: "/tmp/back-left", rightPath: "/tmp/back-right")]
        )
        registry.persistenceLoaderForTesting = {
            AppSessionSnapshot(windows: [front, back])
        }

        registry.resolveLaunch(cliArguments: [
            "/Applications/HomMerge.app/Contents/MacOS/HomMerge",
        ])

        XCTAssertFalse(registry.hasPendingLaunchComparisonForTesting)
        XCTAssertTrue(registry.isLaunchResolvedForTesting)
        XCTAssertEqual(registry.consumeInitialRestoreSnapshot(), back)
        XCTAssertEqual(registry.consumeInitialRestoreSnapshot(), front)
        XCTAssertNil(registry.consumeInitialRestoreSnapshot())
    }

    func testResolveWithSingleOpenPathDebouncesThenPresentsLeftFile() {
        _ = registry.noteOpenPath("/tmp/only.txt")
        registry.resolveLaunch(cliArguments: [
            "/Applications/HomMerge.app/Contents/MacOS/HomMerge",
        ])

        XCTAssertFalse(registry.isLaunchResolvedForTesting)
        XCTAssertTrue(registry.isAwaitingSecondOpenFileForTesting)

        registry.completeSingleFileDebounceForTesting()

        XCTAssertFalse(registry.hasPendingLaunchComparisonForTesting)
        XCTAssertNil(registry.consumeInitialRestoreSnapshot())
        XCTAssertTrue(registry.isLaunchResolvedForTesting)
        XCTAssertTrue(registry.shouldPresentMainWindowForTesting)
        XCTAssertEqual(
            registry.consumeInitialSingleFileURL()?.path,
            URL(fileURLWithPath: "/tmp/only.txt").standardizedFileURL.path
        )
    }

    func testSecondOpenPathDuringDebounceStartsComparison() {
        registry.singleFileDebounceInterval = .seconds(60)
        _ = registry.noteOpenPath("/tmp/left.txt")
        registry.resolveLaunch(cliArguments: [
            "/Applications/HomMerge.app/Contents/MacOS/HomMerge",
        ])

        XCTAssertTrue(registry.isAwaitingSecondOpenFileForTesting)
        XCTAssertEqual(registry.noteOpenPath("/tmp/right.txt"), .readyToReply)

        XCTAssertTrue(registry.hasPendingLaunchComparisonForTesting)
        XCTAssertTrue(registry.isLaunchResolvedForTesting)
        XCTAssertTrue(registry.shouldPresentMainWindowForTesting)
        XCTAssertNil(registry.consumeInitialSingleFileURL())
    }

    func testConsumeShouldPresentMainWindowClearsFlag() {
        registry.resolveLaunch(cliArguments: [
            "/Applications/HomMerge.app/Contents/MacOS/HomMerge",
            "/tmp/left.txt",
            "/tmp/right.txt",
        ])
        XCTAssertTrue(registry.consumeShouldPresentMainWindow())
        XCTAssertFalse(registry.shouldPresentMainWindowForTesting)
    }

    func testNoteOpenPathsAfterLaunchStartsComparisonWithoutSingleFileOpen() {
        registry.resolveLaunch(cliArguments: [
            "/Applications/HomMerge.app/Contents/MacOS/HomMerge",
        ])
        XCTAssertTrue(registry.isLaunchResolvedForTesting)

        XCTAssertEqual(
            registry.noteOpenPaths(["/tmp/left.txt", "/tmp/right.txt"]),
            .readyToReply
        )

        XCTAssertNil(registry.consumeInitialSingleFileURL())
        XCTAssertNil(registry.consumeStagedWarmSingleFileURL())
        let request = registry.lastWarmLaunchComparisonForTesting
        XCTAssertEqual(
            request?.left.path,
            URL(fileURLWithPath: "/tmp/left.txt").standardizedFileURL.path
        )
        XCTAssertEqual(
            request?.right.path,
            URL(fileURLWithPath: "/tmp/right.txt").standardizedFileURL.path
        )
    }
}
