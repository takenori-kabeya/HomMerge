import XCTest
@testable import HomMerge

final class FolderCompareTablePreferencesTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "HomMerge.FolderCompareTablePreferencesTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testLoadReturnsDefaultIdealWidthsWithoutWritingDefaults() {
        XCTAssertNil(defaults.object(forKey: FolderCompareTablePreferences.columnWidthsKey))

        let widths = FolderCompareTablePreferences.load(defaults: defaults)

        XCTAssertEqual(widths[.name], 250)
        XCTAssertEqual(widths[.status], 70)
        XCTAssertEqual(widths[.leftDate], 140)
        XCTAssertEqual(widths[.rightDate], 140)
        XCTAssertEqual(widths[.path], 200)
        XCTAssertNil(defaults.object(forKey: FolderCompareTablePreferences.columnWidthsKey))
    }

    func testSaveThenLoadRoundTripsAllColumns() {
        let stored: [FolderCompareTableColumnID: CGFloat] = [
            .name: 300,
            .status: 80,
            .leftDate: 150,
            .rightDate: 155,
            .path: 220,
        ]

        FolderCompareTablePreferences.save(stored, defaults: defaults)
        let loaded = FolderCompareTablePreferences.load(defaults: defaults)

        XCTAssertEqual(loaded[.name], 300)
        XCTAssertEqual(loaded[.status], 80)
        XCTAssertEqual(loaded[.leftDate], 150)
        XCTAssertEqual(loaded[.rightDate], 155)
        XCTAssertEqual(loaded[.path], 220)
    }

    func testClampedWidthRaisesValuesBelowMinimum() {
        XCTAssertEqual(FolderCompareTablePreferences.clampedWidth(10, for: .name), 120)
        XCTAssertEqual(FolderCompareTablePreferences.clampedWidth(10, for: .status), 40)
        XCTAssertEqual(FolderCompareTablePreferences.clampedWidth(10, for: .leftDate), 110)
        XCTAssertEqual(FolderCompareTablePreferences.clampedWidth(10, for: .path), 80)
    }

    func testClampedWidthCapsValuesAboveMaximum() {
        XCTAssertEqual(FolderCompareTablePreferences.clampedWidth(200, for: .status), 100)
        XCTAssertEqual(FolderCompareTablePreferences.clampedWidth(300, for: .leftDate), 160)
        XCTAssertEqual(FolderCompareTablePreferences.clampedWidth(300, for: .rightDate), 160)
    }

    func testLoadClampsSavedValuesAndIgnoresUnknownKeys() {
        defaults.set(
            [
                "name": 50,
                "status": 400,
                "leftDate": 150,
                "rightDate": 90,
                "path": 40,
                "unknown": 999,
            ],
            forKey: FolderCompareTablePreferences.columnWidthsKey
        )

        let loaded = FolderCompareTablePreferences.load(defaults: defaults)

        XCTAssertEqual(loaded.count, FolderCompareTableColumnID.allCases.count)
        XCTAssertEqual(loaded[.name], 120)
        XCTAssertEqual(loaded[.status], 100)
        XCTAssertEqual(loaded[.leftDate], 150)
        XCTAssertEqual(loaded[.rightDate], 110)
        XCTAssertEqual(loaded[.path], 80)
        XCTAssertNil(loaded.keys.first { $0.rawValue == "unknown" })
    }
}
