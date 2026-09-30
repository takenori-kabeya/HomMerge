import XCTest
@testable import HomMerge

final class SessionPersistenceTests: XCTestCase {
    private var defaults: UserDefaults!
    private let suiteName = "jp.cabinetwork.HomMergeTests.SessionPersistence"

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        super.tearDown()
    }

    func testSaveAndLoadRoundTripsSnapshot() {
        let snapshot = AppSessionSnapshot(
            windows: [
                WindowSnapshot(
                    selectedTabIndex: 1,
                    tabs: [
                        TabSnapshot(leftPath: "/tmp/a.txt", rightPath: "/tmp/b.txt"),
                        TabSnapshot(leftPath: "/tmp/c.txt", rightPath: nil),
                    ]
                )
            ]
        )

        SessionPersistence.save(snapshot, to: defaults)

        let loaded = SessionPersistence.load(from: defaults)
        XCTAssertEqual(loaded, snapshot)
    }

    func testLoadReturnsNilWhenNothingStored() {
        XCTAssertNil(SessionPersistence.load(from: defaults))
    }

    func testClearRemovesStoredSnapshot() {
        let snapshot = AppSessionSnapshot(
            windows: [
                WindowSnapshot(
                    selectedTabIndex: 0,
                    tabs: [TabSnapshot(leftPath: "/tmp/x", rightPath: "/tmp/y")]
                )
            ]
        )
        SessionPersistence.save(snapshot, to: defaults)
        XCTAssertNotNil(SessionPersistence.load(from: defaults))

        SessionPersistence.clear(defaults: defaults)
        XCTAssertNil(SessionPersistence.load(from: defaults))
    }

    func testMultiWindowOrderIsPreservedOnRoundTrip() {
        let front = WindowSnapshot(
            selectedTabIndex: 0,
            tabs: [TabSnapshot(leftPath: "/tmp/front-left", rightPath: "/tmp/front-right")]
        )
        let back = WindowSnapshot(
            selectedTabIndex: 0,
            tabs: [TabSnapshot(leftPath: "/tmp/back-left", rightPath: "/tmp/back-right")]
        )
        let snapshot = AppSessionSnapshot(windows: [front, back])

        SessionPersistence.save(snapshot, to: defaults)

        let loaded = SessionPersistence.load(from: defaults)
        XCTAssertEqual(loaded?.windows, [front, back])
        XCTAssertEqual(loaded?.windows.first, front)
        XCTAssertEqual(loaded?.windows.last, back)
    }
}
